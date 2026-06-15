# `scripts/full_run_leave_up.sh`

**Last verified:** 2026-06-16

## Overview
One-shot operator helper that **rebuilds** the project's own container images
(`dashboard`, `media_postprocessor`) with `--no-cache`, **boots** the no-vpn
stack, **runs** the full test + challenge suite, writes a results summary, and
**leaves the stack running** for manual testing. Built for the request
"rebuild everything, boot everything, run all tests + challenges, leave it up."

## Prerequisites
- `podman` + `podman-compose` (auto-detected; falls back to `podman compose`).
- A valid `.env` (with `DOWNLOAD_DIR` pointing at an existing host directory).
- `ffmpeg`, `python3`, and the `/tmp/mpp_venv` pytest venv (auto-created if absent).
- Network access for vendor image pulls.

## Usage
```bash
# run detached (it is long — 30-60 min for the --no-cache rebuild + full suite):
nohup scripts/full_run_leave_up.sh >/dev/null 2>&1 &
```

## Outputs
- `docs/qa/full-run-<date>/RESULTS.md` — curated per-suite PASS/FAIL summary + the
  failed-test names + manual-test URLs.
- `docs/qa/full-run-<date>/runtests.log` — full `run-tests.sh` output (gitignored).
- `docs/qa/full-run-<date>/run.log` — full run log (gitignored).

## Side-effects (important)
- Rebuilds the `dashboard` + `media_postprocessor` images (`--no-cache`).
- Boots the no-vpn stack and **LEAVES IT RUNNING** (does not `./stop`).
- The `media_postprocessor` service **backfills (transcodes) the existing library**
  on first start — expect CPU/disk activity and `webready-*.mp4` / `*.mp3` files to
  appear alongside originals in `DOWNLOAD_DIR`.

## Internal behaviour
1. `--no-cache` rebuild of our images (avoids the "restart illusion": stale code in
   an old container being served).
2. Boot + `up -d --force-recreate dashboard media_postprocessor`.
3. **MeTube-readiness wait** — polls `:8088/history` and `:9090/api/history` until
   both serve valid JSON before running ANY test/challenge. This is the fix for the
   first run, where the suite ran before MeTube stabilized and reported false
   failures (contract showed 0/11 but was actually 18/0 once ready).
4. Runs `media_postprocessor` pytest, `run-tests.sh` (output **tee'd** so failure
   names are preserved), smoke, contract, then the challenge scripts.
5. Writes `RESULTS.md` with the manual-test URLs and leaves the stack up.

## Related scripts
- `scripts/smoke-test.sh`, `scripts/validate-contract.sh`, `tests/run-tests.sh`
- `challenges/scripts/download_then_webready_challenge.sh`
- `scripts/video_confirm.sh` (§11.4.153 feature video-confirmation via HelixAgent)
