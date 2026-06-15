# §11.4.44 — HelixAgent Video-Analysis Recipe (for Constitution §11.4.153)

**Purpose:** machine-analyze recorded feature/QA videos with
HelixDevelopment/HelixAgent so each feature's real-use recording is checked; if a
problem is detected → fix/retest. This is the §11.4.153 mandatory video-recording
confirmation step.

> Evidence basis: every claim below is sourced from the **remote** GitHub repo
> `HelixDevelopment/HelixAgent` (read via `gh api` on 2026-06-15). Items the docs
> do **not** confirm are flagged **UNCONFIRMED / HONEST GAP** and a fallback is
> proposed instead of inventing a schema.

---

## 0. TL;DR

HelixAgent does **not** ingest video. There is **no** `/v1/.../video` endpoint and
no ffmpeg/frame-extraction step inside the service. The QA API only treats video
as *evidence output* (`evidence_paths`), never as analysis input.

Therefore the recipe is: **extract frames with ffmpeg locally → send frames to a
multimodal endpoint → parse a PASS/FAIL verdict.** Two endpoints can receive
frames; pick per the table:

| Endpoint | Multimodal? | Production-ready? | Use it when |
|----------|-------------|-------------------|-------------|
| `POST /v1/chat/completions` (OpenAI-style `image_url` content parts) | **Yes (documented + challenge-tested)** | Yes, *if* a vision-capable provider key is configured (`ANTHROPIC_API_KEY`/`OPENAI_API_KEY`/`GEMINI_API_KEY`) | **Primary path.** Frame + analysis prompt → free-text verdict. |
| `POST /v1/vision/analyze` (`image` / `image_url` + `prompt`) | Yes *by contract* | **NO — stubbed.** Returns `verified:false`, `status:"stub_only"` until a real provider is wired in (see §2.2) | Only after confirming `/v1/vision/health` reports a real provider, not a stub. |

---

## 1. Base URL / Port + Auth

