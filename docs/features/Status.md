# Feature Status Ledger

**Revision:** 1
**Last modified:** 2026-06-15T15:27:34Z
**Authority:** constitution §11.4.153 (per-feature Status + video-recording confirmation), composes §11.4.44 (revision header), §11.4.45 (integration-status-doc + closed status vocabulary), §11.4.56 (Status_Summary two-audience companion), §11.4.65 (HTML+PDF export) + §11.4.153 DOCX, §11.4.107 (no frozen-frame video proof), §11.4.6 (no-guessing — every row reconciled against real code).
**Scope:** Full feature surface of the `ytdlp` Podman/Docker orchestration around `yt-dlp` — every service, client surface, CLI script, landing route, dashboard component, test/challenge suite, and every PLANNED-but-unbuilt feature.
**Maintainer:** project conductor.

---

## How to read this ledger

- **Implementation** — `Implemented` (code present + wired), `Partial` (code present, incomplete/edge-gaps), `Planned` (not yet built).
- **Validation/Verification** — closed status vocabulary per §11.4.45: `PASS` / `FAIL` / `SKIP` / `PENDING_FORENSICS` / `OPERATOR-BLOCKED`. Because no clean-baseline full-suite run with captured evidence was executed in the session that produced this ledger, verdicts that would require live captured runtime evidence are recorded `PENDING_FORENSICS` (per §11.4.6 — an unproven PASS is forbidden; the code is present and test files exist, but a green-with-captured-evidence run is not yet on record here). `Planned` rows carry `SKIP` (no feature to validate yet).
- **Video-Confirmation** — per §11.4.153 every user-visible confirmed claim MUST be backed by a recorded real-use video. **NO feature has a video recording yet.** Therefore **EVERY** row's Video-Confirmation cell is **`PENDING — not yet recorded`**, without exception. None is "confirmed".

> **HONEST FACT (§11.4.6 / §11.4.153):** Not a single feature in this project has a real-use video recording at the time of this revision. Every Video-Confirmation cell below reads `PENDING — not yet recorded`. No row claims video confirmation.

---

## OPERATOR-BLOCKED rows (top per §11.4.45)

No feature in this project is currently `OPERATOR-BLOCKED`. (The VPN profile requires operator-supplied `.ovpn` credentials and `vpn-auth.txt`, but the VPN *code path* is implemented and testable in compose-config form without live credentials, so it is classified `PENDING_FORENSICS`, not `OPERATOR-BLOCKED`.)

---

