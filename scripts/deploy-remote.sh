#!/usr/bin/env bash
# Deploy the ytdlp no-vpn System to a remote Podman host (§11.4.76 containers-submodule
# distributed booting). Reproducible, anti-bluff: validates the deploy with the project's
# own ./status (body-matched HTTP checks, CONST-034).
#
# Purpose:   rsync the build contexts + scripts to a remote host, place cookies, write a
#            remote .env, run ./init + ./start_no_vpn there, then ./status to verify.
# Usage:     scripts/deploy-remote.sh <user@host> [remote_dir] [cookies_file]
#            e.g. scripts/deploy-remote.sh milosvasic@nezha.local '~/ytdlp' ~/Downloads/cookies.txt
# Inputs:    a reachable SSH host with key-based auth + Podman + podman-compose preinstalled;
#            the host is registered in deploy/remote-hosts.env (CONTAINERS_REMOTE_*).
# Outputs:   a running no-vpn ytdlp stack on the remote host (:8086/:8088/:9090).
# Side-effects: writes <remote_dir> on the remote host; copies cookies (chmod 600).
# Cross-references: deploy/remote-hosts.env, containers/docs/REMOTE_DEPLOYMENT.md,
#            constitution §11.4.76 / §11.4.31.
#
# ROOT-CAUSE NOTE (2026-06-16, systematic-debugging §11.4.102): the FIRST deploy of this
# System failed because an over-broad rsync exclude `--exclude='*.html'` (intended only for
# doc exports under docs/) ALSO stripped `dashboard/src/index.html`, so the Angular
# `ng build` aborted with "Failed to read index HTML file /app/src/index.html" (podman
# reported exit 127) and the dashboard image never built. The fix is baked in below: the
# rsync NEVER excludes `*.html` globally; it excludes only build artifacts + the already-
# excluded submodule/docs trees. DO NOT re-introduce a global `*.html` exclude.
set -euo pipefail

DEST="${1:?usage: deploy-remote.sh <user@host> [remote_dir] [cookies_file]}"
REMOTE_DIR="${2:-~/ytdlp}"
COOKIES="${3:-$HOME/Downloads/cookies.txt}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10)

echo "==> [1/6] preflight: SSH + podman on $DEST"
"${SSH[@]}" "$DEST" 'podman --version && podman-compose --version' >/dev/null

echo "==> [2/6] rsync build contexts + scripts (NO global *.html exclude — see ROOT-CAUSE NOTE)"
rsync -az --timeout=120 \
  --exclude='.git/' --exclude='node_modules/' --exclude='dashboard/node_modules/' \
  --exclude='dashboard/dist/' --exclude='dashboard/.angular/' \
  --exclude='constitution/' --exclude='containers/' --exclude='Challenges/' \
  --exclude='helixqa/' --exclude='docs_chain/' --exclude='HelixAgent/' --exclude='Media/' \
  --exclude='qa-results/' --exclude='docs/' --exclude='.env' \
  "$HERE/" "$DEST:$REMOTE_DIR/"

echo "==> [3/6] place cookies (chmod 600) where MeTube + yt-dlp-cli read them"
if [ -f "$COOKIES" ]; then
  "${SSH[@]}" "$DEST" "mkdir -p $REMOTE_DIR/yt-dlp/cookies $REMOTE_DIR/metube/config"
  scp -o BatchMode=yes "$COOKIES" "$DEST:$REMOTE_DIR/yt-dlp/cookies/cookies.txt"
  "${SSH[@]}" "$DEST" "cp $REMOTE_DIR/yt-dlp/cookies/cookies.txt $REMOTE_DIR/metube/config/cookies.txt && chmod 600 $REMOTE_DIR/yt-dlp/cookies/cookies.txt $REMOTE_DIR/metube/config/cookies.txt"
else
  echo "    (no cookies file at $COOKIES — skipping; auth'd downloads will be limited)"
fi

echo "==> [4/6] write remote .env (DOWNLOAD_DIR on persistent disk, NOT tmpfs)"
ID="$("${SSH[@]}" "$DEST" 'echo "$(id -u):$(id -g)"')"
"${SSH[@]}" "$DEST" "cat > $REMOTE_DIR/.env <<EOF
CONTAINER_RUNTIME=podman
USE_VPN=false
DOWNLOAD_DIR=\$HOME/ytdlp-data/downloads
PUID=${ID%%:*}
PGID=${ID##*:}
TZ=Europe/Moscow
METUBE_PORT=8086
METUBE_DIRECT_PORT=8088
SERVICE_MODE=false
YOUTUBE_COOKIES=true
DEFAULT_QUALITY=1080p
EOF
mkdir -p \$HOME/ytdlp-data/downloads"

echo "==> [5/6] init + start_no_vpn on remote (builds 3 images, boots no-vpn profile)"
"${SSH[@]}" "$DEST" "cd $REMOTE_DIR && chmod +x init start_no_vpn status stop download 2>/dev/null; bash init >/dev/null && bash start_no_vpn"

echo "==> [6/6] verify with ./status (anti-bluff body-matched HTTP checks)"
"${SSH[@]}" "$DEST" "cd $REMOTE_DIR && bash status"
echo "==> deploy-remote.sh done for $DEST"
