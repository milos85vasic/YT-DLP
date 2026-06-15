"""Minimal stdlib HTTP status API for media_postprocessor (Phase 1).

Serves GET /postprocess/status and GET /postprocess/jobs, matching
contracts/media-postprocessor.openapi.yaml. No transcoding here.
"""

import json
import os
import signal
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from media_postprocessor import jobs_db, watcher, worker
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


def _reconcile_interval() -> float:
    """Periodic reconcile cadence in seconds (env MP_RECONCILE_INTERVAL, default 30)."""
    try:
        return float(os.environ.get("MP_RECONCILE_INTERVAL", "30"))
    except ValueError:
        return 30.0


def _periodic_reconcile_loop(download_dir: str, db_path: str, interval: float, stop_event):
    """Re-scan the library every `interval` seconds until `stop_event` is set (§10).

    This is the safety net for the watcher's min-age guard: freshly-written files
    that the real-time observer DEFERS (mtime younger than MIN_STABLE_AGE_SECONDS)
    are eventually enqueued here once they have settled. Without this loop a
    deferred file would never be processed. The wait-then-scan order means the
    startup backfill in main() owns the first pass.
    """
    while not stop_event.wait(interval):
        try:
            watcher.reconcile_scan(download_dir, db_path)
        except Exception as exc:  # noqa: BLE001 - a transient scan error must not kill the loop
            print(f"media_postprocessor: periodic reconcile error: {exc}", flush=True)


def main() -> None:
    cfg = Config.from_env(os.environ)

    # 1. Init DB + resume any job a crashed worker left 'running' (§5.3).
    jobs_db.init_db(cfg.db_path)
    jobs_db.requeue_running_on_startup(cfg.db_path)

    # 2. One-time startup backfill over the whole library (§10).
    watcher.reconcile_scan(cfg.download_dir, cfg.db_path)

    # Shared stop signal for the worker loop + the periodic reconcile thread.
    stop_event = threading.Event()

    # 3. Real-time filesystem watcher (watchdog observer, background).
    observer = watcher.start_watching(cfg.download_dir, cfg.db_path)

    # 4. Worker loop draining the queue in a background thread.
    worker_thread = threading.Thread(
        target=worker.run_forever,
        args=(cfg.db_path, cfg, stop_event),
        name="mp-worker",
        daemon=True,
    )
    worker_thread.start()

    # 5. Periodic reconcile safety net in a background thread (§10).
    interval = _reconcile_interval()
    reconcile_thread = threading.Thread(
        target=_periodic_reconcile_loop,
        args=(cfg.download_dir, cfg.db_path, interval, stop_event),
        name="mp-reconcile",
        daemon=True,
    )
    reconcile_thread.start()

    # 6. HTTP status server (foreground).
    server = build_server(cfg)

    # 7. Clean shutdown on SIGTERM/SIGINT: stop observer, signal worker +
    #    reconcile threads, shut the server down (which unblocks serve_forever).
    def _shutdown(_signum=None, _frame=None):
        stop_event.set()
        try:
            observer.stop()
        except Exception:  # noqa: BLE001 - best-effort teardown
            pass
        threading.Thread(target=server.shutdown, name="mp-server-shutdown", daemon=True).start()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    print(
        f"media_postprocessor listening on :{cfg.port} "
        f"(watch={cfg.download_dir} reconcile={interval}s)",
        flush=True,
    )
    try:
        server.serve_forever()
    finally:
        _shutdown()
        observer.join(timeout=5)
        worker_thread.join(timeout=5)
        reconcile_thread.join(timeout=5)
        server.server_close()


if __name__ == "__main__":
    main()
