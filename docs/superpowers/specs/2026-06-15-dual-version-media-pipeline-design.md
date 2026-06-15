# Dual-Version Media Pipeline — Design Specification

## §11.4.44 Revision header

- **Revision:** 1
- **Last modified:** 2026-06-15T15:39:54Z
- **Status:** draft-for-review

> This is a **DESIGN** specification, not an implementation. The decisions, ffmpeg
> recipes, schema, and reuse choices below are **locked** (evidence-cited) and must
> not be re-decided during implementation — implementers consume them verbatim.

---

## 1. Overview

The ytdlp stack is a Podman-orchestrated yt-dlp download system. Today, downloaded
media lands in `${DOWNLOAD_DIR}` (mounted `/downloads`) in whatever container/codec
the source provided. Playback on the operator's Android-TV target is therefore not
guaranteed, and audio is not normalised to a portable format.

This spec introduces a **dual-version media pipeline**: every download is preserved
as an untouched **zero-loss master**, and — alongside it — a **guaranteed-playable
derivative** is produced:

- Every downloaded **VIDEO** → `webready-<base>.mp4`, **always** transcoded to
  **H.264 + AAC** (operator choice for guaranteed Android-TV playback). The original
  file is kept untouched as the zero-loss master.
- Every downloaded **AUDIO** → `<base>.mp3` at **320 kbps CBR**. Original kept.

A new dedicated sidecar service, **`media_postprocessor`** (Python), owns this work.
It maintains a crash-safe **SQLite (WAL) jobs database**, **backfills** the existing
library, and **processes all new downloads** in real time.

### Existing services (docker-compose.yml) — context

| Service | Role |
|---|---|
| `metube` / `metube-direct` | Download queue/history API; downloads to `${DOWNLOAD_DIR}:/downloads` |
| `dashboard` | Angular 17 + nginx proxy on `:9090` |
| `landing` | Flask "Боба"; SQLite aborted-history ledger |
| `yt-dlp-cli` | Sleeping container for `./download` |
| `openvpn`, `watchtower` | Networking / image updates |
| **`media_postprocessor`** (NEW) | Dual-version derivation sidecar |

Host has **ffmpeg 8.1.1** and **podman**; **docker is absent** — all tooling and
compose usage must assume Podman.

---

## 2. Goals / Non-goals

### Goals

1. Guarantee Android-TV playback for every video via an always-present
   `webready-<base>.mp4` (H.264 + AAC, faststart).
2. Normalise every audio download to `<base>.mp3` @ 320 kbps CBR.
3. Preserve the original download untouched as the zero-loss master.
4. Backfill the existing library and process all new downloads automatically.
5. Be crash-safe: an interrupted transcode never leaves a half-written or invalid
   derivative; on restart the work resumes to a valid, complete output.
6. Surface status through the contract-first API, the dashboard UI, and a compact
   landing indicator.
7. Respect host-safety limits (§12.6 RAM ceiling, OOM-cascade lesson, CONST-033).

### Non-goals

- **Not** bit-exact "zero loss" inside the webready file. See §2.1 (honesty clause).
- **Not** a streaming/transcode-on-demand server. Derivation is batch/at-rest.
- **Not** a re-implementation of yt-dlp download logic; this consumes finished files.
- **Not** a host-power manager (no host power/sleep calls — CONST-033).
- **Not** per-feature video confirmation **now** — deferred until runnable
  (§11.4.153), honest SKIP until then.

### 2.1 Honesty clause — how "zero loss" is honored (§11.4.6)

"Zero loss" is honored by **keeping the ORIGINAL file untouched** as the master.
The `webready-<base>.mp4` is a **re-encode** (H.264 + AAC) and is therefore **NOT
bit-exact** to the source. We state this honestly: the webready file trades exactness
for guaranteed playability; the master is the lossless artifact. The one exception is
audio passthrough (see §4.1) where the source audio track is `-c:a copy` — lossless
for that track only.

---

## 3. Architecture

```
                       ${DOWNLOAD_DIR} (/downloads)   <- metube / metube-direct write here
                                  |
        +-------------------------+--------------------------+
        |                          (watch + reconcile)       |
        v                                                    |
  media_postprocessor (Python sidecar)                       |
   ├─ watcher (watchdog Observer / PollingObserver)          |
   ├─ reconcile full-scan (periodic) == one-time backfill ---+
   ├─ SQLite jobs DB (WAL, crash-safe)
   ├─ worker pool (bounded concurrency, default 1–2)
   │    └─ ffmpeg (native CLI, in-container)
   │         ├─ video  -> webready-<base>.mp4  (H.264+AAC, faststart)
   │         └─ audio  -> <base>.mp3           (320k CBR)
   ├─ ffprobe validation (before marking done)
   └─ REST API (contracts/media-postprocessor.openapi.yaml)
                                  ^
                                  |  /api/postprocess/* (nginx proxy)
                       dashboard (Angular 17 + nginx :9090)
                                  |
                       landing (Flask "Боба") compact indicator
```

