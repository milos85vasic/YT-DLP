#!/bin/bash
# protect-user-session-from-oom.sh
#
# MANUAL PREREQUISITE — run ONCE per host, with sudo, BEFORE any
# project shares this host with memory-hungry workloads (HelixAgent,
# Node.js / V8 services, ML/CV pipelines, etc.).
#
# Background (CONST-033 — addendum 2026-04-27): twice in the last
# week the user's session (`user@1000.service`) was terminated by
# the kernel OOM killer. The blast radius is identical to a suspend:
# every container the user was running (MeTube, HelixAgent, all
# parallel CLI agents) dies at once, the SSH session drops, the GUI
# greeter shows the lock screen — indistinguishable from a
# "logged out" event.
#
# Forensic from the 2026-04-27 22:22 incident:
#   journalctl: user@1000.service: Main process exited, code=killed, status=9/KILL
#   journalctl: user-1000.slice: A process of this unit has been killed by the OOM killer.
# The OOM cascade originated in a NON-MeTube pod with V8/python3
# workers and no memory limit. Once that pod's cgroup hit its memory
# ceiling, the kernel walked up the cgroup tree and eventually picked
# user@1000.service as the victim because it had the highest
# cumulative RSS in user.slice.
#
# This script makes user@1000.service the LAST victim the kernel
# considers, not the first, by setting OOMScoreAdjust=-500 on it.
# Combined with per-container mem_limit (already enforced for
# MeTube), this prevents the cascade from ever reaching the session.
#
# Verification (re-run the challenge after this script):
#   bash challenges/scripts/user_session_oom_protected_challenge.sh
# Both assertions must PASS.

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: must be run as root (sudo)." >&2
    exit 1
fi

TARGET_UID="${1:-1000}"
TARGET_UNIT="user@${TARGET_UID}.service"

echo "[1/3] Adding OOMScoreAdjust=-500 drop-in for $TARGET_UNIT…"
DROPIN_DIR="/etc/systemd/system/${TARGET_UNIT}.d"
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_DIR/00-oom-protection.conf" <<EOF
# CONST-033 (2026-04-27 addendum): protect the user session from
# the kernel OOM killer. Without this, neighbouring projects'
# uncapped containers can OOM-cascade and take the user's session
# down, which is observationally indistinguishable from suspend.
[Service]
OOMScoreAdjust=-500
EOF

echo "[2/3] Reloading systemd…"
systemctl daemon-reload

echo "[3/3] Re-applying to the running unit (no restart — that would log the user out)…"
# Hot-apply by writing /proc/<pid>/oom_score_adj of the running
# user@1000.service main pid so the change takes effect immediately
# without forcing a session bounce.
if pid=$(systemctl show -p MainPID --value "$TARGET_UNIT" 2>/dev/null) && [ -n "$pid" ] && [ "$pid" != "0" ]; then
    if [ -w "/proc/$pid/oom_score_adj" ]; then
        echo "-500" > "/proc/$pid/oom_score_adj"
        echo "    Set oom_score_adj=-500 on running PID $pid"
    fi
fi

echo
echo "DONE. Verify with:"
echo "  bash challenges/scripts/user_session_oom_protected_challenge.sh"
echo
echo "Belt-and-braces: also ensure every project's containers have"
echo "explicit mem_limit. MeTube's docker-compose.yml does (256m–1.5g"
echo "per service). For neighbour projects, add mem_limit per service"
echo "to their compose files — uncapped containers are how the OOM"
echo "cascade starts in the first place."
