# Dual-Version Media Pipeline — Phase 1 Implementation Plan

> **Revision:** 1
> **Last modified:** 2026-06-15T00:00:00Z

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `media_postprocessor/` Python sidecar skeleton — package layout, a crash-safe SQLite (WAL) jobs DB, ffprobe-based media classification, a minimal stdlib HTTP status API, its OpenAPI contract, and the docker-compose service + nginx proxy wiring — exactly as locked in the approved design spec (`docs/superpowers/specs/2026-06-15-dual-version-media-pipeline-design.md`).

**Architecture:** A standalone Python service runs inside a Podman container with system ffmpeg/ffprobe and a host-mounted `/downloads`. Phase 1 lays the foundation: a `jobs_db.py` module owning the exact §5.2 schema with WAL PRAGMAs and atomic claim/done/fail/requeue operations; a `media_probe.py` module classifying files into `webready_video` / `mp3_audio` / `skip` via extension rules + real ffprobe; a `config.py` reading env; and a stdlib `http.server`-based status endpoint in `service.py`. No transcoding, watcher, or UI yet — those are later phases. The contract is authored and validated before the HTTP code.

**Tech Stack:** Python 3.11 (stdlib `sqlite3`, `http.server`, `subprocess`, `unittest`/`pytest`), system `ffmpeg`/`ffprobe` 8.1.1, `watchdog` (declared in requirements for Phase 3, unused in Phase 1 code), Podman 5.x + podman-compose, nginx (dashboard proxy template), OpenAPI 3.0.3.

---

## File Structure

Every file Phase 1 creates or modifies, with its single responsibility:

| File | Create/Modify | Responsibility |
|---|---|---|
| `media_postprocessor/__init__.py` | Create | Package marker + version string. |
| `media_postprocessor/config.py` | Create | Read+validate env (DOWNLOAD_DIR, DB path, PORT, MAX_CONCURRENCY); single `Config` dataclass. |
| `media_postprocessor/jobs_db.py` | Create | SQLite WAL jobs DB: schema (§5.2), PRAGMAs (§5.1), `init_db`/`enqueue`/`claim_next_job`/`mark_done`/`mark_failed`/`requeue_running_on_startup`. |
| `media_postprocessor/media_probe.py` | Create | ffprobe-based media-kind detection + `classify_target(path)` → `webready_video`/`mp3_audio`/`skip`. |
| `media_postprocessor/service.py` | Create | stdlib `http.server` status API: `GET /postprocess/status`, `GET /postprocess/jobs`. App entrypoint. |
| `media_postprocessor/requirements.txt` | Create | `watchdog` only (sqlite3/ffmpeg are system/stdlib). |
| `media_postprocessor/Dockerfile` | Create | Python base + system ffmpeg; runs `service.py`. Built for Podman. |
| `media_postprocessor/tests/__init__.py` | Create | Test package marker. |
| `media_postprocessor/tests/test_jobs_db.py` | Create | Unit tests for jobs_db against a real tmp sqlite file (no mocks). |
| `media_postprocessor/tests/test_media_probe.py` | Create | Pure unit tests (extension logic) + integration test running real ffprobe on a generated fixture. |
| `media_postprocessor/tests/test_service.py` | Create | Integration test hitting the real HTTP server against a real tmp DB. |
| `contracts/media-postprocessor.openapi.yaml` | Create | OpenAPI 3.0.3 contract: `GET /postprocess/status`, `GET /postprocess/jobs`. |
| `docker-compose.yml` | Modify | Add `media_postprocessor` service (no-vpn profile) with resource-limit block + bounded-concurrency env. |
| `dashboard/nginx.conf.template` | Modify | Add `/api/postprocess/*` location using resolver + `set $var` + rewrite + proxy_pass. |

---

## Task 1: Package skeleton + config module

**Files:**
- Create: `media_postprocessor/__init__.py`
- Create: `media_postprocessor/tests/__init__.py`
- Create: `media_postprocessor/config.py`
- Test: `media_postprocessor/tests/test_config.py`

