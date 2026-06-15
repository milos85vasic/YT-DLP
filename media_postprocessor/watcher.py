"""Filesystem watcher + reconcile/backfill for media_postprocessor (Phase 3, §10).

Real-time: a watchdog event handler enqueues newly-finished downloads as they
land. Periodic reconcile full-scan (`reconcile_scan`) diffs the library against
the jobs table and enqueues anything missing — this SAME scan is the one-time
backfill, called at startup over the whole library (§10).

Skip rules (§10): in-progress extensions (*.part, *.ytdl, *.partial), generated
outputs (a 'webready-' basename prefix and any '.mp3') are never enqueued, so we
never derive from a derivative or pick up a still-being-written file. The actual
webready-/.mp3 classification is delegated to media_probe.classify_target.

This module imports the committed, stable media_postprocessor.jobs_db and
media_postprocessor.media_probe. The jobs_db API is db-path-based; the public
`conn` parameter therefore accepts either a sqlite3.Connection (its db path is
resolved) or a db-path string, and the enqueue is idempotent on the UNIQUE
source_path (§5.2).
"""

import os
import sqlite3
import time

from watchdog.events import FileSystemEventHandler
from watchdog.observers.polling import PollingObserver

from media_postprocessor import jobs_db, media_probe

# Files that are still being written by metube, or are mid-rename, MUST NOT be
# picked up before they finish (§10 mid-write protection).
IN_PROGRESS_EXTS = (".part", ".ytdl", ".partial")

# §10 min-age / stable-size guard: yt-dlp renames <name>.part -> <name> and then
# ffmpeg writes/merges into the final file, so a file that has *just* been
# touched may still be growing. We defer any file whose mtime is younger than
# MIN_STABLE_AGE_SECONDS — once it stops changing for this long it is considered
# stable. Overridable via the MP_MIN_STABLE_AGE env var (seconds).
def _default_min_stable_age() -> float:
    try:
        return float(os.environ.get("MP_MIN_STABLE_AGE", "10"))
    except ValueError:
        return 10.0


MIN_STABLE_AGE_SECONDS = _default_min_stable_age()


def _db_path(conn) -> str:
    """Resolve a db path from either a sqlite3.Connection or a db-path string.

    The committed jobs_db API is path-based (it opens its own short-lived
    connections with the spec PRAGMAs), so a passed-in live Connection is only
    used to recover the file it is attached to.
    """
    if isinstance(conn, sqlite3.Connection):
        for _seq, name, filename in conn.execute("PRAGMA database_list"):
            if name == "main" and filename:
                return filename
        raise ValueError("connection has no main database file (in-memory?)")
    return conn


def _is_in_progress(path: str) -> bool:
    """True for in-progress/mid-write files we must ignore (§10)."""
    lower = os.path.basename(path).lower()
    return lower.endswith(IN_PROGRESS_EXTS)


def _is_stable(path: str, min_age: float) -> bool:
    """True iff `path` has not been modified for at least `min_age` seconds.

    This is the §10 min-age / stable-size filter: a file whose mtime is younger
    than `min_age` may still be growing (yt-dlp finished the .part rename but
    ffmpeg is still merging into the final file), so it is NOT yet safe to
    enqueue. A min_age <= 0 disables the guard.
    """
    if min_age <= 0:
        return True
    try:
        return time.time() - os.stat(path).st_mtime >= min_age
    except OSError:
        return False


def _already_enqueued(db_path: str, source_path: str) -> bool:
    """True iff a row for source_path already exists (enqueue is a no-op)."""
    conn = jobs_db.connect(db_path)
    try:
        row = conn.execute(
            "SELECT 1 FROM jobs WHERE source_path=?", (source_path,)
        ).fetchone()
        return row is not None
    finally:
        conn.close()


def _enqueue_if_target(
    path: str, db_path: str, min_age: float = MIN_STABLE_AGE_SECONDS
) -> bool:
    """classify + idempotent-enqueue one path. Returns True iff NEWLY enqueued.

    Ignores in-progress files and anything media_probe.classify_target marks
    'skip' (webready- prefix, .mp3 outputs, non-media extensions). Returns False
    when the file is a target but its row already exists, so callers can count
    genuinely-new rows (enqueue itself is INSERT OR IGNORE on UNIQUE source_path).

    §10 mid-write protection: after classify + stat, a file that is NOT yet
    stable (mtime younger than `min_age` — still being written/merged by
    yt-dlp+ffmpeg) returns False and is NOT enqueued. The real-time watchdog
    handler therefore defers fresh files; the periodic reconcile full-scan is
    the safety net that picks them up once they have settled (spec §10).
    """
    if _is_in_progress(path):
        return False
    target = media_probe.classify_target(path)
    if target == "skip":
        return False
    try:
        st = os.stat(path)
    except OSError:
        return False
    if not _is_stable(path, min_age):
        return False
    if _already_enqueued(db_path, path):
        return False
    jobs_db.enqueue(db_path, path, int(st.st_size), int(st.st_mtime), target)
    return True


def reconcile_scan(download_dir: str, conn) -> int:
    """Walk the tree and enqueue every webready_video / mp3_audio file (§10).

    This is the periodic reconcile full-scan AND the one-time startup backfill:
    enqueue is idempotent on source_path, so re-running it never duplicates a
    row. Skips in-progress extensions, 'webready-' outputs, and '.mp3' outputs.

    Returns the number of files newly enqueued by this call.
    """
    db_path = _db_path(conn)
    enqueued = 0
    for root, _dirs, files in os.walk(download_dir):
        for name in files:
            path = os.path.join(root, name)
            if _enqueue_if_target(path, db_path):
                enqueued += 1
    return enqueued


class DownloadFinishedHandler(FileSystemEventHandler):
    """Enqueue a newly-finished download via classify+enqueue (§10).

    on_created handles a file that appears complete; on_moved handles the
    common metube pattern of writing '<name>.part' then renaming to the final
    name (we enqueue the destination). In-progress extensions and derivative
    outputs are ignored by the shared classify+enqueue logic.
    """

    def __init__(self, conn):
        super().__init__()
        self._db_path = _db_path(conn)

    def _handle(self, path: str) -> None:
        _enqueue_if_target(path, self._db_path)

    def on_created(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def on_moved(self, event):
        if event.is_directory:
            return
        # The finished file is the rename destination.
        self._handle(event.dest_path)


def start_watching(download_dir: str, conn):
    """Build, start and return a PollingObserver watching download_dir (§10).

    A PollingObserver is used because inotify is unreliable on network mounts
    (the ${DOWNLOAD_DIR} is typically a network filesystem); polling reliably
    detects creates/moves there.
    """
    handler = DownloadFinishedHandler(conn)
    observer = PollingObserver()
    observer.schedule(handler, download_dir, recursive=True)
    observer.start()
    return observer
