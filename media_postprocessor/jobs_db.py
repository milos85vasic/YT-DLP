"""SQLite (WAL) crash-safe jobs DB for media_postprocessor.

Schema is locked from the design spec §5.2; PRAGMAs from §5.1.
"""

import datetime
import os
import sqlite3

_SCHEMA = """
CREATE TABLE IF NOT EXISTS jobs (
  id          INTEGER PRIMARY KEY,
  source_path TEXT UNIQUE,
  size        INTEGER,
  mtime       INTEGER,
  media_type  TEXT,
  status      TEXT NOT NULL DEFAULT 'queued'
              CHECK (status IN ('queued','running','done','failed','canceled')),
  output_path TEXT,
  attempts    INTEGER NOT NULL DEFAULT 0,
  error       TEXT,
  created_at  TEXT,
  updated_at  TEXT,
  started_at  TEXT,
  finished_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
"""


def connect(db_path: str) -> sqlite3.Connection:
    """Open a connection with the spec PRAGMAs applied (§5.1)."""
    conn = sqlite3.connect(db_path, timeout=5.0)
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    return conn


def init_db(db_path: str) -> None:
    """Create the parent directory, the jobs table, and the status index."""
    parent = os.path.dirname(db_path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    conn = connect(db_path)
    try:
        conn.executescript(_SCHEMA)
        conn.commit()
    finally:
        conn.close()


def _now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def enqueue(db_path: str, source_path: str, size: int, mtime: int, media_type: str) -> int:
    """Insert a queued job. Idempotent on the UNIQUE source_path (§5.2).

    Returns the job id whether newly inserted or pre-existing.
    """
    now = _now()
    conn = connect(db_path)
    try:
        conn.execute(
            "INSERT OR IGNORE INTO jobs "
            "(source_path, size, mtime, media_type, status, attempts, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, 'queued', 0, ?, ?)",
            (source_path, size, mtime, media_type, now, now),
        )
        conn.commit()
        row = conn.execute(
            "SELECT id FROM jobs WHERE source_path=?", (source_path,)
        ).fetchone()
        return int(row[0])
    finally:
        conn.close()


def claim_next_job(db_path: str):
    """Atomically claim the oldest queued job → running, bumping attempts.

    Uses BEGIN IMMEDIATE + UPDATE...RETURNING so two workers can never
    claim the same row. Returns a dict of the claimed row, or None.
    """
    now = _now()
    conn = connect(db_path)
    try:
        conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            "UPDATE jobs SET status='running', started_at=?, updated_at=?, "
            "attempts=attempts+1 "
            "WHERE id = (SELECT id FROM jobs WHERE status='queued' "
            "            ORDER BY id LIMIT 1) "
            "RETURNING id, source_path, media_type, output_path, attempts, status",
            (now, now),
        ).fetchone()
        conn.commit()
    finally:
        conn.close()
    if row is None:
        return None
    return {
        "id": row[0],
        "source_path": row[1],
        "media_type": row[2],
        "output_path": row[3],
        "attempts": row[4],
        "status": row[5],
    }


def mark_done(db_path: str, job_id: int, output_path: str) -> None:
    """Mark a job done with its produced output path and finish timestamp."""
    now = _now()
    conn = connect(db_path)
    try:
        conn.execute(
            "UPDATE jobs SET status='done', output_path=?, error=NULL, "
            "updated_at=?, finished_at=? WHERE id=?",
            (output_path, now, now, job_id),
        )
        conn.commit()
    finally:
        conn.close()


def mark_failed(db_path: str, job_id: int, error: str) -> None:
    """Mark a job failed with the error string and finish timestamp."""
    now = _now()
    conn = connect(db_path)
    try:
        conn.execute(
            "UPDATE jobs SET status='failed', error=?, updated_at=?, finished_at=? "
            "WHERE id=?",
            (error, now, now, job_id),
        )
        conn.commit()
    finally:
        conn.close()


def requeue_running_on_startup(db_path: str) -> int:
    """Crash recovery (§5.3): any job left 'running' is re-queued.

    Returns the number of rows re-queued.
    """
    now = _now()
    conn = connect(db_path)
    try:
        cur = conn.execute(
            "UPDATE jobs SET status='queued', started_at=NULL, updated_at=? "
            "WHERE status='running'",
            (now,),
        )
        conn.commit()
        return cur.rowcount
    finally:
        conn.close()