- [ ] **Step 1: Create the package markers**

Create `media_postprocessor/__init__.py`:

```python
"""media_postprocessor — dual-version media derivation sidecar (Phase 1 skeleton)."""

__version__ = "0.1.0"
```

Create `media_postprocessor/tests/__init__.py`:

```python
```

(empty file — just the package marker)

- [ ] **Step 2: Write the failing test for config**

Create `media_postprocessor/tests/test_config.py`:

```python
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'media_postprocessor.config'`.

- [ ] **Step 4: Write the minimal config implementation**

Create `media_postprocessor/config.py`:

```python
"""Environment-driven configuration for media_postprocessor (Phase 1)."""

from dataclasses import dataclass
from typing import Mapping


@dataclass(frozen=True)
class Config:
    download_dir: str
    db_path: str
    port: int
    max_concurrency: int

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> "Config":
        download_dir = env.get("DOWNLOAD_DIR", "/downloads")
        db_path = env.get(
            "MP_DB_PATH", f"{download_dir}/.media_postprocessor/jobs.db"
        )
        try:
            port = int(env.get("MP_PORT", "8089"))
            max_concurrency = int(env.get("MP_MAX_CONCURRENCY", "1"))
        except ValueError as exc:
            raise ValueError(f"invalid integer config value: {exc}") from exc
        return cls(
            download_dir=download_dir,
            db_path=db_path,
            port=port,
            max_concurrency=max_concurrency,
        )
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_config.py -v`
Expected: PASS — 3 passed.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git checkout -b media-postprocessor-phase1
git add media_postprocessor/__init__.py media_postprocessor/tests/__init__.py media_postprocessor/config.py media_postprocessor/tests/test_config.py
git commit -m "feat(media_postprocessor): package skeleton + env config module"
```

---

## Task 2: jobs_db — init_db with exact §5.2 schema and §5.1 PRAGMAs

**Files:**
- Create: `media_postprocessor/jobs_db.py`
- Test: `media_postprocessor/tests/test_jobs_db.py`

- [ ] **Step 1: Write the failing test for init_db + PRAGMAs**

Create `media_postprocessor/tests/test_jobs_db.py`:

```python
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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'media_postprocessor.jobs_db'`.

- [ ] **Step 3: Write init_db + connection helper (schema §5.2, PRAGMAs §5.1)**

Create `media_postprocessor/jobs_db.py`:

```python
"""SQLite (WAL) crash-safe jobs DB for media_postprocessor.

Schema is locked from the design spec §5.2; PRAGMAs from §5.1.
"""

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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py -v`
Expected: PASS — 4 passed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/jobs_db.py media_postprocessor/tests/test_jobs_db.py
git commit -m "feat(jobs_db): init_db with exact §5.2 schema + §5.1 WAL PRAGMAs"
```

---

## Task 3: jobs_db — enqueue (idempotent on UNIQUE source_path)

**Files:**
- Modify: `media_postprocessor/jobs_db.py`
- Test: `media_postprocessor/tests/test_jobs_db.py`

- [ ] **Step 1: Add the failing test for enqueue**

Append this class to `media_postprocessor/tests/test_jobs_db.py` (before the `if __name__` guard):

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestEnqueue -v`
Expected: FAIL — `AttributeError: module 'media_postprocessor.jobs_db' has no attribute 'enqueue'`.

- [ ] **Step 3: Implement enqueue + a timestamp helper**

Add to `media_postprocessor/jobs_db.py` (after `init_db`):

```python
import datetime


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
```

Add `import datetime` to the top with the other imports (it may live with `import os`/`import sqlite3`).

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestEnqueue -v`
Expected: PASS — 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/jobs_db.py media_postprocessor/tests/test_jobs_db.py
git commit -m "feat(jobs_db): idempotent enqueue on UNIQUE source_path"
```

---

## Task 4: jobs_db — claim_next_job (atomic UPDATE...RETURNING)

**Files:**
- Modify: `media_postprocessor/jobs_db.py`
- Test: `media_postprocessor/tests/test_jobs_db.py`

- [ ] **Step 1: Add the failing test for claim_next_job**

Append this class to `media_postprocessor/tests/test_jobs_db.py` (before the `if __name__` guard):

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestClaimNextJob -v`
Expected: FAIL — `AttributeError: module 'media_postprocessor.jobs_db' has no attribute 'claim_next_job'`.

