# Feature Status Summary

**Revision:** 1
**Last modified:** 2026-06-15T15:27:34Z
**Authority:** constitution §11.4.56 (Status_Summary two-audience companion to §11.4.153 `Status.md`), §11.4.44 (revision header), §11.4.65 + §11.4.153 (HTML+PDF+DOCX export).
**Companion of:** `docs/features/Status.md`.

---

## Page 1 — For the team (non-developer, plain language)

### What this project is

A self-hosted toolkit that downloads videos from YouTube and many other sites
(Instagram, Facebook, X, TikTok, Bilibili, and more). It runs as a small set of
containers you start with simple commands. There are three ways to use it:

- **Боба landing page** — a friendly welcome page that walks you through signing
  in to your sites and uploading your cookies so login-protected videos can be
  downloaded.
- **Dashboard** — a modern web app where you paste a link, pick quality, and
  watch your downloads progress, see history, and manage cookies.
- **Command line** (`./download`) — for power users who prefer the terminal.

An optional VPN tunnel can route all downloads privately, and an auto-update
service keeps the container images fresh.

### What works today

- Downloading videos through the dashboard, the classic MeTube interface, or the
  command line.
- The cookie sign-in flow (upload your `cookies.txt`, see how fresh it is per
  site).
- The download queue with live status (waiting, preparing, downloading,
  finishing, done, error, cancelled) and a history list that even remembers
  cancelled items.
- Starting, stopping, restarting, and checking the health of the whole system
  with one command each.
- An optional VPN mode and automatic image updates.

### What is pending

- **No video recordings exist yet.** Every feature still needs a recorded
  "real use" video showing it genuinely working for an end user. Until those
  recordings are made and reviewed, NO feature is marked "video-confirmed" —
  every single one reads **"PENDING — not yet recorded."** This is the honest
  status, not a placeholder.
- A planned **media post-processing** capability — making web-ready video
  versions, pulling out MP3 audio, showing pipeline progress in the dashboard,
  and resuming interrupted downloads — is **not built yet**.
- The automated tests and challenges exist and cover the features, but a full,
  clean, evidence-captured test run is not yet on record in this document, so
  verdicts read "PENDING_FORENSICS" rather than a confirmed PASS.

### Team actions

- None blocking. The VPN mode needs the operator's own VPN credentials to run
  live, but the code path is in place.
- Next milestone: record the per-feature real-use videos so features can move
  from "pending" to genuinely "confirmed."

---

## Page 2 — For software engineers

### File-path anchors

- **Services:** `docker-compose.yml` — `openvpn-yt-dlp`, `metube` / `metube-direct`,
  `landing-vpn` / `landing-no-vpn`, `yt-dlp-cli` / `yt-dlp-cli-vpn`, `dashboard`,
  `watchtower`. Profiles: `vpn`, `no-vpn`, `vpn-cli`, `docker`.
- **Landing (Flask 'Боба'):** `landing/app.py` — routes `/`, `/app`,
  `/api/upload-cookies`, `/api/delete-cookies`, `/api/cookie-status`,
  `/api/aborted-history` (GET/POST/DELETE), `/api/profile-status`, `/health`,
  `/logo.png`, `/favicon.ico`, `/api/delete-download`. Helpers
  `_validate_cookie_file`, `_summarize_cookies_by_platform`,
  `_aborted_history_lock` (flock at `/config/aborted.json.lock`).
- **Dashboard (Angular 17 + nginx):** `dashboard/src/app/` — `app.routes.ts`
  (`''` download-form, `queue`, `history`, `cookies`, `**` not-found);
  components `download-form/`, `queue/` (STATE_META: pending, preparing,
  downloading, postprocessing, finished, error, aborted), `history/`
  (aborted-history merge via `abortedToDownloadInfo`), `cookies/`, `navbar/`
  (profile badge), `error-boundary/`, `not-found/`; services
  `metube.service.ts` (typed API, no `any`), `error-interceptor.service.ts`.
  nginx template `dashboard/nginx.conf.template` + `dashboard/entrypoint.sh`.
- **CLI scripts (repo root, no `.sh` suffix):** `init`, `start`, `start_no_vpn`,
  `stop`, `status`, `download`, `check-vpn`, `restart`, `cleanup`;
  `prepare-release.sh`, `setup-auto-update`, `update-images`. Runtime detection
  via `lib/container-runtime.sh`.
- **Tests:** `tests/test-*.sh` (unit, integration, integration-realhttp,
  scenarios, errors, dashboard, dashboard-operations, aborted-history,
  cookie-validator, media-services, bulk-operations, add-all-platforms,
  add-download, vpn-compose, vpn-smoke, chaos, constitution-inheritance);
  orchestrators `run-tests.sh`, `run-full-suite.sh`, `run-comprehensive-tests.sh`;
  `tests/e2e/` (Playwright: dashboard, landing, cross-service, clear-history,
  delete-retry-cancel, cleanup-and-start); `tests/benchmark/`, `tests/cookies/`,
  `tests/challenges/` (`metube-challenges.json` + `run-metube-challenges.sh`).
- **Challenges (HelixQA):** `challenges/scripts/` (api-contract,
  container-restart-resilience, download-completes, form-reenables,
  host/user OOM+suspend, landing-cookie-upload, memory-limits, no-vpn-direct,
  queue-lifecycle, queue-polling-survives-error, retry-immediately-visible,
  `run_all_challenges.sh`); `Challenges/` submodule (framework + p1-f06..f18
  CLI-agent feature dirs).

### Status vocabulary (§11.4.45 closed set)

`PASS` / `FAIL` / `SKIP` / `PENDING_FORENSICS` / `OPERATOR-BLOCKED`.

- Implemented-and-wired features: **`PENDING_FORENSICS`** — code present + test
  files exist, but no clean-baseline full-suite run with captured runtime
  evidence is on record in this revision (per §11.4.6 an unproven PASS is
  forbidden).
- Planned features (§7 of `Status.md`): **`SKIP`** — nothing to validate.
- `OPERATOR-BLOCKED`: none. VPN live path needs operator `.ovpn` credentials but
  the code path is implemented and compose-config-testable, so it is
  `PENDING_FORENSICS`, not blocked.

### §-anchors

- **§11.4.153** — per-feature Status + Status_Summary set with mandatory real-use
  video confirmation; adds DOCX to the export set for this class.
- **§11.4.107** — no frozen/stale-frame video proof; videos (once recorded) must
  show live, advancing real-use content.
- **§11.4.6** — no-guessing: every row reconciled against real code; no
  unproven PASS; no faked confirmation.
- **§11.4.45 / §11.4.56 / §11.4.44 / §11.4.65** — status-doc maintenance,
  two-audience summary, revision header, multi-format export.

### Video-confirmation status (load-bearing honest fact)

Per §11.4.153, EVERY user-visible confirmed claim must be backed by a recorded
real-use video. **No such video exists for any feature in this project at
Revision 1.** Therefore every row in `Status.md` carries
`Video-Confirmation = PENDING — not yet recorded` — there are zero "confirmed"
cells. This is the truthful state (§11.4.2 / §11.4.5 / §11.4.6), not a stub.

### Planned-feature absence proof

`media_postprocessor`, web-ready transcode, MP3 derivation, post-process status
API, dashboard pipeline-status UI, and resume mechanism were confirmed absent by
grep over `docker-compose.yml`, `dashboard/src`, and `landing/app.py` (no
matches). They are the only `Planned` / `SKIP` rows.
