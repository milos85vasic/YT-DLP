# Pending false-success fixes (CONST-034 / §7.1)

A live-verification pass on 2026-06-13 ran an anti-bluff audit of the
orchestration scripts. Several scripts claimed success/health **without
verifying the real end-state**. The fixes below are designed and ready, but
they require a **live stack / real download to verify**, so per CONST-034 they
have **NOT been shipped unverified**. Apply + verify each, then move it out of
this file.

Already fixed + verified (for reference): `stop` (now passes all profiles +
verifies no container survives), `smoke-test.sh` Gate 6 (arm64 documented
yt-dlp-cli), `init` (artifact check), `update-images` (real cache check).

---

## 1. `start` / `start_no_vpn` — "Services started successfully!" without proof

**Defect:** Printed success immediately after `compose ... up -d`. `up -d` only
*schedules* containers; exit 0 ≠ running (image half-pull, port clash, OOM, bad
mount can all leave a container down).

**Fix:** After `up -d`, poll (timeout ~120s) until the expected containers reach
"running", then print success; otherwise print the `ps` table and `exit 1`.
Expected names — no-vpn: `metube-direct`, `metube-landing`, `yt-dlp-dashboard`
(treat `yt-dlp-cli` as the smoke-test arm64 documented-exception — amd64-only
PoT image); vpn profile: resolve from `docker-compose.yml`.

**Verification gate (required before shipping):** bring up the no-vpn stack and
confirm the script exits 0; then deliberately `podman stop metube-direct` before
a run and confirm it now exits non-zero with the failing container listed.
(The dashboard image + base images are already cached, so the bring-up is fast.)

## 2. `status` — health reported on HTTP code only, not body

**Defect:** `health_check` marked a service healthy on `%{http_code}==200`
alone. An HTML 502 wrapped in a 200, or a curl `000` early-close, reads as
healthy (violates §7.1 "body, not status").

**Fix:** Make `health_check` take an expected-body token and require BOTH a 200
AND the token present in the body, per endpoint:
- `:8088/history` → `"queue"`  · `:9090/api/history` → `"queue"`
- `:8086/api/cookie-status` → `"has_cookies"`  · `:9090/` → `app-root`
- `:8086/` (or `/health`) → `"status":"ok"`

**Verification gate:** bring up the stack, run `./status`, confirm all checks
green with bodies; stop one service and confirm it flips to UNHEALTHY (not a
false green).

## 3. `download` — "downloaded" without an artifact on disk (ARTIFACT rule)

**Defect:** Runs `yt-dlp` in the container and returns its exit code; never
confirms a file landed in `$DOWNLOAD_DIR`. "Download succeeded" ≠ "yt-dlp exit
0" (§7.1 ARTIFACT rule).

**Fix:** At each of the 3 invocation sites (`--batch`, `--channels`, single
URL): capture a pre-run timestamp, run yt-dlp, and on exit 0 `find
"$DOWNLOAD_DIR" -type f -newermt <ts> -size +1k` (recursive, handles playlist
subfolders); if none found, print a diagnostic and `exit 1`. Scope strictly to
real download invocations.

**Verification gate — BLOCKED on this host:** the `yt-dlp-cli`/PoT image is
amd64-only, so `download` cannot run on this arm64 machine at all. This fix
**can only be verified on a Linux x86_64 host** with a real download producing a
file >1KB in `$DOWNLOAD_DIR` (the `download_completes_challenge.sh` template).

---

*Full ready-to-apply edit blocks for all three were generated during the audit
and can be regenerated on request. Each must pass its verification gate above
before being committed into the live script.*
