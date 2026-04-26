# AGENTS.md — Landing Page Subdirectory

> **Authority chain:** `Constitution.md` > `CLAUDE.md` > `AGENTS.md` (this file)

## Scope

This directory contains the Python/Flask landing page proxy. All rules here apply to `landing/` and its subdirectories.

## Additional Constraints (Beyond Constitution + CLAUDE.md)

### Python Rules
- Use type hints for all function signatures.
- All proxy endpoints must preserve the exact request/response shape of the upstream MeTube API.
- Validate uploaded files before forwarding.
- Return JSON with `"status": "ok"` or `"status": "error"` consistently.

### Flask Endpoint Requirements
Every new endpoint MUST:
1. Have a docstring explaining its purpose
2. Handle exceptions and return structured JSON errors
3. Log errors with `log.error()`
4. Be added to `scripts/smoke-test.sh` if it's user-facing

### Proxy Rules
- The landing page proxies to `METUBE_URL` (default: `http://metube-direct:8081`).
- NEVER modify request/response bodies when proxying — pass through exactly.
- The only exception is `/api/delete-download` which adds file deletion logic.

### Testing
- Run `python3 -m py_compile app.py` before committing.
- Test proxy endpoints with curl against running containers.
- Landing page tests are in `../tests/test-dashboard.sh` and `../scripts/smoke-test.sh`.
