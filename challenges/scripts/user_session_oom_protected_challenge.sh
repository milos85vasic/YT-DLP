#!/bin/bash
#
# user_session_oom_protected_challenge.sh
#
# Asserts that the kernel OOM killer will NOT pick user@1000.service
# as a victim before the offending project's containers — the
# defence-in-depth layer 6 of CONST-033, added after the 2026-04-27
# incident where a neighbour project's uncapped V8 / python3 pod
# OOM-cascaded into the user's session.
#
# Anti-bluff (CONST-034): we don't trust a `cat unit-file | grep
# OOMScoreAdjust` check — the unit might say -500 but the running
# pid might still have its kernel default. We read the LIVE value
# from /proc/<pid>/oom_score_adj.
#
# Exit:
#   0 = user session is OOM-protected
#   1 = at least one assertion failed
#   2 = invocation error

set -uo pipefail

TARGET_UID="${1:-1000}"
TARGET_UNIT="user@${TARGET_UID}.service"

echo "=== user_session_oom_protected_challenge ==="
echo "target unit: $TARGET_UNIT"
echo

PASS=0
FAIL=0

# 1. Drop-in present.
echo "[1/3] Checking for drop-in /etc/systemd/system/${TARGET_UNIT}.d/00-oom-protection.conf…"
DROPIN="/etc/systemd/system/${TARGET_UNIT}.d/00-oom-protection.conf"
if [ -r "$DROPIN" ] && grep -qE "OOMScoreAdjust=-[0-9]+" "$DROPIN"; then
    echo "    PASS: drop-in present, OOMScoreAdjust set"
    PASS=$((PASS+1))
else
    echo "    FAIL: $DROPIN missing or OOMScoreAdjust unset."
    echo "          Run: sudo bash scripts/host-power-management/protect-user-session-from-oom.sh"
    FAIL=$((FAIL+1))
fi

# 2. systemd resolves OOMScoreAdjust to ≤ -100.
echo "[2/3] Asking systemd for the resolved OOMScoreAdjust on $TARGET_UNIT…"
RESOLVED=$(systemctl show -p OOMScoreAdjust --value "$TARGET_UNIT" 2>/dev/null || echo "")
if [ -n "$RESOLVED" ] && [ "$RESOLVED" -le -100 ] 2>/dev/null; then
    echo "    PASS: systemd OOMScoreAdjust = $RESOLVED (≤ -100)"
    PASS=$((PASS+1))
else
    echo "    FAIL: systemd reports OOMScoreAdjust='$RESOLVED' (need ≤ -100)"
    FAIL=$((FAIL+1))
fi

# 3. The LIVE pid's /proc/<pid>/oom_score_adj reflects the setting.
#    This is the anti-bluff anchor — unit file says one thing, kernel
#    says another, the kernel wins. If the unit was edited but never
#    re-applied, this catches it.
echo "[3/3] Verifying /proc/<MainPID>/oom_score_adj on the running unit…"
PID=$(systemctl show -p MainPID --value "$TARGET_UNIT" 2>/dev/null || echo "")
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
    echo "    SKIP: $TARGET_UNIT not running (MainPID=$PID)"
elif [ ! -r "/proc/$PID/oom_score_adj" ]; then
    echo "    SKIP: /proc/$PID/oom_score_adj not readable"
else
    LIVE=$(cat "/proc/$PID/oom_score_adj")
    if [ "$LIVE" -le -100 ] 2>/dev/null; then
        echo "    PASS: kernel oom_score_adj on PID $PID = $LIVE (≤ -100)"
        PASS=$((PASS+1))
    else
        echo "    FAIL: kernel oom_score_adj on PID $PID = $LIVE (need ≤ -100)"
        echo "          The unit drop-in is set but never re-applied to the running"
        echo "          process. Run: sudo bash scripts/host-power-management/protect-user-session-from-oom.sh"
        FAIL=$((FAIL+1))
    fi
fi

echo
echo "=== summary: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ]
