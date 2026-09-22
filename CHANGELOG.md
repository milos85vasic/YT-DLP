# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [ytdlp-1.4.2] — 2026-09-22

### Fixed — full-cycle self-test script
- `scripts/lifecycle/verify-cycle.sh` had a broken debug trace line (an
  unterminated `'` right before a `>&2` redirect, so the redirect never
  fired and the quote instead swallowed the following lines into one
  garbled argument) plus two `RUNNING STAGE: ...` lines that printed
  `$stage_name` before it was assigned (always empty). Removed the dead
  debug instrumentation; the script's real improvements from this batch —
  sourcing `.env` for variable access, an `EXPECTED_SERVICES` systemd
  liveness check after Boot, captured stage output/exit-code with an
  optional per-stage validation command, and `AUTO_INSTALL=1` for
  non-interactive Install — are unaffected and now actually run cleanly.

### Fixed — unblocked authenticated `./download` CLI
- `yt-dlp/cookies/cookies.txt` (mounted into the `yt-dlp-cli` container per
  both `docker-compose.yml` and the `yt-dlp-cli*.service.template` units)
  was empty on this host, so the standalone `./download` CLI had no
  YouTube auth for age/region/login-gated content. Retrieved a working
  export from an existing deployment (`nezha`) and placed it at the
  correct mount path; this file is git-ignored by design and was not — and
  will never be — committed. `metube/config/cookies.txt` (MeTube's own,
  separately-managed cookie upload) was already present and populated on
  this host and was left untouched.

## [ytdlp-1.4.1] — 2026-09-22

### Fixed — systemd --user integration bugs found by live boot testing
- All ten `systemd-units/*.service.template` files had a `Restart=unless-stopped`
  value, which is a Docker Compose restart-policy string that systemd's
  `Restart=` directive does not recognize (systemd only accepts
  no/always/on-success/on-failure/on-abnormal/on-watchdog/on-abort) — systemd
  silently ignored it, so units never auto-restarted on crash. Changed to
  `Restart=on-failure` everywhere.
- `metube-direct.service.template` and `metube.service.template` inlined the
  `YTDL_OPTIONS` JSON value unquoted into `ExecStart=`; the JSON's User-Agent
  string contains spaces, which systemd's ExecStart word-splitting corrupted
  before it reached the container (runtime error: `Environment variable
  YTDL_OPTIONS is invalid`). Moved the JSON to a properly single-quoted
  `Environment=` line instead.
- `dashboard.service.template`, `landing-no-vpn.service.template`,
  `landing-vpn.service.template`, and `media-postprocessor.service.template`
  had a broken "build image if missing" `ExecStartPre` check that tested
  `podman images -q IMAGE`'s exit code (always 0) instead of its output, so
  the build step never ran and `podman run` tried (and failed) to pull
  `localhost/...` from a nonexistent registry. Fixed the test to check for
  empty output.
- `yt-dlp-cli.service.template` and `yt-dlp-cli-vpn.service.template` were
  missing `--entrypoint /bin/sh` on `podman run`, so the sleep-loop script was
  passed straight to the `yt-dlp` binary as CLI arguments (it tried to
  download `/bin/sh` as a URL) instead of being executed as a shell script.
  Added the entrypoint override to match the existing (correct)
  `docker-compose.yml` behavior.
- `scripts/setup/init` unconditionally ran `enforce_file_ownership
  "$SCRIPT_DIR/vpn-auth.txt"` against the wrong base directory
  (`scripts/setup/`, not the project root) and against a file that only
  exists when `USE_VPN=true`; under `set -e` this aborted every fresh,
  no-VPN `init` run. Same wrong-base-directory bug affected the five other
  `enforce_file_ownership` calls in the same block
  (`yt-dlp/{config,cookies,archive}`, `metube/config`,
  `yt-dlp/config/yt-dlp.conf`). Fixed to resolve the real project root, and
  made the `vpn-auth.txt` check conditional on the file actually existing.
- Same block also aborted once a service had actually run, because rootless
  Podman writes into `metube/config` (and the other paths above) as a
  user-namespace-remapped subuid (`>=100000`), which a plain host `chown`
  cannot touch (`EPERM`) — that is expected, not a failure, and was already
  handled this way for `DOWNLOAD_DIR` a few lines up but not for these other
  paths. Extended the same subuid-tolerant check to all of them.
- `scripts/lifecycle/enable-persistence.sh` under-reported its own result: it
  enabled any service found disabled but never re-counted it as enabled, so a
  clean first-run install always ended in "some services need attention"
  even after fixing everything. Also fixed a `systemctl --user is-enabled`
  usage that printed `disabled` twice (its real stdout plus a redundant
  `|| echo "disabled"` fallback firing on the command's expected non-zero
  exit for a disabled unit).

All of the above were found and fixed by actually tearing down the installed
systemd units and containers and running `./install` + `./boot` from scratch
— not just re-running against an already-working host.

### Added — root-level install/boot entrypoints, systemd --user as the mandatory path
- New **`./install`** — orchestrates environment setup, systemd --user unit
  install/enable, and reboot-persistence (loginctl linger) in one idempotent
  command.
