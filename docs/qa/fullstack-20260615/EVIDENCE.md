# Full-stack media_postprocessor QA — REAL podman stack

**Revision:** 1
**Last modified:** 2026-06-15T22:30:00Z
**Run:** fullstack-20260615
**Runtime:** podman 5.8.2 (applehv VM), ffmpeg 7.1.4 in container, ffmpeg/ffprobe 8.x on host
**DOWNLOAD_DIR:** `/Volumes/T7/Downloads/Misc/MeTube` (PUID=501 PGID=20)

This run booted the real no-vpn stack, proved the dual-version pipeline
(webready h264+aac+faststart video AND mp3 audio) end-to-end on the RUNNING
deployed container, found + fixed a real integration bug (RED→GREEN), and
captured host ffprobe proof. No operator library files were modified.

## Per-step result

| Step | Result | Notes |
|---|---|---|
| 1. Boot stack | PASS | mpp image built, `media-postprocessor` Up, logs clean (`listening on :8089`). 4 project containers up. |
| 2. Proxy check | FIXED→PASS | `/api/postprocess/status` 404 → root cause: dashboard container (32h old) ran a stale image whose bundled nginx template predated the `/api/postprocess/` block. Rebuilt+recreated dashboard → `{"healthy":true,...}` HTTP 200. |
| 3. Deployed-container fixture test | PASS | Running container produced `webready-*.mp4` (h264+aac+faststart) and `*.mp3`, ffprobe-verified on HOST. Proven by BOTH the main mpp (watching real DOWNLOAD_DIR) and an isolated same-image container. |
| 4. Real download | PASS (+bug found) | `curl /api/add` of a public non-YouTube clip → metube downloaded `Big_Buck_Bunny_360_10s_1MB.mp4` (991KB on disk, status `finished`). mpp enqueued it but it FAILED — real bug (video-only source). |
| 5. Bug fix (TDD) | FIXED | RED test reproduced `has no aac audio stream` on a video-only source; fix makes aac validation conditional on source having audio; GREEN. Full suite 57 passed (was 56). |
| 6. Evidence | PASS | This dir. |
| 7. Cleanup | PASS | Test files + isolated containers removed; operator files untouched. |

## Bug fixed (real-stack, unit tests missed it)

**Symptom:** a real video-only download (no audio stream) was marked `failed`
with `webready output ... has no aac audio stream`.

**Root cause:** `transcoder._validate_webready()` unconditionally required an
aac stream. ffmpeg's `-map 0:a:0?` correctly produces a video-only mp4 for a
silent source, but the validator then rejected it. Video-only downloads
(silent clips, screen recordings, GIF-sourced video) are common.

**Fix:** `transcoder.py` — added `_source_has_audio()`; `transcode_video()`
passes `require_audio=source_has_audio` to `_validate_webready()`, which now
requires aac ONLY when the source had audio (a dropped track on an audio
source is still a real defect and still fails).

**Files modified (for the conductor to commit):**
- `media_postprocessor/transcoder.py`
- `media_postprocessor/tests/test_transcoder.py` (RED-first regression test
  `test_video_only_source_produces_valid_webready_no_audio`)

## Captured evidence (ffprobe on HOST)

### Main deployed container — webready video (sample fixture)
`webready-mpp_qa_video_20260615.mp4`:
```
codec_name=h264 (video) ; codec_name=aac (audio) ; duration=1.000000
faststart=True  moov@32 < mdat@1882
```
### Main deployed container — mp3 audio (sample fixture)
`mpp_qa_audio_20260615.mp3`:
```
codec_name=mp3 ; format_name=mp3 ; duration=1.021678
```
### Isolated same-image container — webready + mp3
See `ffprobe_webready_video.json`, `ffprobe_audio_mp3.json`
(h264+aac+faststart, mp3 — both produced in ~5s).

### Fix proof — real video-only download (the clip that FAILED pre-fix)
`webready-mpp_iso_videoonly_20260615.mp4` (produced by FIXED image):
```
codec_name=h264 (video) ; nb_streams=1 (no audio) ; duration=10.000000
faststart=True  moov@32 < mdat@4775
```
Full JSON: `ffprobe_videoonly_webready_AFTER_FIX.json`.
Pre-fix the same source produced job error `has no aac audio stream` (captured
in `proxy_jobs.json` job id 6 history before recreate).

### Runtime signature (fix deployed)
`podman exec media-postprocessor grep -c require_audio /app/media_postprocessor/transcoder.py` → 4
(the running main container carries the fix; proxy `{"healthy":true}` HTTP 200).

## Full suite (source changed)
`/tmp/mpp_venv/bin/python -m pytest media_postprocessor/tests/ -q` → **57 passed**.

## Notes / honesty
- `./status` script errors on `declare -A` (needs bash 4+; macOS default bash
  3.2). Pre-existing, unrelated to this task; not fixed here.
- The operator's real library file `Games/Starforged Legacy Review....webm`
  was being transcoded by the main worker during the run (single concurrency);
  it was NOT touched and the isolated-container approach avoided interfering.
- The two `failed` counts on the main mpp DB are the Big Buck Bunny clip under
  the OLD image (pre-fix). The fixed image is now deployed; the existing
  `failed` row is not auto-re-enqueued (idempotent on source_path) so it
  remains in the DB — the fix itself is proven on the same clip via the
  fixed-image isolated container above.