### 3.1 Service boot

`media_postprocessor` is booted via **vasic-digital/containers** (Go
`BootManager.BootAll`, Podman auto-detect) per **§11.4.76**, with **health-gated
readiness** so dependents only see it once its DB is open and the HTTP health
endpoint is live.

### 3.2 Language choice

**Python** (recommended; see §13 Open items). Rationale: matches the `landing`
Flask service already in the stack, and the actual heavy lifting is CPU-bound work
inside ffmpeg — the controlling language is I/O/orchestration glue, so Python's
ecosystem (`watchdog`, `sqlite3`, an ASGI/WSGI server) is the lowest-friction fit.

---

## 4. Derivation rules (evidence-locked ffmpeg recipes)

These recipes are **locked from cited research**. Do not substitute codecs, presets,
or flags. `media_postprocessor` selects a recipe per file using ffprobe-derived
classification (informed by **vasic-digital/Media** for metadata/quality — see §6).

### 4.1 Video → `webready-<base>.mp4`

**Default (SDR, ≤1080p):**

```
ffmpeg -i in \
  -map 0:v:0 -map 0:a:0? \
  -c:v libx264 -preset slow -crf 18 -profile:v high -level:v 4.1 -pix_fmt yuv420p \
  -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  -fps_mode cfr \
  -c:a aac -b:a 192k -ac 2 \
  -movflags +faststart \
  out.mp4
```

**Audio track optimisation:** if source audio is already **AAC ≤ 2ch**, use
`-c:a copy` (lossless for that track) instead of re-encoding to AAC.

**Edge cases (detected via ffprobe, applied on top of the default):**

| Condition | Detection | Handling |
|---|---|---|
| HDR / 10-bit | `color_transfer = smpte2084` (PQ) or `arib-std-b67` (HLG) | **Tonemap to `yuv420p`** before encode |
| Variable frame rate (VFR) | frame-rate analysis | `-fps_mode cfr` (already in default) |
| Resolution > 4K | width/height probe | **Raise scale caps**; use `-level:v 5.2` |
| Image subtitles (PGS) | subtitle codec | **Burn** into video |
| Text subtitles | subtitle codec | `-c:s mov_text` |
| Multichannel / AC3 / DTS audio | channel/codec probe | **Downmix** `-ac 2` |

### 4.2 Audio → `<base>.mp3`

```
ffmpeg -i in -vn -map 0:a:0 -map_metadata 0 \
  -c:a libmp3lame -b:a 320k -id3v2_version 3 \
  out.mp3
```

**Cover art:** to keep embedded cover art, replace `-vn` with
`-map 0:v -c:v copy -disposition:v attached_pic`.

---

## 5. State & resume (SQLite jobs DB, crash-safe)

### 5.1 PRAGMAs

```
PRAGMA journal_mode = WAL;
PRAGMA synchronous  = NORMAL;
PRAGMA busy_timeout = 5000;
```

### 5.2 Schema

```sql
CREATE TABLE jobs (
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
CREATE INDEX idx_jobs_status ON jobs(status);
```

`source_path` is **UNIQUE** → idempotency: the same file never enqueues twice.

### 5.3 State machine

```
queued ──► running ──► done
                  ├──► failed   (re-queues until attempts == max)
                  └──► canceled
```

- `failed` re-queues to a bounded **max attempts**, then stays `failed` with `error`.
- **On restart (crash recovery):**
  ```sql
  UPDATE jobs SET status='queued' WHERE status='running';
  ```
  Any job that was mid-flight when the process died is re-queued.

### 5.4 Atomic, idempotent output

1. ffmpeg writes to `<final>.partial` **in the same directory** as the final output.
2. On ffmpeg **exit 0 only**, `os.replace(tmp, final)` (POSIX rename atomicity).
3. **Never cross-filesystem** — the temp file lives in the destination directory so
   the rename is atomic (cross-FS rename is a copy and is not atomic).

### 5.5 Anti-bluff validation (never "the job said done")

Before a job is marked `done`, **ffprobe-validate the output**:

- Codec assertion — video: **H.264 + AAC**; audio: valid **mp3**.
- **Non-zero frames / duration**.
- Video webready additionally asserts **`+faststart`** (moov atom before mdat).