- [ ] **Step 3: Implement claim_next_job (atomic, smallest queued id first)**

Add to `media_postprocessor/jobs_db.py`:

```python
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestClaimNextJob -v`
Expected: PASS — 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/jobs_db.py media_postprocessor/tests/test_jobs_db.py
git commit -m "feat(jobs_db): atomic claim_next_job via UPDATE...RETURNING"
```

---

## Task 5: jobs_db — mark_done / mark_failed

**Files:**
- Modify: `media_postprocessor/jobs_db.py`
- Test: `media_postprocessor/tests/test_jobs_db.py`

- [ ] **Step 1: Add the failing test for mark_done / mark_failed**

Append this class to `media_postprocessor/tests/test_jobs_db.py` (before the `if __name__` guard):

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestMarkDoneFailed -v`
Expected: FAIL — `AttributeError: module 'media_postprocessor.jobs_db' has no attribute 'mark_done'`.

- [ ] **Step 3: Implement mark_done + mark_failed**

Add to `media_postprocessor/jobs_db.py`:

```python
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestMarkDoneFailed -v`
Expected: PASS — 2 passed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/jobs_db.py media_postprocessor/tests/test_jobs_db.py
git commit -m "feat(jobs_db): mark_done and mark_failed terminal transitions"
```

---

## Task 6: jobs_db — requeue_running_on_startup (crash recovery §5.3)

**Files:**
- Modify: `media_postprocessor/jobs_db.py`
- Test: `media_postprocessor/tests/test_jobs_db.py`

- [ ] **Step 1: Add the failing test for crash recovery**

Append this class to `media_postprocessor/tests/test_jobs_db.py` (before the `if __name__` guard):

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py::TestRequeueRunningOnStartup -v`
Expected: FAIL — `AttributeError: module 'media_postprocessor.jobs_db' has no attribute 'requeue_running_on_startup'`.

- [ ] **Step 3: Implement requeue_running_on_startup**

Add to `media_postprocessor/jobs_db.py`:

```python
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_jobs_db.py -v`
Expected: PASS — all jobs_db tests green (init + enqueue + claim + done/failed + requeue).

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/jobs_db.py media_postprocessor/tests/test_jobs_db.py
git commit -m "feat(jobs_db): requeue_running_on_startup crash recovery (§5.3)"
```

---

## Task 7: media_probe — classify_target extension rules (pure unit)

**Files:**
- Create: `media_postprocessor/media_probe.py`
- Test: `media_postprocessor/tests/test_media_probe.py`

- [ ] **Step 1: Write the failing pure-unit test for classify_target**

Create `media_postprocessor/tests/test_media_probe.py`:

```python
import unittest

from media_postprocessor import media_probe


class TestClassifyByExtension(unittest.TestCase):
    def test_video_extensions_map_to_webready_video(self):
        for name in ["clip.mp4", "movie.MKV", "vid.webm", "x.avi", "y.mov", "z.m4v"]:
            self.assertEqual(media_probe.classify_target(name), "webready_video", name)

    def test_audio_extensions_map_to_mp3_audio(self):
        for name in ["song.m4a", "track.opus", "x.flac", "y.wav", "z.aac", "w.ogg"]:
            self.assertEqual(media_probe.classify_target(name), "mp3_audio", name)

    def test_existing_mp3_is_skipped(self):
        self.assertEqual(media_probe.classify_target("track.mp3"), "skip")

    def test_webready_prefix_is_skipped(self):
        self.assertEqual(media_probe.classify_target("webready-clip.mp4"), "skip")
        self.assertEqual(
            media_probe.classify_target("/downloads/webready-clip.mp4"), "skip"
        )

    def test_unknown_extension_is_skipped(self):
        self.assertEqual(media_probe.classify_target("notes.txt"), "skip")
        self.assertEqual(media_probe.classify_target("archive.zip"), "skip")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_media_probe.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'media_postprocessor.media_probe'`.

- [ ] **Step 3: Implement the pure extension classifier**

Create `media_postprocessor/media_probe.py`:

```python
"""ffprobe-based media classification for media_postprocessor (Phase 1).

classify_target() is the pure extension+skip-rule classifier (§4, §10);
probe_media_kind() runs real ffprobe and is used by integration tests and
later phases to refine the decision.
"""

