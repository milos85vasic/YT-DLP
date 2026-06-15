import os
import unittest

from media_postprocessor.config import Config


class TestConfig(unittest.TestCase):
    def test_defaults(self):
        cfg = Config.from_env({})
        self.assertEqual(cfg.download_dir, "/downloads")
        self.assertEqual(cfg.db_path, "/downloads/.media_postprocessor/jobs.db")
        self.assertEqual(cfg.port, 8089)
        self.assertEqual(cfg.max_concurrency, 1)

    def test_env_overrides(self):
        env = {
            "DOWNLOAD_DIR": "/data",
            "MP_DB_PATH": "/data/jobs.db",
            "MP_PORT": "9099",
            "MP_MAX_CONCURRENCY": "2",
        }
        cfg = Config.from_env(env)
        self.assertEqual(cfg.download_dir, "/data")
        self.assertEqual(cfg.db_path, "/data/jobs.db")
        self.assertEqual(cfg.port, 9099)
        self.assertEqual(cfg.max_concurrency, 2)

    def test_invalid_port_raises(self):
        with self.assertRaises(ValueError):
            Config.from_env({"MP_PORT": "not-a-number"})


if __name__ == "__main__":
    unittest.main()
