"""Phase 3 watcher tests — REAL filesystem + REAL sqlite, NO mocks (§11.4.27).

Proves reconcile_scan and the watchdog event handler enqueue exactly the real
media files and skip the in-progress / derivative outputs, by querying the real
jobs_db each time.
"""

import os
import sqlite3
import tempfile
import time
import unittest

from media_postprocessor import jobs_db, watcher


def _touch(path: str, content: bytes = b"\x00\x00fake-media-bytes\x00\x00") -> str:
    """Create a real, non-empty file on disk and return its path."""
    with open(path, "wb") as fh:
        fh.write(content)
    return path


def _enqueued_source_paths(db_path: str) -> set:
    """Query the REAL jobs_db for every enqueued source_path."""
    conn = sqlite3.connect(db_path)
    try:
        return {row[0] for row in conn.execute("SELECT source_path FROM jobs")}
    finally:
        conn.close()


def _rows(db_path: str):
    conn = sqlite3.connect(db_path)
    try:
        return conn.execute(
            "SELECT source_path, media_type, status FROM jobs ORDER BY source_path"
        ).fetchall()
    finally:
        conn.close()


class WatcherTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.download_dir = os.path.join(self.tmp.name, "downloads")
        os.makedirs(self.download_dir)
        self.db_path = os.path.join(self.tmp.name, "jobs.db")
        jobs_db.init_db(self.db_path)

    def tearDown(self):
        self.tmp.cleanup()


class TestReconcileScan(WatcherTestBase):
    def _seed_library(self):
        """A real .mp4 (target), .m4a (target), and three non-targets."""
        self.mp4 = _touch(os.path.join(self.download_dir, "sample.mp4"))
        self.m4a = _touch(os.path.join(self.download_dir, "sample.m4a"))
        self.part = _touch(os.path.join(self.download_dir, "sample.part"))
        self.webready = _touch(os.path.join(self.download_dir, "webready-foo.mp4"))
        self.mp3 = _touch(os.path.join(self.download_dir, "bar.mp3"))

    def test_enqueues_only_real_media_targets(self):
        self._seed_library()

        count = watcher.reconcile_scan(self.download_dir, self.db_path)

        # Exactly the .mp4 and .m4a got enqueued.
        self.assertEqual(count, 2)
        enqueued = _enqueued_source_paths(self.db_path)
        self.assertIn(self.mp4, enqueued)
        self.assertIn(self.m4a, enqueued)
        # The .part / webready- / .mp3 did NOT.
        self.assertNotIn(self.part, enqueued)
        self.assertNotIn(self.webready, enqueued)
        self.assertNotIn(self.mp3, enqueued)
        self.assertEqual(len(enqueued), 2)

    def test_media_types_are_correct(self):
        self._seed_library()
        watcher.reconcile_scan(self.download_dir, self.db_path)
        by_path = {r[0]: r[1] for r in _rows(self.db_path)}
        self.assertEqual(by_path[self.mp4], "webready_video")
        self.assertEqual(by_path[self.m4a], "mp3_audio")

    def test_idempotent_second_scan_adds_no_rows(self):
        self._seed_library()

        first = watcher.reconcile_scan(self.download_dir, self.db_path)
        rows_after_first = _rows(self.db_path)

        second = watcher.reconcile_scan(self.download_dir, self.db_path)
        rows_after_second = _rows(self.db_path)

        self.assertEqual(first, 2)
        # INSERT OR IGNORE on UNIQUE source_path → nothing new the 2nd time.
        self.assertEqual(second, 0)
        self.assertEqual(rows_after_first, rows_after_second)
        self.assertEqual(len(rows_after_second), 2)

    def test_accepts_a_live_connection_too(self):
        self._seed_library()
        conn = jobs_db.connect(self.db_path)
        try:
            count = watcher.reconcile_scan(self.download_dir, conn)
        finally:
            conn.close()
        self.assertEqual(count, 2)

    def test_recurses_into_subdirectories(self):
        sub = os.path.join(self.download_dir, "nested", "deeper")
        os.makedirs(sub)
        nested_mp4 = _touch(os.path.join(sub, "deep.mp4"))
        count = watcher.reconcile_scan(self.download_dir, self.db_path)
        self.assertEqual(count, 1)
        self.assertIn(nested_mp4, _enqueued_source_paths(self.db_path))


class TestEventHandler(WatcherTestBase):
    def test_on_created_enqueues_real_mp4(self):
        handler = watcher.DownloadFinishedHandler(self.db_path)
        mp4 = _touch(os.path.join(self.download_dir, "new.mp4"))

        # Drive the handler directly with a real created-file event.
        class _Evt:
            is_directory = False
            src_path = mp4

        handler.on_created(_Evt())

        enqueued = _enqueued_source_paths(self.db_path)
        self.assertIn(mp4, enqueued)
        self.assertEqual(len(enqueued), 1)

    def test_on_created_ignores_in_progress_and_derivative(self):
        handler = watcher.DownloadFinishedHandler(self.db_path)

        for name in ("x.part", "x.ytdl", "x.partial", "webready-x.mp4", "x.mp3"):
            path = _touch(os.path.join(self.download_dir, name))

            class _Evt:
                is_directory = False
                src_path = path

            handler.on_created(_Evt())

        self.assertEqual(_enqueued_source_paths(self.db_path), set())

    def test_on_moved_enqueues_rename_destination(self):
        handler = watcher.DownloadFinishedHandler(self.db_path)
        # metube pattern: writes '<name>.part' then renames to the final name.
        src = os.path.join(self.download_dir, "clip.mp4.part")
        dest = _touch(os.path.join(self.download_dir, "clip.mp4"))

        class _Evt:
            is_directory = False
            src_path = src
            dest_path = dest

        handler.on_moved(_Evt())

        enqueued = _enqueued_source_paths(self.db_path)
        self.assertIn(dest, enqueued)
        self.assertEqual(len(enqueued), 1)


class TestRealObserver(WatcherTestBase):
    """A short real PollingObserver run (best-effort; deterministic test is above)."""

    def test_observer_picks_up_a_created_file(self):
        observer = watcher.start_watching(self.download_dir, self.db_path)
        try:
            mp4 = os.path.join(self.download_dir, "live.mp4")
            _touch(mp4)
            # Poll the real DB until the row appears (PollingObserver interval).
            deadline = time.time() + 15
            found = False
            while time.time() < deadline:
                if mp4 in _enqueued_source_paths(self.db_path):
                    found = True
                    break
                time.sleep(0.25)
            self.assertTrue(found, "real PollingObserver did not enqueue the new file")
        finally:
            observer.stop()
            observer.join(timeout=10)


if __name__ == "__main__":
    unittest.main()