- **Auth:** Bearer token on every call: `Authorization: Bearer $HELIXAGENT_API_KEY`.
  (`docs/api/API_REFERENCE.md`: "Most endpoints require authentication via Bearer
  token". Env var to set the server's key: `HELIXAGENT_API_KEY` / `HELIX_LLM_API_KEY`.)
- **Port — CONFIRMED but INCONSISTENT in the repo (HONEST GAP):**
  - All README/API-reference curl examples use **`http://localhost:7061`**.
  - `.env.example` sets `HELIX_LLM_PORT=8443`.
  - `docs/development/port-registry.md` note: "HelixAgent ports live in the **81xx**
    band by default… switch to 91xx with `HELIXAGENT_PORT_PREFIX=9`." The vision
    challenge script defaults to `HELIXAGENT_PORT=8100`.
  - **Action:** treat `7061` as the documented default but **verify your running
    instance's port** (`curl $BASE/v1/health` or check `docker compose ps`) before
    automating. Recipe uses `$HELIXAGENT_URL` so it is portable.

```bash
export HELIXAGENT_URL="http://localhost:7061"   # verify against your instance
export HELIXAGENT_API_KEY="sk-...your-key..."
```

---

## 2. Multimodal / frame-input endpoints

### 2.1 Primary: `POST /v1/chat/completions` (OpenAI-compatible, multimodal)

`GET /v1/models` advertises `"capabilities": {"vision": true, ...}` for
`helixagent-debate`. The vision challenge
(`challenges/scripts/protocol_vision_api_challenge.sh`) exercises multimodal
`content` arrays with both a remote URL and a base64 **data URI**:

Exact request JSON shape (frames + analysis prompt):

```json
{
  "model": "helixagent-debate",
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "<analysis prompt — see §4>" },
        { "type": "image_url",
          "image_url": { "url": "data:image/png;base64,<BASE64_FRAME_1>" } },
        { "type": "image_url",
          "image_url": { "url": "data:image/png;base64,<BASE64_FRAME_2>" } }
      ]
    }
  ],
  "max_tokens": 1024,
  "stream": false
}
```

- `image_url.url` accepts both `https://…` URLs and `data:image/png;base64,…` URIs
  (both are tested in the challenge). For local `.mp4` frames use the data URI form.
- The model used for the actual vision call depends on configured providers; vision
  works only if a vision-capable provider key is set (Claude/Gemini/GPT-4o). With no
  key the challenge tolerates `404`/`501`/`503` — i.e. **multimodal is opportunistic,
  not guaranteed** unless you provision a vision provider. (HONEST GAP: the docs do
  not guarantee a specific default vision model; they delegate to provider config.)

### 2.2 `POST /v1/vision/analyze` — exists but is a STUB (do not rely on it yet)

Documented contract (`docs/api/API_REFERENCE.md` → Vision API):

```json
// POST /v1/vision/analyze
{ "image": "data:image/png;base64,...", "prompt": "Describe what you see" }
// documented response:
{ "analysis": "…", "confidence": 0.95, "provider": "claude" }
```

**HONEST GAP / anti-bluff:** `challenges/scripts/vision_stub_honesty_challenge.sh`
("CONST-035 anti-bluff regression guard") proves all six `/v1/vision/*` endpoints
(`analyze, ocr, detect, caption, describe, classify`) currently:
- return **HTTP 400** on empty body, and
- return **`verified:false` AND `status:"stub_only"`** for valid input,
until a real vision provider is wired in. They must **not** fabricate
colors/captions/labels. So `/v1/vision/analyze` is an honest stub — **gate on it**:

```bash
curl -s "$HELIXAGENT_URL/v1/vision/health" -H "Authorization: Bearer $HELIXAGENT_API_KEY" | jq .
# Only use /v1/vision/* if responses show verified:true and status != "stub_only".
```

### 2.3 The real vision engine lives in a separate subsystem (VisionEngine)

`Website/user-manuals/41-visionengine-guide.md`: the production vision capability is
the **VisionEngine** Go library (`pkg/llmvision`) with real OpenAI/Anthropic/Gemini/
Qwen adapters and a remote **VisionPool** (Ollama `llava`/`moondream` or llama.cpp
backends). It is consumed by HelixQA, not exposed as a public REST frame-analysis
endpoint. **For an over-HTTP frame check, §2.1 (`/v1/chat/completions`) is the path.**

---

## 3. Response schema (verdict + analysis text)

`/v1/chat/completions` (non-streaming) returns standard OpenAI shape — the verdict
text is in `choices[0].message.content`:

```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "model": "helixagent-debate",
  "choices": [
    { "index": 0,
      "message": { "role": "assistant", "content": "{\"verdict\":\"FAIL\",\"reasons\":[...]}" },
      "finish_reason": "stop" }
  ],
  "usage": { "prompt_tokens": 25, "completion_tokens": 150, "total_tokens": 175 }
}
```

Because `helixagent-debate` is an **ensemble**, the `content` is the ensemble's
synthesized answer. To make it machine-parseable, force JSON in the prompt (§4) and
read `choices[0].message.content`. (Errors come back as
`{"error":{"code":"...","message":"..."}}`; `401`=bad key, `429`=rate-limited —
`/v1/chat/completions` is rate-limited to 60/min.)

---

## 4. End-to-end recipe for `ytdlp---<feature>---<run-id>.mp4`

### (a) Extract sample frames with ffmpeg

```bash
IN="ytdlp---download-playlist---run-0042.mp4"
WORK="/tmp/helix-frames/${IN%.mp4}"
mkdir -p "$WORK"

# Option A: 1 frame/sec (simple, deterministic)
ffmpeg -i "$IN" -vf fps=1 "$WORK/frame_%03d.png"

# Option B: scene-change keyframes (fewer, more informative frames)
ffmpeg -i "$IN" -vf "select='gt(scene,0.3)',showinfo" -vsync vfr "$WORK/scene_%03d.png"
```

Keep the frame count modest (e.g. 4–8 representative frames) to stay within the
prompt/token budget and the 60/min rate limit.

### (b) POST frames + prompt to HelixAgent

```bash
#!/usr/bin/env bash
set -euo pipefail
: "${HELIXAGENT_URL:=http://localhost:7061}"
: "${HELIXAGENT_API_KEY:?set HELIXAGENT_API_KEY}"
WORK="$1"; FEATURE="$2"   # e.g. /tmp/helix-frames/...  "download-playlist"

# Build image_url content parts from frames (data URIs)
PARTS=$(for f in "$WORK"/*.png; do
  b64=$(base64 < "$f" | tr -d '\n')
  printf '{"type":"image_url","image_url":{"url":"data:image/png;base64,%s"}}\n' "$b64"
done | paste -sd, -)

PROMPT="You are a QA video-frame auditor verifying constitution clause 11.4.153. \
These are sequential frames from a real-use recording of the feature \"$FEATURE\" \
of the ytdlp tool. Confirm the feature actually works on screen: the expected UI/CLI \
state appears, the action completes, and NO error, crash, stack trace, empty result, \
or broken state is visible. Respond ONLY with minified JSON: \
{\"verdict\":\"PASS\"|\"FAIL\",\"confidence\":0.0-1.0,\"reasons\":[\"...\"],\"evidence_frames\":[1,2]}. \
verdict FAIL if any frame shows a problem."

BODY=$(cat <<JSON
{"model":"helixagent-debate","stream":false,"max_tokens":1024,
 "messages":[{"role":"user","content":[{"type":"text","text":$(jq -Rn --arg p "$PROMPT" '$p')},$PARTS]}]}
JSON
)

curl -sS -X POST "$HELIXAGENT_URL/v1/chat/completions" \
  -H "Authorization: Bearer $HELIXAGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY"
```

### (c) Parse a PASS/FAIL-with-reasons verdict and act

```bash
RESP=$(... the curl above ...)
VERDICT_JSON=$(echo "$RESP" | jq -r '.choices[0].message.content')
VERDICT=$(echo "$VERDICT_JSON" | jq -r '.verdict')
echo "$VERDICT_JSON" | jq .

if [ "$VERDICT" = "PASS" ]; then
  echo "§11.4.153 OK for $FEATURE"
else
  echo "§11.4.153 VIOLATION — fix and retest:"
  echo "$VERDICT_JSON" | jq -r '.reasons[]'
  exit 1   # gate CI: feature must be fixed and the recording re-analyzed
fi
```

The non-zero exit enforces the "if a problem is detected → fix/retest" rule: the
pipeline fails, the feature is fixed, a new recording is made, and this analysis
re-runs until `verdict == PASS`.

### (Optional) Drive a full autonomous QA session instead of single frames

If you have the running app (not just a recording), `POST /v1/qa/sessions`
(`platforms: ["cli"|"web"|...]`, `project_root`, `output_dir`) runs the
Learn→Plan→Execute→**Analyze** pipeline (LLM-vision driven) and itself produces
`evidence_paths` containing screenshots and `.mp4` videos, plus findings via
`GET /v1/qa/findings?status=open`. This complements §11.4.153 but does **not**
replace analyzing a pre-existing recording — for that, use §4(a–c).

---

## 5. Run HelixAgent locally (so the analysis step is reachable)

From the README (Docker is the recommended path; requires Docker & Docker Compose):

```bash
git clone <HelixAgent repo>        # README shows dev.helix.agent remote
cd helixagent
cp .env.example .env               # then edit (see below)

make docker-full                   # docker compose --profile full up -d
# or lighter:
make docker-ai                     # docker compose --profile ai up -d  (AI services only)
```

Other Make targets (from `Makefile`):
- `make docker-build` → `docker build -t helixagent:latest .`
- `make run-dev` → `GIN_MODE=debug go run ./cmd/helixagent/main.go` (local, no Docker; needs Go 1.24+)
- `make docker-monitoring` → Prometheus/Grafana stack.

**Minimum `.env` for working video analysis** — set the server key and **at least one
vision-capable provider**, otherwise `/v1/chat/completions` multimodal returns
`404/501/503` and `/v1/vision/*` stays `stub_only`:

```bash
HELIX_LLM_API_KEY=sk-...            # = the Bearer token clients must send
ANTHROPIC_API_KEY=sk-ant-...        # vision-capable (Claude); OR
GEMINI_API_KEY=...                  # OR
OPENAI_API_KEY=sk-...               # GPT-4o
# Optional remote vision pool (VisionEngine):
# VISION_PROVIDERS=anthropic,gemini,openai,qwen
```

> Podman: the README documents Docker/Compose only — Podman is **UNCONFIRMED** in the
> repo. `podman compose --profile full up -d` is plausible (the compose file is
> Podman-compatible) but untested per the docs.

Verify reachability before analyzing:
```bash
curl -s "$HELIXAGENT_URL/v1/health" && \
curl -s "$HELIXAGENT_URL/v1/models" -H "Authorization: Bearer $HELIXAGENT_API_KEY" | jq '.data[0].capabilities'
```

---

## Confirmed facts vs. honest gaps

**CONFIRMED**
- Auth = `Authorization: Bearer <key>` on all endpoints; server key env = `HELIXAGENT_API_KEY`/`HELIX_LLM_API_KEY`.
- `/v1/chat/completions` is OpenAI-multimodal: `content` array with `image_url`
  (URL or `data:image/png;base64,…`) is documented and challenge-tested. Verdict in
  `choices[0].message.content`.
- `/v1/vision/*` endpoints exist with documented schemas but are **honestly stubbed**
  (`verified:false`, `status:"stub_only"`) until a real vision provider is wired in.
- No video-ingestion endpoint anywhere; QA API uses video only as evidence output.
- Local run = `make docker-full` / `docker compose --profile full up -d`; needs a
  vision-capable provider key for real analysis.

**UNCONFIRMED / HONEST GAP**
- Port is inconsistent across the repo (`7061` in docs vs `8443`/`81xx`/`8100`
  elsewhere) — verify your instance's actual port.
- No guaranteed default vision model; multimodal success depends on provider config
  (calls may return `404/501/503` if none is set).
- Podman is not documented (Docker only).
- `/v1/vision/analyze` should not be used for §11.4.153 until its health check shows
  a non-stub provider.
