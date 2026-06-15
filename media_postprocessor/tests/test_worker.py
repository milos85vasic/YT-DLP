"""End-to-end + resume/chaos tests for the Phase 4 worker loop.

REAL ffmpeg + REAL sqlite + the committed fixtures, NO mocks (§11 integration +
§11.4.85 resume/chaos). Every artifact lands in a per-test tmp dir; the
committed fixtures under tests/fixtures/ are only ever read.
"""

import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest

from media_postprocessor import jobs_db, worker
from media_postprocessor.config import Config

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")
SAMPLE_VIDEO = os.path.join(FIXTURES, "sample_video.mp4")
SAMPLE_AUDIO = os.path.join(FIXTURES, "sample_audio.m4a")


def _ffprobe_codecs(path):
    """Return the set of (codec_type, codec_name) tuples in `path` via ffprobe."""
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,codec_name",
         "-of", "default=nw=1", path],
        capture_output=True, text=True, check=True,
    )
    codecs = set()
    ctype = cname = None
    for line in proc.stdout.splitlines():
        if line.startswith("codec_name="):
            cname = line.split("=", 1)[1]
        elif line.startswith("codec_type="):
            ctype = line.split("=", 1)[1]
            codecs.add((ctype, cname))
    return codecs


def _status(db_path, job_id):
    conn = jobs_db.connect(db_path)
    try:
        row = conn.execute(
            "SELECT status, output_path FROM jobs WHERE id=?", (job_id,)
        ).fetchone()
    finally:
        conn.close()
    return row  # (status, output_path) or None


class WorkerTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.downloads = os.path.join(self.tmp.name, "downloads")
        os.makedirs(self.downloads)
        self.db_path = os.path.join(self.tmp.name, "jobs.db")
        jobs_db.init_db(self.db_path)
        self.cfg = Config.from_env(
            {"DOWNLOAD_DIR": self.downloads, "MP_DB_PATH": self.db_path}
        )

    def tearDown(self):
        self.tmp.cleanup()

    def _copy_in(self, fixture):
        dst = os.path.join(self.downloads, os.path.basename(fixture))
        shutil.copy(fixture, dst)
        return dst


class TestEndToEndVideo(WorkerTestBase):
    def test_video_job_runs_to_done_with_valid_webready(self):
        src = self._copy_in(SAMPLE_VIDEO)
        job_id = jobs_db.enqueue(
            self.db_path, src, os.path.getsize(src), int(os.path.getmtime(src)),
            "webready_video",
        )
        # queued -> running -> done
        self.assertEqual(_status(self.db_path, job_id)[0], "queued")

        self.assertTrue(worker.process_one(self.db_path, self.cfg))

        status, output_path = _status(self.db_path, job_id)
        self.assertEqual(status, "done")
        expected = os.path.join(self.downloads, "webready-sample_video.mp4")
        self.assertEqual(output_path, expected)
        self.assertTrue(os.path.exists(expected), "webready file must exist on disk")

        codecs = _ffprobe_codecs(expected)
        self.assertIn(("video", "h264"), codecs)
        self.assertIn(("audio", "aac"), codecs)

    def test_empty_queue_returns_false(self):
        self.assertFalse(worker.process_one(self.db_path, self.cfg))


class TestEndToEndAudio(WorkerTestBase):
    def test_audio_job_runs_to_done_with_valid_mp3(self):
        src = self._copy_in(SAMPLE_AUDIO)
        job_id = jobs_db.enqueue(
            self.db_path, src, os.path.getsize(src), int(os.path.getmtime(src)),
            "mp3_audio",
        )
        self.assertEqual(_status(self.db_path, job_id)[0], "queued")

        self.assertTrue(worker.process_one(self.db_path, self.cfg))

        status, output_path = _status(self.db_path, job_id)
        self.assertEqual(status, "done")
        expected = os.path.join(self.downloads, "sample_audio.mp3")
        self.assertEqual(output_path, expected)
        self.assertTrue(os.path.exists(expected))

        codecs = _ffprobe_codecs(expected)
        self.assertIn(("audio", "mp3"), codecs)


class TestFailedJobMarking(WorkerTestBase):
    def test_missing_source_marks_failed_not_running(self):
        missing = os.path.join(self.downloads, "gone.mp4")
        job_id = jobs_db.enqueue(self.db_path, missing, 0, 0, "webready_video")

        self.assertTrue(worker.process_one(self.db_path, self.cfg))

        status, _ = _status(self.db_path, job_id)
        self.assertEqual(status, "failed", "a failed transcode must not leave 'running'")