- New **`./boot`** — starts every service via `systemctl --user` and verifies
  real HTTP reachability on both loopback (127.0.0.1) and the host's
  LAN-facing IPv4 address (not just systemd's reported service state),
  printing access URLs for both.
- `scripts/lifecycle/boot.sh` extended with LAN-IP detection and dual
  (loopback + LAN) HTTP health checks in systemd mode.
- New `Makefile` targets: `install`, `boot`, `boot-status`, `boot-stop`.

## [ytdlp-1.4.0] — 2026-06-15

### Added — Dual-version media pipeline (webready video + MP3)
- New **`media_postprocessor`** sidecar: every downloaded video gets a
  `webready-<base>.mp4` (H.264 High@4.1 / CRF18 / yuv420p / `+faststart`, AAC —
  stream-copied when already AAC) for guaranteed Android-TV playback; every
  audio gets a `<base>.mp3` (320 kbps). The original is kept untouched as the
  zero-loss master. On first start the service backfills (transcodes) the
  existing library, then watches for new downloads.
- SQLite-WAL job queue with crash-safe claim/resume, atomic `.partial`→rename
  output, ffprobe validation before completion, filesystem watcher + periodic
  reconcile (= one-time backfill), bounded-concurrency worker, and a
  `/api/postprocess/*` status API surfaced in the dashboard (Creating web video
  / Creating MP3 / Ready states).
- OpenAPI contract, Podman Dockerfile (system ffmpeg), compose service
  (`media-postprocessor:8089`, `oom_score_adj 1000`), nginx proxy.
- Coverage: 57 pytest (unit + integration + real-subprocess e2e + SIGKILL-resume
  chaos), anti-bluff Challenge `download_then_webready_challenge.sh`, HelixQA
  bank, docs_chain-wired feature Status ledger.

### Fixed — caught by real-stack validation (`docs/qa/fullstack-20260615/`)
- Watcher enqueued files still being written by yt-dlp (no min-age guard) →
  added `MIN_STABLE_AGE` mid-write protection (spec §10), RED-first.
- `webready` validation rejected video-only sources (no audio stream) → audio
  validation now conditional on the source actually having audio. Proven on a
  real download (Big Buck Bunny).

### Governance
- Constitution **§11.4.155** (project-name-prefixed recordings) authored;
  §11.4.153/154 applied; remote CI disabled (§11.4.75); 5 dependency submodules
  added (helixqa, containers, docs_chain, HelixAgent, Media).

## [ytdlp-1.3.0] — 2026-06-14

First tagged release under the §11.4.151 project-prefixed scheme, and the first
with published GitHub + GitLab releases. Spans 72 commits since `v1.2.0`.

### Governance / Constitution
- Inherit the **Helix Universal Constitution** as a pinned git submodule
  (`constitution/` @ `6445733e`); parent `CLAUDE.md` / `AGENTS.md` /
  `CONSTITUTION.md` now point at it (the universal constitution wins on conflict).
- **Constitution inheritance gate** (`tests/test-constitution-inheritance.sh`,
  7 invariants) with a **paired §1.1 mutation proof**
  (`tests/meta-test-constitution-inheritance.sh`), wired into `run-tests.sh`
  (`run_constitution_tests`) and `dev-check.sh` (Gate 5c). Hardened against
  silent-skip; `./init` self-heals submodules.
- `docs/SUBMODULES.md`, `docs/PENDING-FALSE-SUCCESS-FIXES.md`.

### Fixed — anti-bluff / false-success (CONST-034 / §7.1)
- `stop`: ran `compose down` with no `--profile` → stopped nothing yet claimed
  success; now passes all profiles, force-removes named services, and **verifies
  the end-state** (exit 1 if any survive).
- `start_no_vpn`: added a **readiness gate** — success is printed only after the
  services are actually running (`up -d || true` so the documented arm64
  `yt-dlp-cli` failure doesn't abort it).
- `status`: health now requires the expected **response body** per endpoint, not
  just HTTP 200 (an HTML-502-in-200 / curl-000 early-close no longer reads healthy).
- `init`: verifies the download dir is writable and `yt-dlp.conf` was written
  before claiming success.
- `update-images`: real per-image cache check instead of a blanket
  "may be using cached version"; honest reporting on arm64 (PoT image is amd64-only).
- `smoke-test.sh` Gate 6: `yt-dlp-cli` is a **documented arm64 failure** (PoT
  image has no arm64 build) — proven via manifest inspection, FAILs if that ever
  changes; strict on x86_64.

### UI / product
- Rebrand landing page to **Боба** with a Dracula-themed dashboard.
- Fix **502 Bad Gateway** on the dashboard API proxy; nginx cache-header fixes.
- Dashboard UX fixes; history-clear / queue-start use URLs (not IDs) for MeTube
  `/delete` and `/start`.

### Tests
- Comprehensive shell suite + browser-level E2E for history/queue ops.
- Anti-bluff hardening: body-content assertions, documented-failure helpers,
  artifact (on-disk) verification; per-test guards added across integration/scenario.

### Known platform notes
- The standalone `./download` CLI needs `yt-dlp-cli` (PoT image, **amd64-only**);
  on Apple Silicon use the web UI (MeTube's own engine is multi-arch). `status`
  needs bash 4+ (`declare -A`); macOS default bash 3.2 does not apply (Linux host).
- `start` (VPN profile) readiness gate and `download` artifact-rule fix are
  designed but pending verification (see `docs/PENDING-FALSE-SUCCESS-FIXES.md`).

[ytdlp-1.3.0]: https://github.com/milos85vasic/YT-DLP/releases/tag/ytdlp-1.3.0