import json
import os
import subprocess

VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv", ".wmv", ".ts"}
AUDIO_EXTS = {".m4a", ".opus", ".flac", ".wav", ".aac", ".ogg", ".oga", ".wma"}


def classify_target(path: str) -> str:
    """Return 'webready_video' | 'mp3_audio' | 'skip' from name rules (§4, §10).

    Skips derivative outputs: a 'webready-' basename prefix and any '.mp3'
    so we never derive from a derivative.
    """
    base = os.path.basename(path)
    lower = base.lower()
    if lower.startswith("webready-"):
        return "skip"
    ext = os.path.splitext(lower)[1]
    if ext == ".mp3":
        return "skip"
    if ext in VIDEO_EXTS:
        return "webready_video"
    if ext in AUDIO_EXTS:
        return "mp3_audio"
    return "skip"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_media_probe.py -v`
Expected: PASS — 5 passed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/media_probe.py media_postprocessor/tests/test_media_probe.py
git commit -m "feat(media_probe): classify_target extension + skip rules (§4, §10)"
```

---

## Task 8: media_probe — probe_media_kind via real ffprobe (integration)

**Files:**
- Modify: `media_postprocessor/media_probe.py`
- Test: `media_postprocessor/tests/test_media_probe.py`

- [ ] **Step 1: Add the failing integration test (real ffmpeg fixture + real ffprobe)**

Append this class to `media_postprocessor/tests/test_media_probe.py` (before the `if __name__` guard):

```python
import os
import shutil
import subprocess
import tempfile


def _have(tool):
    return shutil.which(tool) is not None


@unittest.skipUnless(_have("ffmpeg") and _have("ffprobe"), "ffmpeg/ffprobe required")
class TestProbeMediaKindReal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.video = os.path.join(self.tmp.name, "sample.mp4")
        self.audio = os.path.join(self.tmp.name, "sample_audio.m4a")
        # Tiny AV sample: 1s testsrc video + 1s sine audio.
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "testsrc=duration=1:size=128x128:rate=10",
             "-f", "lavfi", "-i", "sine=frequency=1000:duration=1",
             "-shortest", "-pix_fmt", "yuv420p", self.video],
            check=True, capture_output=True,
        )
        # Audio-only sample.
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "sine=frequency=440:duration=1", "-vn", self.audio],
            check=True, capture_output=True,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_fixtures_exist_and_nonempty(self):
        # ARTIFACT rule: stat the real generated files (§11.4 ARTIFACT).
        self.assertGreater(os.path.getsize(self.video), 0)
        self.assertGreater(os.path.getsize(self.audio), 0)

    def test_probe_detects_video(self):
        self.assertEqual(media_probe.probe_media_kind(self.video), "video")

    def test_probe_detects_audio(self):
        self.assertEqual(media_probe.probe_media_kind(self.audio), "audio")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_media_probe.py::TestProbeMediaKindReal -v`
Expected: FAIL — `AttributeError: module 'media_postprocessor.media_probe' has no attribute 'probe_media_kind'`.

- [ ] **Step 3: Implement probe_media_kind via real ffprobe**

Add to `media_postprocessor/media_probe.py`:

```python
def probe_media_kind(path: str) -> str:
    """Run real ffprobe → 'video' | 'audio' | 'skip'.

    'video' if any video stream is present (excluding attached-pic cover art),
    'audio' if no video but an audio stream is present, else 'skip'.
    """
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", path],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return "skip"
    try:
        streams = json.loads(proc.stdout).get("streams", [])
    except json.JSONDecodeError:
        return "skip"
    has_audio = False
    for s in streams:
        if s.get("codec_type") == "video" and s.get("disposition", {}).get(
            "attached_pic", 0
        ) != 1:
            return "video"
        if s.get("codec_type") == "audio":
            has_audio = True
    return "audio" if has_audio else "skip"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_media_probe.py -v`
Expected: PASS — all media_probe tests green (extension unit + 3 real-ffprobe integration).

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/media_probe.py media_postprocessor/tests/test_media_probe.py
git commit -m "feat(media_probe): probe_media_kind via real ffprobe (integration)"
```

---

## Task 9: OpenAPI contract for the status API

**Files:**
- Create: `contracts/media-postprocessor.openapi.yaml`

- [ ] **Step 1: Author the contract**

Create `contracts/media-postprocessor.openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: Media Postprocessor API
  description: |
    Contract for the media_postprocessor sidecar status API, exposed through
    the dashboard nginx proxy at /api/postprocess/*. All endpoints return JSON.
  version: 1.0.0
  contact:
    name: YT-DLP Project
servers:
  - url: http://localhost:9090/api/postprocess
    description: Dashboard proxy (no-VPN)
  - url: http://localhost:8089/postprocess
    description: media_postprocessor direct (no-VPN)

paths:
  /status:
    get:
      summary: Overall postprocessor status
      description: Returns aggregate job counts per state plus a health flag.
      responses:
        '200':
          description: Status response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/StatusResponse'

  /jobs:
    get:
      summary: List jobs with state
      description: Returns all jobs with their derived state.
      responses:
        '200':
          description: Jobs list
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/JobsResponse'

components:
  schemas:
    StatusResponse:
      type: object
      required: [healthy, counts]
      properties:
        healthy:
          type: boolean
        counts:
          type: object
          required: [queued, running, done, failed, canceled]
          properties:
            queued:
              type: integer
            running:
              type: integer
            done:
              type: integer
            failed:
              type: integer
            canceled:
              type: integer
    JobsResponse:
      type: object
      required: [jobs]
      properties:
        jobs:
          type: array
          items:
            $ref: '#/components/schemas/Job'
    Job:
      type: object
      required: [id, source_path, media_type, status, attempts]
      properties:
        id:
          type: integer
        source_path:
          type: string
        media_type:
          type: string
        status:
          type: string
          enum: [queued, running, done, failed, canceled]
        output_path:
          type: string
          nullable: true
        attempts:
          type: integer
        error:
          type: string
          nullable: true
```

- [ ] **Step 2: Validate the YAML parses**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -c "import yaml; d=yaml.safe_load(open('contracts/media-postprocessor.openapi.yaml')); print(d['openapi'], list(d['paths']))"`
Expected output: `3.0.3 ['/status', '/jobs']`

- [ ] **Step 3: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add contracts/media-postprocessor.openapi.yaml
git commit -m "feat(contracts): media-postprocessor OpenAPI 3.0.3 status contract"
```

---

## Task 10: service.py — stdlib HTTP status API matching the contract

**Files:**
- Create: `media_postprocessor/service.py`
- Test: `media_postprocessor/tests/test_service.py`

- [ ] **Step 1: Write the failing integration test against the real HTTP server**

Create `media_postprocessor/tests/test_service.py`:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_service.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'media_postprocessor.service'`.

- [ ] **Step 3: Implement service.py (status counts + jobs list + main)**

Create `media_postprocessor/service.py`:

```python
"""Minimal stdlib HTTP status API for media_postprocessor (Phase 1).

Serves GET /postprocess/status and GET /postprocess/jobs, matching
contracts/media-postprocessor.openapi.yaml. No transcoding here.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from media_postprocessor import jobs_db
from media_postprocessor.config import Config

_STATES = ("queued", "running", "done", "failed", "canceled")


def _counts(db_path: str) -> dict:
    conn = jobs_db.connect(db_path)
    try:
        rows = dict(conn.execute("SELECT status, COUNT(*) FROM jobs GROUP BY status"))
    finally:
        conn.close()
    return {state: int(rows.get(state, 0)) for state in _STATES}


def _jobs(db_path: str) -> list:
    conn = jobs_db.connect(db_path)
    try:
        rows = conn.execute(
            "SELECT id, source_path, media_type, status, output_path, attempts, error "
            "FROM jobs ORDER BY id"
        ).fetchall()
    finally:
        conn.close()
    return [
        {
            "id": r[0],
            "source_path": r[1],
            "media_type": r[2],
            "status": r[3],
            "output_path": r[4],
            "attempts": r[5],
            "error": r[6],
        }
        for r in rows
    ]


def _make_handler(cfg: Config):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, code, payload):
            body = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == "/postprocess/status":
                self._send(200, {"healthy": True, "counts": _counts(cfg.db_path)})
            elif self.path == "/postprocess/jobs":
                self._send(200, {"jobs": _jobs(cfg.db_path)})
            else:
                self._send(404, {"error": "not found"})

        def log_message(self, *args):
            pass  # silence default stderr access logging

    return Handler


def build_server(cfg: Config) -> ThreadingHTTPServer:
    """Build (do not start) the HTTP server bound to cfg.port."""
    return ThreadingHTTPServer(("0.0.0.0", cfg.port), _make_handler(cfg))


def main() -> None:
    cfg = Config.from_env(os.environ)
    jobs_db.init_db(cfg.db_path)
    jobs_db.requeue_running_on_startup(cfg.db_path)
    server = build_server(cfg)
    print(f"media_postprocessor listening on :{cfg.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/tests/test_service.py -v`
Expected: PASS — 3 passed.

- [ ] **Step 5: Run the full module test suite**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/ -v`
Expected: PASS — all config, jobs_db, media_probe, service tests green.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/service.py media_postprocessor/tests/test_service.py
git commit -m "feat(service): stdlib HTTP status+jobs API matching contract"
```

---

## Task 11: requirements.txt + Dockerfile (Podman build with ffmpeg)

**Files:**
- Create: `media_postprocessor/requirements.txt`
- Create: `media_postprocessor/Dockerfile`

- [ ] **Step 1: Create requirements.txt**

Create `media_postprocessor/requirements.txt`:

```text
# Phase 1: only the watcher lib (used in Phase 3). sqlite3 is stdlib;
# ffmpeg/ffprobe are system binaries installed in the Dockerfile.
watchdog>=4.0
```

- [ ] **Step 2: Create the Dockerfile (ffmpeg base, runs service.py)**

Create `media_postprocessor/Dockerfile`:

```dockerfile
# Built for Podman (host has podman 5.x + ffmpeg 8.1.1; docker is absent).
FROM python:3.11-slim

# System ffmpeg + ffprobe (the transcode/probe engine — §6 native CLI).
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /app/media_postprocessor/requirements.txt
RUN pip install --no-cache-dir -r /app/media_postprocessor/requirements.txt

# Copy the whole package dir into /app/media_postprocessor so that
# `python -m media_postprocessor.service` resolves `from media_postprocessor import ...`.
# Build context is ./media_postprocessor, so "." is the package contents.
COPY . /app/media_postprocessor

ENV PYTHONPATH=/app
ENV DOWNLOAD_DIR=/downloads
ENV MP_DB_PATH=/downloads/.media_postprocessor/jobs.db
ENV MP_PORT=8089
ENV MP_MAX_CONCURRENCY=1
EXPOSE 8089

CMD ["python", "-m", "media_postprocessor.service"]
```

- [ ] **Step 3: Build the image with Podman and verify ffprobe is present**

Run:
```bash
cd /Volumes/T7/Projects/ytdlp
podman build -t media_postprocessor:phase1 ./media_postprocessor
podman run --rm media_postprocessor:phase1 ffprobe -version
```
Expected: build succeeds; final command prints a line starting with `ffprobe version`.

- [ ] **Step 4: Verify the service starts and answers /postprocess/status in-container**

Run:
```bash
cd /Volumes/T7/Projects/ytdlp
podman run --rm -d --name mp_smoke -p 8089:8089 media_postprocessor:phase1
sleep 2
curl -s http://localhost:8089/postprocess/status
podman stop mp_smoke
```
Expected: `curl` prints `{"healthy": true, "counts": {"queued": 0, "running": 0, "done": 0, "failed": 0, "canceled": 0}}`.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add media_postprocessor/requirements.txt media_postprocessor/Dockerfile
git commit -m "feat(media_postprocessor): requirements + Podman Dockerfile with ffmpeg"
```

---

## Task 12: docker-compose service with resource limits + bounded concurrency

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add the media_postprocessor service**

In `docker-compose.yml`, insert the following service block immediately after the `dashboard:` service block (after its closing line `restart: unless-stopped`, before the `watchtower:` service). Indentation is two spaces under `services:`:

```yaml
  media_postprocessor:
    build:
      context: ./media_postprocessor
      dockerfile: Dockerfile
    container_name: media-postprocessor
    profiles:
      - no-vpn
    user: "${PUID}:${PGID}"
    # OOM-cascade lesson (§9): postprocessor is the FIRST sacrificed — never
    # the download/queue services. Keep oom_score_adj highest here.
    mem_limit: 1g
    memswap_limit: 1g
    pids_limit: 256
    oom_score_adj: 1000
    environment:
      - DOWNLOAD_DIR=/downloads
      - MP_DB_PATH=/downloads/.media_postprocessor/jobs.db
      - MP_PORT=8089
      - MP_MAX_CONCURRENCY=1
      - TZ=Europe/Moscow
    volumes:
      - ${DOWNLOAD_DIR}:/downloads:rw
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

- [ ] **Step 2: Validate the compose file parses (Podman)**

Run: `cd /Volumes/T7/Projects/ytdlp && podman-compose --profile no-vpn config >/dev/null && echo COMPOSE_OK`
Expected output: `COMPOSE_OK` (and no parse errors above it).

- [ ] **Step 3: Assert the new service carries the full resource-limit block**

Run:
```bash
cd /Volumes/T7/Projects/ytdlp
podman-compose --profile no-vpn config 2>/dev/null | grep -A30 'media_postprocessor:' | grep -E 'mem_limit|memswap_limit|pids_limit|oom_score_adj|MP_MAX_CONCURRENCY'
```
Expected: five lines printed — `mem_limit`, `memswap_limit`, `pids_limit`, `oom_score_adj`, and `MP_MAX_CONCURRENCY` all present.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add docker-compose.yml
git commit -m "feat(compose): add media_postprocessor service with §9 resource limits"
```

---

## Task 13: nginx — /api/postprocess/* proxy location

**Files:**
- Modify: `dashboard/nginx.conf.template`

- [ ] **Step 1: Add the proxy location**

In `dashboard/nginx.conf.template`, insert the following location block immediately after the `location /api/aborted-history {` block's closing `}` and before the `location /socket.io/ {` block. Match the existing resolver + `set $var` + rewrite + proxy_pass idiom exactly:

```nginx
    location /api/postprocess/ {
        resolver ${RESOLVER} valid=10s;
        set $postprocess_backend http://media-postprocessor:8089;
        rewrite ^/api/postprocess/(.*) /postprocess/$1 break;
        proxy_pass $postprocess_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
```

- [ ] **Step 2: Verify the block was inserted with the right rewrite target**

Run:
```bash
cd /Volumes/T7/Projects/ytdlp
grep -A3 'location /api/postprocess/' dashboard/nginx.conf.template
```
Expected: prints the location line, the `resolver ${RESOLVER}` line, the `set $postprocess_backend http://media-postprocessor:8089;` line, and the `rewrite ^/api/postprocess/(.*) /postprocess/$1 break;` line.

- [ ] **Step 3: Verify nginx config validity after envsubst (using the dashboard image)**

Run:
```bash
cd /Volumes/T7/Projects/ytdlp
RESOLVER=127.0.0.11 envsubst '${RESOLVER}' < dashboard/nginx.conf.template > /tmp/mp_nginx_test.conf
podman run --rm -v /tmp/mp_nginx_test.conf:/etc/nginx/conf.d/default.conf:ro nginx:alpine nginx -t
```
Expected: `nginx: configuration file /etc/nginx/nginx.conf test is successful`.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add dashboard/nginx.conf.template
git commit -m "feat(nginx): proxy /api/postprocess/* to media_postprocessor:8089"
```

---

## Task 14: Phase 1 full-suite green + .gitignore the local DB

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Ignore the runtime DB + its WAL sidecars (regenerated by init_db)**

Append to `.gitignore`:

```gitignore
# media_postprocessor runtime jobs DB (regenerated by jobs_db.init_db on boot)
**/.media_postprocessor/jobs.db
**/.media_postprocessor/jobs.db-wal
**/.media_postprocessor/jobs.db-shm
media_postprocessor/**/__pycache__/
```

- [ ] **Step 2: Run the entire media_postprocessor test suite from a clean checkout state**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -m pytest media_postprocessor/ -v`
Expected: PASS — every test across `test_config.py`, `test_jobs_db.py`, `test_media_probe.py`, `test_service.py` green; the ffprobe integration tests run (not skipped) because ffmpeg 8.1.1 is on the host.

