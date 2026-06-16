# Vision-analysis path for §11.4.153 feature-video confirmation — FINDINGS

**Revision:** 1
**Last modified:** 2026-06-16T11:00:00Z
**Status:** OPERATOR-BLOCKED (§11.4.21) — no reliable/strong vision model available in this environment

## Goal
§11.4.153 requires every feature's real-use recording to be machine-analyzed by an
ensemble; a defect found must be fixed/retested. Operator demands the "strongest
models" and **no faulty/bluff LLM responses**. This documents what vision capability
is actually available here.

## What was tried (real evidence)
1. **HelixAgent ensemble (`:7061`)** — its `/v1/models` exposes only text aliases
   (`helixagent-llm/debate/ensemble`); **no vision-capable provider** (no gpt-4o /
   claude / gemini / llava). `/v1/chat/completions` rejects the OpenAI multimodal
   content-array (`content` must be a string) and `/v1/vision/*` are stubbed. → no
   working vision path without configuring a vision provider (needs API keys).
2. **Local Ollama (`helix_ollama_video :11434`)** — had only `qwen2.5:3b` (text).
   Pulled **`moondream`** (vision, ~1.7 GB) into it. Tested on the real recording
   `/Volumes/T7/Downloads/Recordings/ytdlp---dashboard---20260615T221723Z.png`:
   - 1366×900 image: first call **empty after 71 s**, second call **timed out (180 s)**.
   - Downscaled to 672px: succeeded but took **298 s (~5 min)**, and the response was
     **partially correct + partially hallucinated**:
     > "...a web browser window... a webpage that has a 'Add download' button located
     > in the upper right corner. Below the button... 'Add file', 'Add folder',
     > 'Add zip', 'Add zip archive', 'Add zip file'."
   - The "Add download" button is REAL (the dashboard has it) — so it genuinely sees
     the image — but the "Add zip/file/folder" options **do not exist** in the ytdlp
     dashboard. The model confabulates.

## Honest assessment (anti-bluff)
- A vision path is mechanically reachable (Ollama + a vision model), but the only
  model available on this **CPU-only** host (moondream) is **(a) impractically slow
  — ~5 min per frame**, making "analyze every feature's recording" infeasible, and
  **(b) unreliable — it hallucinates UI elements.**
- Marking features "video-confirmed" on such output would be a **§11.4 PASS-bluff**
  (a hallucinating model's "PASS" is not a confirmation). This is exactly the
  "faulty/bluff LLM responses" the operator forbids — so it MUST NOT be used.

## What unblocks it (operator action)
A genuine, strong, reliable ensemble analysis needs ONE of:
1. **Cloud vision API key(s)** (GPT-4o / Claude 3.x/4 / Gemini) configured as a
   provider in **HelixAgent** (the intended ensemble) — then `/v1/.../completions`
   multimodal works and the §11.4.153 loop runs at quality + speed.
2. **GPU acceleration** for the local Ollama so a strong open vision model
   (llava:13b / qwen2-vl / pixtral) runs fast + accurately.

Until then the §11.4.153 video-analysis is honestly **OPERATOR-BLOCKED**; the
**capture** half (window-scoped recording, `ytdlp---` prefix, rotation) works and is
ready (`scripts/video_confirm.sh`). The `docs/features/Status.md` video-confirmation
cells stay **PENDING** (truthful) rather than faked.

## Sources / artifacts
- Real moondream output captured this session (above).
- Capture harness: `scripts/video_confirm.sh` (+ `docs/scripts/video_confirm.sh.md`).
- Recipe: `docs/research/helixagent-video-analysis/RECIPE.md`.
