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
