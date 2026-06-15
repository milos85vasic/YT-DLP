"""Real in-process end-to-end test of the wired orchestrator (service.main()).

NO mocks. Spawns `python -m media_postprocessor.service` as a real subprocess
pointed at a tmp DOWNLOAD_DIR + tmp DB + an ephemeral MP_PORT, drops the
committed fixture sample_video.mp4 into the watched dir, and proves the full
chain watcher -> enqueue -> worker -> transcode -> artifact runs in ONE process:

  * webready-sample_video.mp4 appears on disk,
  * ffprobe confirms h264 + aac + faststart,
  * GET /postprocess/status reports done >= 1.

Then it proves clean shutdown on SIGTERM.

MP_MIN_STABLE_AGE=0 disables the watcher's min-age guard so the test does not
wait 10s for stability. The fixture is also copied (not moved) so on_created
fires; the periodic reconcile (short interval here) is the safety net.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import time
import unittest
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "fixtures", "sample_video.mp4")
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))


def _ffprobe(path):
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"ffprobe failed: {proc.stderr}")
    return json.loads(proc.stdout)


def _free_port():
    import socket
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class TestOrchestratorEndToEnd(unittest.TestCase):
    def setUp(self):
        if shutil.which("ffprobe") is None or shutil.which("ffmpeg") is None:
            self.skipTest("ffmpeg/ffprobe not available")
        if not os.path.exists(FIXTURE):
            self.skipTest("sample_video.mp4 fixture missing")
        import tempfile
        self.tmp = tempfile.mkdtemp(prefix="mpp_it_")
        self.download_dir = os.path.join(self.tmp, "downloads")
        os.makedirs(self.download_dir)
        self.db_path = os.path.join(self.tmp, "jobs.db")
        self.port = _free_port()
        env = dict(os.environ)
        env.update({
            "DOWNLOAD_DIR": self.download_dir,
            "MP_DB_PATH": self.db_path,
            "MP_PORT": str(self.port),
            "MP_MIN_STABLE_AGE": "0",
            "MP_RECONCILE_INTERVAL": "2",
            "PYTHONUNBUFFERED": "1",
        })
        self.proc = subprocess.Popen(
            [sys.executable, "-m", "media_postprocessor.service"],
            cwd=REPO_ROOT, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )

    def tearDown(self):
        if self.proc.poll() is None:
            self.proc.send_signal(signal.SIGKILL)
            self.proc.wait(timeout=10)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _status(self):
        with urllib.request.urlopen(
            f"http://127.0.0.1:{self.port}/postprocess/status", timeout=5
        ) as r:
            return json.loads(r.read().decode())

    def _wait_server(self, timeout=20):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.proc.poll() is not None:
                out = self.proc.stdout.read() if self.proc.stdout else ""
                self.fail(f"service exited early (rc={self.proc.returncode}):\n{out}")
            try:
                self._status()
                return
            except (urllib.error.URLError, ConnectionError, OSError):
                time.sleep(0.2)
        self.fail("server did not come up in time")

    def test_drop_file_gets_processed_end_to_end(self):
        self._wait_server()

        # Drop the fixture into the watched dir. Back-date its mtime so it is
        # immediately stable even where the guard is on.
        dest = os.path.join(self.download_dir, "sample_video.mp4")
        shutil.copy2(FIXTURE, dest)
        old = time.time() - 3600
        os.utime(dest, (old, old))

        artifact = os.path.join(self.download_dir, "webready-sample_video.mp4")
        deadline = time.time() + 60
        while time.time() < deadline:
            if os.path.exists(artifact) and os.path.getsize(artifact) > 0:
                break
            if self.proc.poll() is not None:
                out = self.proc.stdout.read() if self.proc.stdout else ""
                self.fail(f"service died (rc={self.proc.returncode}):\n{out}")
            time.sleep(0.5)
        else:
            self.fail(f"artifact not produced within timeout: {artifact}")

        # ffprobe the process-produced artifact: h264 + aac + faststart.
        info = _ffprobe(artifact)
        codecs = {s.get("codec_name") for s in info.get("streams", [])}
        self.assertIn("h264", codecs, f"expected h264, got {codecs}")
        self.assertIn("aac", codecs, f"expected aac, got {codecs}")
        from media_postprocessor import transcoder
        self.assertTrue(transcoder.has_faststart(artifact), "moov must precede mdat")

        # Status server must report done >= 1.
        status = None
        deadline = time.time() + 15
        while time.time() < deadline:
            status = self._status()
            if status["counts"]["done"] >= 1:
                break
            time.sleep(0.5)
        self.assertIsNotNone(status)
        self.assertTrue(status["healthy"])
        self.assertGreaterEqual(
            status["counts"]["done"], 1, f"expected done>=1, got {status}"
        )

    def test_clean_shutdown_on_sigterm(self):
        self._wait_server()
        self.proc.send_signal(signal.SIGTERM)
        try:
            rc = self.proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            self.fail("service did not shut down within 15s of SIGTERM")
        # Graceful exit: clean return (0) or terminated by the signal itself.
        self.assertIn(rc, (0, -signal.SIGTERM), f"unexpected exit code {rc}")


if __name__ == "__main__":
    unittest.main()
