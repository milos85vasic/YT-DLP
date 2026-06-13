# Pending false-success fixes (CONST-034 / §7.1)

A live-verification pass on 2026-06-13 ran an anti-bluff audit of the
orchestration scripts. Several scripts claimed success/health **without
verifying the real end-state**. The fixes below are designed and ready, but
they require a **live stack / real download to verify**, so per CONST-034 they
have **NOT been shipped unverified**. Apply + verify each, then move it out of
this file.

Already fixed + verified (for reference): `stop` (passes all profiles + verifies
no container survives), `smoke-test.sh` Gate 6 (arm64 documented yt-dlp-cli),
`init` (artifact check), `update-images` (real cache check), **`start_no_vpn`
(readiness gate — verified: exit 0 only after the 3 no-vpn services are up; the
arm64 yt-dlp-cli `up -d` failure is tolerated via `|| true` so the gate is
authoritative)**, **`status` (body-check — verified positive + negative under
bash 5: stopping metube flips MeTube/proxy to UNHEALTHY)**.

---

## 1. `start` (VPN profile) — "Services started successfully!" without proof

**Defect:** Like the now-fixed `start_no_vpn`, `start` prints success right after
`compose ... up -d`; exit 0 only means containers were scheduled.

**Fix:** Apply the same readiness-gate pattern already shipped in `start_no_vpn`
(poll until the expected containers are running; `up -d || true` so a documented
arch failure doesn't abort; the gate decides success). The VPN profile container
names must be resolved from `docker-compose.yml` (openvpn-yt-dlp + the metube
that joins its netns + landing-vpn).

**Verification gate (NOT done here):** needs valid VPN credentials + the `vpn`
profile to bring up; could not be verified on this session's host. Verify on a
host with VPN creds before shipping.

## 2. `download` — "downloaded" without an artifact on disk (ARTIFACT rule)

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
