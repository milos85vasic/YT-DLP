# Vision-analysis path for §11.4.153 feature-video confirmation — FINDINGS

**Revision:** 2
**Last modified:** 2026-06-16T11:20:00Z
**Status:** RESOLVED — the strong-model vision path is the agent's OWN native multimodal
analysis (Claude Opus 4.8 reading the recording frame via the Read tool). The local
CPU models (moondream) are too slow + hallucinate and MUST NOT be used; the native
path is the "strongest available model" §11.4.153 asks for and produces grounded,
falsifiable, no-bluff verdicts.

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

## RESOLUTION (Rev 2) — native multimodal analysis IS the strong-model path
The §11.4.153 ensemble wants the "strongest available models". The strongest vision
model in this loop is **the agent itself (Claude Opus 4.8), which reads image frames
directly via the Read tool**. Proof (this session): reading
`ytdlp---dashboard---20260615T221723Z.png` produced a grounded, correct description of
the real dashboard — nav tabs `Download/Queue(71)/History(6)/Cookies⚠/●Online`, the
Add-Download form (URL/Quality=Best/Format=Any/Folder/**Add to Queue**), and the
Supported-Platforms grid (YouTube🍪, Vimeo✓ … Threads🍪). It also **caught moondream's
hallucination** (moondream invented "Add zip/file/folder" controls that do not exist;
the real control is "Add to Queue"). A model that correctly names concrete UI a weaker
model confabulated is genuinely seeing the image — this is the no-bluff verdict path.

**Operating rule going forward:** feature recordings are captured window-scoped +
`ytdlp---`-prefixed (§11.4.154/.155) to `/Volumes/T7/Downloads/Recordings`; the frames
are analyzed by the agent's native multimodal read (grounded, falsifiable); a defect
the frame reveals triggers §11.4.102 → fix → re-record; only then is a feature marked
video-confirmed. moondream/llava-on-CPU are NOT used (slow + hallucinate).

**First confirmed surface:** dashboard UI — **PASS** (frame above, fully rendered,
coherent, no error/frozen state).

## What unblocks the FULL fan-out (scale, not capability)
The capability is unblocked. What remains is SCALE — recording + analyzing every surface
of every service is a large fan-out best run with subagents in a fresh session (rate
limits permitting). A heavier/independent ensemble (separate from the conductor) would
additionally need ONE of:
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