Only on a passing probe is `status` set to `done`. A produced-but-invalid output is
treated as a failure and re-queued (or surfaced as `failed`).

---

## 6. Reuse (§11.4.74 — evidence-locked)

| Need | Reuse decision | Notes |
|---|---|---|
| Transcode engine | **Native ffmpeg CLI in-container** | `vasic-digital/ffmpeg-kit` is a **mobile app-embedding toolkit → NO-MATCH** for server use |
| Service boot | **vasic-digital/containers** (Go `BootManager.BootAll`, Podman auto-detect) | Per §11.4.76; health-gated readiness |
| Metadata / quality classification | **vasic-digital/Media** (Go) | Informs encode decisions; **not** a transcoder |
| Feature-video analysis | **HelixDevelopment/HelixAgent** REST `:7061` `POST /v1/ensemble/completions` | §11.4.153; **read `docs/api/API_REFERENCE.md` (multimodal schema) before wiring frames** |
| Test banks | **HelixDevelopment/helixqa** YAML banks (`helixqa run` / `autonomous`) | Per §11.4.27 |
| Docs/features status | **vasic-digital/docs_chain** `.docs_chain/contexts/*.yaml` (`sync` / `verify`) | Per §11.4.106; **caveat:** §11.4.106 prefers by-reference — **consume the CLI by reference** |

---

## 7. API (contract-first)

### 7.1 Contract

New OpenAPI contract: **`contracts/media-postprocessor.openapi.yaml`**, validated via
the existing **`scripts/validate-contract.sh`** pattern. Contract is authored and
validated **before** implementation.

Endpoints (shape — finalised in the contract):

- `GET  /api/postprocess/jobs` — list jobs with status/derived state.
- `GET  /api/postprocess/jobs/{id}` — single job detail.
- `POST /api/postprocess/jobs/{id}/retry` — re-queue a `failed`/`canceled` job.
- `GET  /api/postprocess/health` — readiness/liveness (used by health gate, §3.1).
- (Optional) `GET /api/postprocess/summary` — counts for the landing indicator.

### 7.2 nginx proxy

Add an `/api/postprocess/*` location to
**`dashboard/nginx.conf.template`** using the **existing
resolver + `set $var` + `rewrite` + `proxy_pass`** pattern, targeting
`media_postprocessor:<port>`. Match the established style verbatim (do not introduce
a new proxy idiom).

---

## 8. UI/UX

### 8.1 Dashboard (Angular 17)

- Extend `DownloadInfo.status` in **`metube.service.ts`** with the new states —
  **no `any`** (strict typing required).
- **`queue.component.ts`** `STATE_META` (already has `postprocessing`) gains:
  - `deriving_webready`
  - `deriving_mp3`
  - `webready_ready`
- Add corresponding **CSS** for the new states.
- Maintain the **four-state render** discipline: **loading / error / empty /
  content**.
- Add a **Retry** action wired to `POST /api/postprocess/jobs/{id}/retry`.

### 8.2 Landing (Flask "Боба")

- Add a **compact summary indicator** (e.g. queued / deriving / ready counts),
  sourced from the summary endpoint (§7.1).

---

## 9. Host safety

`media_postprocessor` is constrained at the compose level and at runtime:

- Explicit **`mem_limit`**, **`memswap_limit`**, **`pids_limit`**, **`oom_score_adj`**
  (OOM-cascade lesson — the postprocessor must be the first sacrificed, never the
  download/queue services).
- **Bounded transcode concurrency** (default **1–2**).
- **`nice` / `ionice`** the ffmpeg workers to yield CPU/IO to interactive services.
- Stay within the **§12.6 60% RAM ceiling**.
- **No host-power calls** (**CONST-033**).

---

## 10. Watcher + backfill

- **Real-time:** Python **`watchdog` Observer**, using **`PollingObserver` for
  network mounts** (inotify is unreliable on network filesystems).
- **Periodic reconcile full-scan:** because inotify drops events and events are
  missed while the service is down, a periodic full scan **diffs the library against
  the jobs table** and enqueues anything missing. **This same scan is the one-time
  backfill.**
- **Skip rules:** ignore files starting with **`webready-`** and the **generated
  `.mp3`** outputs (never derive from a derivative).
- **Mid-write protection:** a **min-age / stable-size filter** ensures files still
  being written by metube are not picked up before they finish.

---

## 11. Testing & anti-bluff (§11.4.27 — mocks only in unit)

