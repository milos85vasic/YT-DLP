# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
