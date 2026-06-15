import json
import os
import tempfile
import threading
import unittest
import urllib.request

from media_postprocessor import jobs_db
from media_postprocessor.config import Config
from media_postprocessor.service import build_server


class TestServiceEndpoints(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        db_path = os.path.join(self.tmp.name, "jobs.db")
        jobs_db.init_db(db_path)
        jobs_db.enqueue(db_path, "/downloads/a.mp4", 1, 2, "video")
        b = jobs_db.enqueue(db_path, "/downloads/b.m4a", 1, 2, "audio")
        jobs_db.claim_next_job(db_path)  # a -> running
        jobs_db.claim_next_job(db_path)  # b -> running
        jobs_db.mark_done(db_path, b, "/downloads/b.mp3")
        cfg = Config.from_env({"MP_DB_PATH": db_path, "MP_PORT": "0"})
        self.server = build_server(cfg)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.tmp.cleanup()

    def _get(self, path):
        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}{path}") as r:
            return r.status, json.loads(r.read().decode())

    def test_status_returns_counts(self):
        status, body = self._get("/postprocess/status")
        self.assertEqual(status, 200)
        self.assertTrue(body["healthy"])
        self.assertEqual(body["counts"]["running"], 1)
        self.assertEqual(body["counts"]["done"], 1)
        self.assertEqual(body["counts"]["queued"], 0)

    def test_jobs_returns_list(self):
        status, body = self._get("/postprocess/jobs")
        self.assertEqual(status, 200)
        self.assertEqual(len(body["jobs"]), 2)
        paths = {j["source_path"] for j in body["jobs"]}
        self.assertEqual(paths, {"/downloads/a.mp4", "/downloads/b.m4a"})

    def test_unknown_path_404(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self._get("/nope")
        self.assertEqual(ctx.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
