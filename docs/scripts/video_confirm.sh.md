# `scripts/video_confirm.sh`

**Last verified:** 2026-06-16

## Overview
§11.4.153 feature visual-confirmation helper. Captures a **window-scoped** frame
(§11.4.154) of a running feature surface (default: the dashboard at
`http://localhost:9090`), names it with the project prefix `ytdlp---<scope>---<ts>.png`
(§11.4.155), sends it to a **vision-capable LLM ensemble** for a PASS/FAIL verdict,
and records the **real** model response (no bluff) under `docs/qa/`.

## Prerequisites
- A running feature surface (default dashboard `:9090`).
- Node/`npx` + Playwright (the repo ships `tests/e2e/`); chromium is auto-installed
  on first run.
- `curl`, `python3`, `base64`, `ffmpeg`.
- **A vision-capable model** reachable for the analysis step. Set `HELIXAGENT_URL`
  (default `http://localhost:7061`) and optionally `HELIXAGENT_API_KEY`.

## ⚠️ Known prerequisite gap (verified 2026-06-16)
The analysis step needs a model that accepts **image input**. As verified on this
host **neither available model can**:
- The running **HelixAgent** build is **text-only** — its `/v1/chat/completions`
  rejects the OpenAI multimodal `content` array (`400: cannot unmarshal array into
  ... content of type string`) and its `/v1/vision/*` endpoints are stubbed.
- The local **`helix_ollama_video`** Ollama has only `qwen2.5:3b` (text, no vision).

So the **capture** half works end-to-end, but the **ensemble-analysis** half is
**operator-blocked (§11.4.21)** until a vision model is deployed — e.g.
`podman exec helix_ollama_video ollama pull llava` (then point the harness at the
Ollama vision endpoint), or configure a vision provider in HelixAgent. The harness
does **not** deploy a model itself (that would modify operator infrastructure
unprompted, §11.4.122) and does **not** fake a verdict when analysis is unavailable.

## Usage
```bash
scripts/video_confirm.sh [scope] [url]
# default: scripts/video_confirm.sh dashboard http://localhost:9090
```

## Outputs
- Recording: `/Volumes/T7/Downloads/Recordings/ytdlp---<scope>---<ts>.png`.
- `docs/qa/video-confirm-<date>/VERDICT.md` — capture result, HelixAgent health, the
  raw model response, and the parsed verdict (or the honest blocker).

## Side-effects
- Writes one `ytdlp---<scope>---*.png` to the recordings path; **fresh-corpus
  rotation** (§11.4.154) deletes ONLY this project's own prior `ytdlp---<scope>---*`
  files — never foreign (`helixcode-*`/`helixtranslate-*`) or operator files (§11.4.122).

## Related scripts
- `scripts/full_run_leave_up.sh`, `challenges/scripts/download_then_webready_challenge.sh`
- Research: `docs/research/helixagent-video-analysis/RECIPE.md`,
  `docs/research/recording-mechanism/MECHANISM.md`
