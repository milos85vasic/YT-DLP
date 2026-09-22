#!/bin/bash
#
# YT-DLP — boot entrypoint
#
# Starts every configured service through `systemctl --user` (the mandatory
# integration path — never raw `podman run` / docker-compose for day-to-day
# operation), then verifies: systemd service state, real HTTP reachability
# on loopback, AND real HTTP reachability on the host's LAN-facing address.
#
# Requires ./install to have been run at least once.
#
# Usage:
#   ./boot
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env not found. Run ./install first." >&2
    exit 1
fi

exec env USE_SYSTEMD=true "$SCRIPT_DIR/scripts/lifecycle/boot.sh" "$@"