- [ ] **Step 3: Confirm the contract still parses**

Run: `cd /Volumes/T7/Projects/ytdlp && python3 -c "import yaml; yaml.safe_load(open('contracts/media-postprocessor.openapi.yaml')); print('CONTRACT_OK')"`
Expected output: `CONTRACT_OK`

- [ ] **Step 4: Commit**

```bash
cd /Volumes/T7/Projects/ytdlp
git add .gitignore
git commit -m "chore(media_postprocessor): gitignore runtime jobs DB + WAL sidecars"
```

---

## Later phases (outline)

These are deliberately NOT detailed here — each becomes its own bite-sized plan when Phase 1 lands and is reviewed.

- **Phase 2 — ffmpeg derivation.** Implement the locked §4.1 video recipe (`webready-<base>.mp4`, H.264+AAC, faststart, AAC-passthrough + HDR/VFR/4K/subtitle/multichannel edge cases) and §4.2 audio recipe (`<base>.mp3`, 320k CBR). Atomic `.partial`-in-dest-dir + `os.replace` on exit 0 (§5.4). ffprobe anti-bluff validation before `done` (§5.5). Bounded worker pool + nice/ionice (§9).
- **Phase 3 — Watcher + reconcile + backfill.** `watchdog` PollingObserver on the network mount, periodic full-scan diffing the library against the jobs table (= one-time backfill), min-age/stable-size mid-write filter, skip rules (§10).
- **Phase 4 — Resume / crash-safety + chaos.** SIGKILL-mid-transcode → restart → resume-to-valid-complete; zero half-files; stress (N concurrent) (§11.4.85).
- **Phase 5 — API + dashboard UI + landing indicator.** `/jobs/{id}`, `/jobs/{id}/retry`, `/health`, `/summary`; Angular `STATE_META` new states + Retry action (strict typing, no `any`); landing compact indicator (§7, §8).
- **Phase 6 — Full test matrix + Challenge + helixqa.** `download_then_webready_challenge.sh` (ARTIFACT rule), security (path-traversal / arg-injection), helixqa bank entry (§11).
- **Phase 7 — docs/features wiring + video-confirmation + release.** docs_chain contexts, HelixAgent video confirmation harness, four-format exports, prefixed release tag, multi-upstream push (§12, §13).