class TestResumeChaosSeeded(WorkerTestBase):
    """§11.4.85: a seeded 'running' job (crash mid-transcode) + a stale
    `<out>.partial` must requeue to 'queued', then complete to a VALID 'done'
    with NO `.partial` remaining."""

    def test_requeue_then_complete_no_partial(self):
        src = self._copy_in(SAMPLE_VIDEO)
        job_id = jobs_db.enqueue(
            self.db_path, src, os.path.getsize(src), int(os.path.getmtime(src)),
            "webready_video",
        )

        # Simulate a crash mid-transcode: force status to 'running' and drop a
        # stale partial file alongside the eventual output.
        conn = jobs_db.connect(self.db_path)
        try:
            conn.execute("UPDATE jobs SET status='running' WHERE id=?", (job_id,))
            conn.commit()
        finally:
            conn.close()
        out = os.path.join(self.downloads, "webready-sample_video.mp4")
        stale_partial = out + ".partial"
        with open(stale_partial, "wb") as fh:
            fh.write(b"\x00\x01\x02 garbage from a crashed ffmpeg run")
        self.assertEqual(_status(self.db_path, job_id)[0], "running")
        self.assertTrue(os.path.exists(stale_partial))

        # Resume: requeue_running_on_startup flips running -> queued.
        n = jobs_db.requeue_running_on_startup(self.db_path)
        self.assertEqual(n, 1)
        self.assertEqual(_status(self.db_path, job_id)[0], "queued")

        # Then process_one completes it to a valid 'done' output.
        self.assertTrue(worker.process_one(self.db_path, self.cfg))

        status, output_path = _status(self.db_path, job_id)
        self.assertEqual(status, "done")
        self.assertEqual(output_path, out)
        self.assertTrue(os.path.exists(out))
        self.assertFalse(
            os.path.exists(stale_partial),
            "no stale .partial may remain after a clean completion",
        )
        codecs = _ffprobe_codecs(out)
        self.assertIn(("video", "h264"), codecs)
        self.assertIn(("audio", "aac"), codecs)


class TestRunForeverResumeAndDrain(WorkerTestBase):
    def test_run_forever_resumes_running_then_drains_to_done(self):
        src = self._copy_in(SAMPLE_AUDIO)
        job_id = jobs_db.enqueue(
            self.db_path, src, os.path.getsize(src), int(os.path.getmtime(src)),
            "mp3_audio",
        )
        # Seed as 'running' (crashed worker) so run_forever's startup requeue
        # must recover it.
        conn = jobs_db.connect(self.db_path)
        try:
            conn.execute("UPDATE jobs SET status='running' WHERE id=?", (job_id,))
            conn.commit()
        finally:
            conn.close()

        stop = threading.Event()
        t = threading.Thread(
            target=worker.run_forever, args=(self.db_path, self.cfg, stop)
        )
        t.start()
        try:
            deadline = time.time() + 60
            while time.time() < deadline:
                if _status(self.db_path, job_id)[0] == "done":
                    break
                time.sleep(0.2)
        finally:
            stop.set()
            t.join(timeout=10)

        self.assertFalse(t.is_alive(), "run_forever must stop cleanly on stop_event")
        status, output_path = _status(self.db_path, job_id)
        self.assertEqual(status, "done")
        self.assertTrue(os.path.exists(output_path))


class TestRealSigkillChaos(WorkerTestBase):
    """Optional REAL kill (§11.4.85): launch run_forever in a subprocess
    processing a job, SIGKILL it mid-run, then a fresh worker recovers the job
    to a valid 'done' output."""

    def test_sigkill_then_fresh_worker_recovers(self):
        src = self._copy_in(SAMPLE_VIDEO)
        job_id = jobs_db.enqueue(
            self.db_path, src, os.path.getsize(src), int(os.path.getmtime(src)),
            "webready_video",
        )

        runner = (
            "from media_postprocessor import worker;"
            "from media_postprocessor.config import Config;"
            f"cfg=Config.from_env({{'DOWNLOAD_DIR': {self.downloads!r},"
            f" 'MP_DB_PATH': {self.db_path!r}}});"
            f"worker.run_forever({self.db_path!r}, cfg)"
        )
        repo_root = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        env = dict(os.environ, PYTHONPATH=repo_root)
        proc = subprocess.Popen(
            [sys.executable, "-c", runner], env=env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            # Wait until the worker has claimed the job (status -> running),
            # i.e. it is mid-transcode, then SIGKILL it.
            deadline = time.time() + 30
            claimed = False
            while time.time() < deadline:
                row = _status(self.db_path, job_id)
                if row and row[0] == "running":
                    claimed = True
                    break
                if proc.poll() is not None:
                    break
                time.sleep(0.02)
            self.assertTrue(claimed, "worker subprocess must claim the job before kill")
            proc.send_signal(signal.SIGKILL)
        finally:
            proc.wait(timeout=10)

        # The job is stranded in 'running' (the killed worker never finished).
        self.assertEqual(_status(self.db_path, job_id)[0], "running")

        # A fresh worker recovers it: requeue + drain to a valid done output.
        stop = threading.Event()
        t = threading.Thread(
            target=worker.run_forever, args=(self.db_path, self.cfg, stop)
        )
        t.start()
        try:
            deadline = time.time() + 60
            while time.time() < deadline:
                if _status(self.db_path, job_id)[0] == "done":
                    break
                time.sleep(0.2)
        finally:
            stop.set()
            t.join(timeout=10)

        status, output_path = _status(self.db_path, job_id)
        self.assertEqual(status, "done")
        self.assertTrue(os.path.exists(output_path))
        self.assertFalse(os.path.exists(output_path + ".partial"))
        codecs = _ffprobe_codecs(output_path)
        self.assertIn(("video", "h264"), codecs)
        self.assertIn(("audio", "aac"), codecs)


if __name__ == "__main__":
    unittest.main()
