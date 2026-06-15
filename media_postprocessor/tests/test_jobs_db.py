import os
import sqlite3
import tempfile
import unittest

from media_postprocessor import jobs_db


class JobsDbTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmp.name, "jobs.db")
        jobs_db.init_db(self.db_path)

    def tearDown(self):
        self.tmp.cleanup()


class TestInitDb(JobsDbTestBase):
    def test_jobs_table_exists_with_columns(self):
        conn = sqlite3.connect(self.db_path)
        cols = {row[1] for row in conn.execute("PRAGMA table_info(jobs)")}
        conn.close()
        expected = {
            "id", "source_path", "size", "mtime", "media_type", "status",
            "output_path", "attempts", "error", "created_at", "updated_at",
            "started_at", "finished_at",
        }
        self.assertEqual(cols, expected)

    def test_status_index_exists(self):
        conn = sqlite3.connect(self.db_path)
        idx = {row[1] for row in conn.execute("PRAGMA index_list(jobs)")}
        conn.close()
        self.assertIn("idx_jobs_status", idx)

    def test_wal_mode_active(self):
        conn = sqlite3.connect(self.db_path)
        mode = conn.execute("PRAGMA journal_mode").fetchone()[0]
        conn.close()
        self.assertEqual(mode.lower(), "wal")

    def test_status_check_constraint_rejects_bad_value(self):
        conn = sqlite3.connect(self.db_path)
        with self.assertRaises(sqlite3.IntegrityError):
            conn.execute(
                "INSERT INTO jobs (source_path, status) VALUES (?, ?)",
                ("/x.mp4", "bogus"),
            )
            conn.commit()
        conn.close()


class TestEnqueue(JobsDbTestBase):
    def test_enqueue_inserts_queued_row(self):
        job_id = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1234, 1700000000, "video")
        self.assertIsInstance(job_id, int)
        conn = sqlite3.connect(self.db_path)
        row = conn.execute(
            "SELECT source_path, size, mtime, media_type, status, attempts "
            "FROM jobs WHERE id=?", (job_id,)
        ).fetchone()
        conn.close()
        self.assertEqual(row, ("/downloads/a.mp4", 1234, 1700000000, "video", "queued", 0))

    def test_enqueue_is_idempotent_on_source_path(self):
        first = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        second = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 9, 9, "video")
        self.assertEqual(first, second)
        conn = sqlite3.connect(self.db_path)
        count = conn.execute("SELECT COUNT(*) FROM jobs").fetchone()[0]
        conn.close()
        self.assertEqual(count, 1)

    def test_enqueue_sets_created_and_updated_timestamps(self):
        job_id = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "audio")
        conn = sqlite3.connect(self.db_path)
        created, updated = conn.execute(
            "SELECT created_at, updated_at FROM jobs WHERE id=?", (job_id,)
        ).fetchone()
        conn.close()
        self.assertTrue(created)
        self.assertTrue(updated)


class TestClaimNextJob(JobsDbTestBase):
    def test_claim_returns_none_when_empty(self):
        self.assertIsNone(jobs_db.claim_next_job(self.db_path))

    def test_claim_marks_job_running_and_returns_it(self):
        jid = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        claimed = jobs_db.claim_next_job(self.db_path)
        self.assertIsNotNone(claimed)
        self.assertEqual(claimed["id"], jid)
        self.assertEqual(claimed["source_path"], "/downloads/a.mp4")
        self.assertEqual(claimed["status"], "running")
        conn = sqlite3.connect(self.db_path)
        status, started, attempts = conn.execute(
            "SELECT status, started_at, attempts FROM jobs WHERE id=?", (jid,)
        ).fetchone()
        conn.close()
        self.assertEqual(status, "running")
        self.assertTrue(started)
        self.assertEqual(attempts, 1)

    def test_claim_is_fifo_and_does_not_reclaim_running(self):
        a = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        b = jobs_db.enqueue(self.db_path, "/downloads/b.mp4", 1, 2, "video")
        first = jobs_db.claim_next_job(self.db_path)
        second = jobs_db.claim_next_job(self.db_path)
        third = jobs_db.claim_next_job(self.db_path)
        self.assertEqual(first["id"], a)
        self.assertEqual(second["id"], b)
        self.assertIsNone(third)


class TestMarkDoneFailed(JobsDbTestBase):
    def test_mark_done_sets_status_output_and_finished(self):
        jid = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        jobs_db.claim_next_job(self.db_path)
        jobs_db.mark_done(self.db_path, jid, "/downloads/webready-a.mp4")
        conn = sqlite3.connect(self.db_path)
        status, output, finished, error = conn.execute(
            "SELECT status, output_path, finished_at, error FROM jobs WHERE id=?", (jid,)
        ).fetchone()
        conn.close()
        self.assertEqual(status, "done")
        self.assertEqual(output, "/downloads/webready-a.mp4")
        self.assertTrue(finished)
        self.assertIsNone(error)

    def test_mark_failed_sets_status_and_error(self):
        jid = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        jobs_db.claim_next_job(self.db_path)
        jobs_db.mark_failed(self.db_path, jid, "ffmpeg exit 1")
        conn = sqlite3.connect(self.db_path)
        status, error, finished = conn.execute(
            "SELECT status, error, finished_at FROM jobs WHERE id=?", (jid,)
        ).fetchone()
        conn.close()
        self.assertEqual(status, "failed")
        self.assertEqual(error, "ffmpeg exit 1")
        self.assertTrue(finished)


class TestRequeueRunningOnStartup(JobsDbTestBase):
    def test_running_jobs_become_queued_others_untouched(self):
        a = jobs_db.enqueue(self.db_path, "/downloads/a.mp4", 1, 2, "video")
        b = jobs_db.enqueue(self.db_path, "/downloads/b.mp4", 1, 2, "video")
        c = jobs_db.enqueue(self.db_path, "/downloads/c.mp4", 1, 2, "video")
        # a -> running (simulating a crash mid-flight)
        jobs_db.claim_next_job(self.db_path)
        # c -> done
        jobs_db.claim_next_job(self.db_path)  # claims b
        jobs_db.mark_done(self.db_path, b, "/downloads/webready-b.mp4")

        requeued = jobs_db.requeue_running_on_startup(self.db_path)
        self.assertEqual(requeued, 1)

        conn = sqlite3.connect(self.db_path)
        statuses = dict(conn.execute("SELECT id, status FROM jobs"))
        conn.close()
        self.assertEqual(statuses[a], "queued")   # was running -> requeued
        self.assertEqual(statuses[b], "done")     # untouched
        self.assertEqual(statuses[c], "queued")   # never claimed


if __name__ == "__main__":
    unittest.main()
