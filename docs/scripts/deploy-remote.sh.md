# deploy-remote.sh — companion guide (§11.4.18)

**Last verified:** 2026-06-16 (nezha.local deploy).

## Overview
Deploys the ytdlp **no-vpn** System to a remote Podman host for heavy testing that
needs real running production services (§11.4.76 containers-submodule distributed
booting). Reproducible + anti-bluff: ends with the project's own `./status`
(body-matched HTTP checks per CONST-034).

## Prerequisites
- Remote host with key-based SSH, Podman + podman-compose, a persistent (non-tmpfs)
  data disk. Registered in `deploy/remote-hosts.env` (`CONTAINERS_REMOTE_*`).
- Local `cookies.txt` (Netscape) if auth'd downloads are wanted.

## Usage
```bash
scripts/deploy-remote.sh milosvasic@nezha.local '~/ytdlp' ~/Downloads/cookies.txt
```
Steps: preflight → rsync build contexts → place cookies (chmod 600) → write remote
`.env` → `./init` + `./start_no_vpn` → `./status` verify. Stack lands on
`:8086` (landing), `:8088` (MeTube), `:9090` (dashboard).

## Edge cases / known root cause
- **Do NOT add a global `--exclude='*.html'` to the rsync.** It strips
  `dashboard/src/index.html`, breaking the Angular `ng build` ("Failed to read index
  HTML file /app/src/index.html", podman exit 127) so the dashboard image never
  builds. This was the first-deploy failure on 2026-06-16; the fix is baked into the
  script (it excludes only build artifacts + already-excluded submodule/docs trees).
- `DOWNLOAD_DIR` must be on a persistent disk, never tmpfs/`/tmp` (silent
  download-finished-but-no-file failure under podman PrivateTmp) — `./init` refuses
  tmpfs.

## Related
`deploy/remote-hosts.env`, `containers/docs/REMOTE_DEPLOYMENT.md`, `./init`,
`./start_no_vpn`, `./status`, constitution §11.4.76 / §11.4.31.