| Layer | What it proves |
|---|---|
| **unit** | State machine, naming (`webready-<base>.mp4`, `<base>.mp3`), codec-decision logic. Mocks allowed **only here**. |
| **integration** | **Real ffmpeg** on a tiny sample + **real SQLite** → ffprobe asserts **H.264 + AAC + faststart** for video / **valid mp3** for audio. |
| **e2e (Playwright)** | Real download → status transitions → files on disk + UI reflects state. |
| **resume / chaos (§11.4.85)** | **SIGKILL mid-transcode → restart → resumes to a valid complete output; zero half-files.** |
| **stress** | N concurrent jobs — no deadlock, no leak. |
| **security** | **Path-traversal** and **ffmpeg-arg-injection** on filenames (malicious `<base>` names). |
| **performance / benchmark** | Throughput / resource envelope. |

### 11.1 Challenge (ARTIFACT rule)

`challenges/scripts/download_then_webready_challenge.sh` **extends**
`challenges/scripts/download_completes_challenge.sh`:

1. **Submit** a download → **wait** until finished.
2. Assert the **original > 1KB**.
3. Assert **`webready-*.mp4` exists** AND is **ffprobe-valid** AND **faststart**.
4. For audio downloads, assert the **`.mp3`** exists and is valid.

**ARTIFACT rule:** the challenge **ffprobes the actual artifact** — it never trusts a
status string.

### 11.2 helixqa

Add a **helixqa bank entry** mirroring the challenge assertions.

### 11.3 Per-feature video confirmation

**Deferred until runnable** — honest **SKIP** per **§11.4.153** until the
HelixAgent-based harness (§12) is wired.

---

## 12. Recording / video-confirmation (§11.4.153–155)

- Recordings for §11.4.153 video confirmation are prefixed
  **`ytdlp---<feature>---<run-id>.mp4`** (**§11.4.155**).
- Stored at **`/Volumes/T7/Downloads/Recordings`**.
- **Window-scoped** capture with **fresh-corpus rotation** (**§11.4.154**).
- Analysis via **HelixDevelopment/HelixAgent** `:7061`
  `POST /v1/ensemble/completions` — **read its `docs/api/API_REFERENCE.md`
  multimodal schema before wiring frames**.
- Until this harness is runnable, per-feature video confirmation is an **honest
  SKIP** (§11.4.153).

---

## 13. Phases (PWU, subagent-driven §11.4.70)

| # | Phase |
|---|---|
| **1** | Contract + `media_postprocessor` skeleton + SQLite state + host-safety limits + compose service. |
| **2** | ffmpeg derivation (video + audio) + atomic/idempotent outputs + ffprobe validation. |
| **3** | Watcher + reconcile + one-time backfill. |
| **4** | Resume / crash-safety + chaos tests. |
| **5** | API + dashboard UI states + landing indicator. |
| **6** | Full test matrix + Challenge + helixqa bank. |
| **7** | docs/features wiring (docs_chain) + video-confirmation harness (HelixAgent) + docs/exports + prefixed release tag (§11.4.151) + multi-upstream push. |

---

## 14. Open items (noted, not blocking)

- **Python vs Go** for the service — **recommend Python** (matches `landing`; ffmpeg
  does the CPU work, the controller is glue).
- **x264 CRF exact value** — **18** chosen as default.
- **MP3 320 CBR vs V0** — **320 CBR** chosen.

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| Transcode CPU/RAM starves interactive services | Host-safety limits §9; bounded concurrency; nice/ionice; §12.6 ceiling. |
| OOM cascade kills download/queue services | Explicit `oom_score_adj` makes postprocessor the first sacrifice (§9). |
| inotify drops events / events missed while down | Periodic reconcile full-scan + PollingObserver on network mounts (§10). |
| Crash mid-transcode leaves half-files | `.partial` in dest dir + `os.replace` on exit 0 + restart re-queue (§5). |
| "Done" job actually invalid | Mandatory ffprobe validation before `done` (§5.5). |
| Re-deriving derivatives (infinite loop) | Skip `webready-`/`.mp3`; `source_path` UNIQUE (§5.2, §10). |
| Malicious filenames (path traversal / arg injection) | Security tests §11; never pass untrusted `<base>` into shell unsanitised. |
| Mistaking webready for lossless | Honesty clause §2.1 — master is the lossless artifact, stated explicitly. |
| HDR/10-bit washed out without tonemap | ffprobe color_transfer detection → tonemap to yuv420p (§4.1). |
| Cross-filesystem rename non-atomic | Temp file mandated in destination dir (§5.4). |

---

*End of design specification (draft-for-review).*