## 1. SERVICES (docker-compose.yml)

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| VPN tunnel (`dperson/openvpn-client`, NET_ADMIN, `/dev/net/tun`, port 3130, healthcheck ping 8.8.8.8) | openvpn-yt-dlp | Networking / Service | Implemented (`vpn` profile) | Reachable: `metube` + `yt-dlp-cli-vpn` join its netns via `network_mode: service:openvpn-yt-dlp` | `tests/test-vpn-compose.sh`, `tests/test-vpn-smoke.sh`, `challenges/scripts/container_restart_resilience_challenge.sh` | PENDING_FORENSICS (compose config valid; live tunnel needs operator `.ovpn`) | PENDING — not yet recorded |
| Download queue/history API + minimal UI (`ghcr.io/alexta69/metube:latest`, port 8088 direct / netns under VPN) | metube / metube-direct | Backend API / Service | Implemented | Reachable: dashboard nginx + landing proxy to `:8081`; `${DOWNLOAD_DIR}` + `./metube/config` volumes | `tests/test-media-services.sh`, `tests/test-integration-realhttp.sh`, `tests/test-add-download.sh`, `tests/challenges/run-metube-challenges.sh`, `challenges/scripts/download_completes_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Flask 'Боба' cookie-auth onboarding + aborted-history ledger + proxy endpoints (`landing/`, ports 8087 vpn / 8086 no-vpn) | landing-vpn / landing-no-vpn | Web UI + API / Service | Implemented | Reachable: published port; proxies cookie + delete-download to MeTube; writes `/config/aborted.json` | `tests/test-dashboard.sh`, `tests/test-aborted-history.sh`, `tests/test-cookie-validator.sh`, `challenges/scripts/landing_cookie_upload_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Sleeping CLI container for `./download` (`ghcr.io/jim60105/yt-dlp:pot`, `while true; do sleep 3600; done`, cookie copy at startup) | yt-dlp-cli / yt-dlp-cli-vpn | CLI backend / Service | Implemented | Reachable: `./download` execs `yt-dlp` inside it; `yt-dlp/config`, `cookies`, `archive` + downloads volumes | `tests/test-media-services.sh`, `challenges/scripts/download_completes_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Angular 17 + nginx dashboard (`dashboard/`, port 9090, `/api/*` proxied to MeTube + landing) | dashboard | Web UI / Service | Implemented (`no-vpn` profile only) | Reachable: nginx `resolver` + variable `proxy_pass` from `entrypoint.sh` template | `tests/test-dashboard.sh`, `tests/test-dashboard-operations.sh`, `tests/e2e/tests/dashboard.spec.ts`, Angular `*.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| Image auto-update (`containrrr/watchtower:latest`, schedule `0 0 */3 * * *`, cleanup) | watchtower | Infra / Service | Implemented (`docker` profile) | Reachable: docker.sock mount; gated by `com.centurylinklabs.watchtower.enable` labels | bash compose-config gate (`make ci`) | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 2. CLIENT SURFACES

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| Dashboard web UI (download-form / queue / history / cookies / navbar, error-boundary, not-found) | dashboard | Web client | Implemented | Routed via `app.routes.ts`; calls `/api/*` through nginx | `tests/test-dashboard.sh`, `tests/e2e/tests/dashboard.spec.ts`, component `*.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| Landing Flask 'Боба' UI (3-step cookie onboarding, drag-drop upload, freshness banner, services grid) | landing | Web client | Implemented | `INDEX_TEMPLATE` in `landing/app.py`; auto-redirect to dashboard | `tests/e2e/tests/landing.spec.ts`, `tests/test-dashboard.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| MeTube minimal UI (vendor original interface, dark theme) | metube | Web client | Implemented (vendor) | Served on `:8088`; linked as "Classic UI" from landing | `tests/test-media-services.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `./download` CLI (host script execs yt-dlp in sleeping container) | download | CLI client | Implemented | `./download` → `exec` into `yt-dlp-cli`; runtime auto-detect | `tests/test-media-services.sh`, `challenges/scripts/download_completes_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 3. ROOT CLI SCRIPTS

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| Init environment (create dirs, validate `.env`, generate `yt-dlp.conf`, write `vpn-auth.txt` chmod 600) | ./init | CLI script | Implemented | Runtime auto-detect via `lib/container-runtime.sh` | `tests/test-unit.sh`, `tests/test-integration.sh`, `tests/test-scenarios.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Start services (reads `USE_VPN`, pulls images, brings up profile) | ./start | CLI script | Implemented | compose up via detected runtime | `tests/test-scenarios.sh`, `tests/test-integration.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Start no-vpn (force no-vpn profile) | ./start_no_vpn | CLI script | Implemented | compose `--profile no-vpn` | `tests/test-scenarios.sh`, `challenges/scripts/no_vpn_profile_direct_access_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Stop services (all profiles, clean pods/networks) | ./stop | CLI script | Implemented | compose down + cleanup | `tests/test-scenarios.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Status summary (service + HTTP health) | ./status | CLI script | Implemented | queries running containers + HTTP endpoints | `tests/test-integration-realhttp.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Download helper (yt-dlp via exec) | ./download | CLI script | Implemented | exec into `yt-dlp-cli` | `tests/test-media-services.sh`, `challenges/scripts/download_completes_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Check VPN (query ipinfo.io inside VPN container) | ./check-vpn | CLI script | Implemented | exec into `openvpn-yt-dlp` | `tests/test-vpn-smoke.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Restart services | ./restart | CLI script | Implemented | stop + start sequence | `tests/test-scenarios.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Cleanup containers/pods/networks | ./cleanup | CLI script | Implemented | compose down + prune | `tests/test-scenarios.sh`, `challenges/scripts/container_restart_resilience_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Release preparation (commit + push) | ./prepare-release.sh | CLI script | Implemented | git operations | bash `-n` syntax gate (`make ci`) | PENDING_FORENSICS | PENDING — not yet recorded |
| Auto-update setup (cron for Podman; Watchtower alt for Docker) | ./setup-auto-update | CLI script | Implemented | writes cron entry / documents Watchtower | bash `-n` syntax gate | PENDING_FORENSICS | PENDING — not yet recorded |
| Update images (pull latest before start) | ./update-images | CLI script | Implemented | compose pull via detected runtime | bash `-n` syntax gate | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 4. LANDING ROUTES (landing/app.py)

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| `/` — Боба onboarding page (3-step cookie flow, session id, dynamic service URLs) | landing | HTTP route | Implemented | `render_template_string(INDEX_TEMPLATE)` | `tests/e2e/tests/landing.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/app` — proxy GET to MeTube backend | landing | HTTP proxy route | Implemented | `requests.get(METUBE_URL)` streamed back | `tests/test-dashboard.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/upload-cookies` (POST) — validate Netscape file (UTF-8 + recognised-domain gate) → forward to MeTube | landing | HTTP API route | Implemented | `_validate_cookie_file` + POST to `${METUBE_URL}/upload-cookies` | `tests/test-cookie-validator.sh`, `challenges/scripts/landing_cookie_upload_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/delete-cookies` (POST) — remove `/config/cookies.txt` | landing | HTTP API route | Implemented | `os.remove` | `tests/test-dashboard.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/cookie-status` (GET) — has_cookies + age + per-platform breakdown + MeTube reachability | landing | HTTP API route | Implemented | `_summarize_cookies_by_platform` + MeTube fallback | `tests/test-cookie-validator.sh`, `tests/test-dashboard.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/aborted-history` (GET) — return persisted aborted list | landing | HTTP API route | Implemented | `_read_aborted_history` (lock-free read) | `tests/test-aborted-history.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/aborted-history` (POST) — append entry, flock-guarded, 60s idempotency | landing | HTTP API route | Implemented | `_aborted_history_lock` + `_write_aborted_history` | `tests/test-aborted-history.sh` (incl. concurrent-posts case) | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/aborted-history` (DELETE) — remove specific urls or `*` | landing | HTTP API route | Implemented | locked read-modify-write | `tests/test-aborted-history.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/profile-status` (GET) — active compose profile + vpn_active + MeTube reachability | landing | HTTP API route | Implemented | reads `ACTIVE_PROFILE` env | `tests/test-dashboard.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/health` (GET) — service + MeTube reachability + timestamp | landing | HTTP API route | Implemented | `requests.get(${METUBE_URL}/history)` | `tests/test-integration-realhttp.sh`, `tests/test-vpn-smoke.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/logo.png` (GET) — serve branding asset | landing | HTTP static route | Implemented | `send_from_directory` | `tests/e2e/tests/landing.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| `/favicon.ico` (GET) — 204 stub | landing | HTTP static route | Implemented | returns `"", 204` | — (trivial; covered by landing smoke) | PENDING_FORENSICS | PENDING — not yet recorded |
| `/api/delete-download` (POST) — remove from history + optional file delete (path-traversal guarded) | landing | HTTP API route | Implemented | POST `${METUBE_URL}/delete` + `os.walk`/`os.remove` within `DOWNLOAD_DIR` | `tests/test-dashboard.sh`, `tests/e2e/tests/delete-retry-cancel.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 5. DASHBOARD COMPONENTS (dashboard/src/app)

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| Download form (url, quality select, format select, folder, add via `/api/add`, inline tracker + error state, re-enable after failure) | download-form | Angular component | Implemented | `MeTubeService.addDownload` | `download-form.component.spec.ts`, `challenges/scripts/form_reenables_after_failure_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| Queue (STATE_META: pending / preparing / downloading / postprocessing / finished / error / aborted; cancel-all; record-and-close aborted) | queue | Angular component | Implemented | `getHistoryPolling` + `recordAbortedItem` | `queue.component.spec.ts`, `challenges/scripts/queue_lifecycle_challenge.sh`, `challenges/scripts/queue_polling_survives_error_challenge.sh` | PENDING_FORENSICS | PENDING — not yet recorded |
| History (+ aborted-history merge via `abortedToDownloadInfo`, retry, delete-with-file, batch + delete-all, refresh) | history | Angular component | Implemented | `getHistory` + `getAbortedHistory` + `deleteDownloadWithFile` | `history.component.spec.ts`, `tests/e2e/tests/clear-history.spec.ts`, `tests/e2e/tests/delete-retry-cancel.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| Cookies (status badge fresh/expiring/expired, age, MeTube online/offline, per-platform breakdown, upload, delete) | cookies | Angular component | Implemented | `getCookieStatus` + `uploadCookies` + `deleteCookies` | `cookies.component.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| Navbar (routerLinks Download/Queue/History/Cookies; VPN / No-VPN / unknown profile badge; MeTube-unreachable badge) | navbar | Angular component | Implemented | `getProfileStatus` | covered via dashboard E2E + Angular harness | PENDING_FORENSICS | PENDING — not yet recorded |
| Error boundary (renders loading / error+retry / empty / content states) | error-boundary | Angular component | Implemented | wrapped around list components | covered via component specs | PENDING_FORENSICS | PENDING — not yet recorded |
| Not-found (404 catch-all route) | not-found | Angular component | Implemented | `**` route in `app.routes.ts` | covered via routing smoke | PENDING_FORENSICS | PENDING — not yet recorded |
| Error interceptor (RxJS error surfacing, clears loading) | error-interceptor.service | Angular service | Implemented | `app.config.ts` provider | `metube.service.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |
| MeTube service (typed API: add/start/history/delete/clear/retry/cookies/profile/aborted/version/poll; no `any`) | metube.service | Angular service | Implemented | `HttpClient` to `/api/*` | `metube.service.spec.ts`, `metube.service.bulk.spec.ts` | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 6. TESTS / CHALLENGES (real test files reconciled)

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| Unit tests (pure-shell logic) | tests/test-unit.sh | Test suite | Implemented | `run-tests.sh -p unit` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Integration tests (containers up) | tests/test-integration.sh | Test suite | Implemented | `run-tests.sh -p integration` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Real-HTTP integration (no mocks, hits `:9090`/`:8086`/`:8088`) | tests/test-integration-realhttp.sh | Test suite | Implemented | services must be up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Scenario tests (lifecycle phases) | tests/test-scenarios.sh | Test suite | Implemented | `run-tests.sh -p scenario` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Error-phase tests | tests/test-errors.sh | Test suite | Implemented | `run-tests.sh -p error` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Dashboard + landing integration | tests/test-dashboard.sh | Test suite | Implemented | services up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Dashboard operations (post-fix full automation) | tests/test-dashboard-operations.sh | Test suite | Implemented | services up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Aborted-history (incl. concurrent-posts no-500) | tests/test-aborted-history.sh | Test suite | Implemented | landing up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Cookie validator (`_validate_cookie_file`) | tests/test-cookie-validator.sh | Test suite | Implemented | landing app.py | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Media-services compatibility (anti-bluff documented-failure) | tests/test-media-services.sh | Test suite | Implemented | yt-dlp-cli / metube up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Bulk operations | tests/test-bulk-operations.sh | Test suite | Implemented | services up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Add-all-platforms / add-download | tests/test-add-all-platforms.sh, tests/test-add-download.sh | Test suite | Implemented | metube up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| VPN compose + smoke | tests/test-vpn-compose.sh, tests/test-vpn-smoke.sh | Test suite | Implemented | vpn profile | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Chaos / resilience | tests/test-chaos.sh | Test suite | Implemented | services up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Constitution inheritance + meta-test | tests/test-constitution-inheritance.sh, tests/meta-test-constitution-inheritance.sh | Test suite | Implemented | repo tree | self | PENDING_FORENSICS | PENDING — not yet recorded |
| E2E (Playwright): dashboard, landing, cross-service, clear-history, delete-retry-cancel, cleanup-and-start | tests/e2e/ | E2E suite | Implemented | `run-e2e.sh` + `playwright.config.ts` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Benchmark suite | tests/benchmark/run-benchmarks.sh | Benchmark suite | Implemented | services up | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Cookie auth + youtube-download + validate-fix | tests/cookies/ | Test suite | Implemented | metube + cookies | self | PENDING_FORENSICS | PENDING — not yet recorded |
| MeTube anti-bluff challenge bank (download-completes, queue-realtime, form-reenables) | tests/challenges/ | Challenge bank | Implemented | `run-metube-challenges.sh` + `metube-challenges.json` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Root HelixQA challenge scripts (api-contract, container-restart-resilience, download-completes, form-reenables, host/user OOM+suspend, landing-cookie-upload, memory-limits, no-vpn-direct, queue-lifecycle, queue-polling, retry-visible) | challenges/scripts/ | Challenge bank | Implemented | `run_all_challenges.sh` | self | PENDING_FORENSICS | PENDING — not yet recorded |
| Challenges submodule (HelixQA challenge framework, p1-f06..f18 CLI-agent feature dirs) | Challenges/ | Challenge framework (submodule) | Implemented (submodule) | `Challenges/` catalogue | submodule self-tests | PENDING_FORENSICS | PENDING — not yet recorded |

---

## 7. PLANNED — not yet built (Implementation = Planned)

Confirmed ABSENT from the codebase (grep over `docker-compose.yml`, `dashboard/src`, `landing/app.py` returned no matches — §11.4.6).

| Feature | Component | Category | Implementation | Wiring | Tests Coverage | Validation/Verification | Video-Confirmation |
|---|---|---|---|---|---|---|---|
| Media post-processor service (new container orchestrating transcode/derive pipeline) | media_postprocessor | Service (planned) | Planned | Not wired — no compose service exists | None yet | SKIP (no feature to validate) | PENDING — not yet recorded |
| Web-ready video transcode (browser-playable derivative output) | media_postprocessor | Pipeline feature (planned) | Planned | Not wired | None yet | SKIP | PENDING — not yet recorded |
| MP3 audio derivation (extract/encode audio track) | media_postprocessor | Pipeline feature (planned) | Planned | Not wired | None yet | SKIP | PENDING — not yet recorded |
| Post-process status API (report pipeline progress per item) | media_postprocessor / landing | API feature (planned) | Planned | Not wired — no route exists in `landing/app.py` | None yet | SKIP | PENDING — not yet recorded |
| Dashboard pipeline-status UI (surface transcode/derive progress) | dashboard | Web UI feature (planned) | Planned | Not wired — no component exists | None yet | SKIP | PENDING — not yet recorded |
| Resume mechanism (resume interrupted/aborted downloads) | metube / media_postprocessor | Pipeline feature (planned) | Planned | Not wired | None yet | SKIP | PENDING — not yet recorded |

---

## Reconciliation note (§11.4.153 / §11.4.118)

Every row above maps to real code (a named compose service, a Flask route in `landing/app.py`, an Angular component/service file under `dashboard/src/app/`, a root CLI script, or a test/challenge file) — except the §7 PLANNED rows, which are explicitly marked `Planned`/`SKIP` because the codebase contains no matching implementation. No code-present feature is omitted; no row lacks corresponding code. Per §11.4.6, no verdict claims a PASS without captured evidence, and per §11.4.153 no Video-Confirmation cell claims "confirmed" — all read `PENDING — not yet recorded`.
