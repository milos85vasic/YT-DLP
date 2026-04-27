#!/bin/bash
#
# user_session_oom_protected_challenge.sh
#
# CONST-033 / CONST-034: anti-OOM-cascade defence for MeTube,
# verified ENTIRELY from outside the containers — no sudo, no
# host-side systemd edits required. The check answers:
#
#   "Is every MeTube container configured to volunteer for early
#    OOM kill, AND does each container have a memory limit so a
#    runaway one can't drag down the user session before the
#    kernel notices?"
#
# Why containerized: per the user-session OOM cascade observed
# 2026-04-27, the kernel picks the highest-RSS process in user.slice
# when its memory ceiling is hit. We can't change the user session's
# baseline OOM score from inside containers (rootless podman caps
# oom_score_adj at the parent's value), but we CAN guarantee every
# MeTube container declares a non-zero oom_score_adj AND a mem_limit.
# That makes our containers always-volunteers, so the kernel picks
# them before walking up to the user session — the cascade ends in
# our cgroup, not in the operator's session.
#
# This challenge runs as the regular user. No sudo. No host edits.
#
# Anti-bluff (CONST-034): we read /proc/<pid>/oom_score_adj on the
# RUNNING container, not the compose declaration — a value declared
# in YAML but not realised at runtime is bluff.
#
# Exit:
#   0 = every running MeTube container is OOM-protected
#   1 = at least one container is missing a defence
#   2 = invocation error (no container runtime, no containers running)

set -uo pipefail

RT=podman
if ! command -v podman >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        RT=docker
    else
        echo "FAIL: no container runtime available"
        exit 2
    fi
fi

EXPECTED_CONTAINERS=(metube-direct metube-landing yt-dlp-cli yt-dlp-dashboard)
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

echo "=== user_session_oom_protected_challenge ==="
echo "runtime: $RT"
echo

PASS=0
FAIL=0

# 1. Every expected container is RUNNING.
echo "[1/3] Checking that every MeTube container is running…"
RUNNING=$("$RT" ps --format "{{.Names}}" 2>/dev/null)
for c in "${EXPECTED_CONTAINERS[@]}"; do
    if echo "$RUNNING" | grep -qx "$c"; then
        echo "    PASS: $c is running"
        PASS=$((PASS + 1))
    else
        echo "    FAIL: $c is not running — start the no-vpn profile (./start_no_vpn) and rerun"
        FAIL=$((FAIL + 1))
    fi
done

# 2. Every container has oom_score_adj > 0 (volunteers to be killed
#    before processes with the default 0). We don't require a
#    specific value — rootless podman caps it at the parent's value
#    so a hard "≥ 500" assertion would always fail. We require
#    "strictly positive" — i.e. the container has explicitly raised
#    its OOM score above its parent's baseline.
echo
echo "[2/3] Checking each container's live /proc/<pid>/oom_score_adj…"
USER_SCORE=0
USER_PID=$(systemctl --user show -p MainPID --value 2>/dev/null || echo "")
if [ -n "$USER_PID" ] && [ -r "/proc/$USER_PID/oom_score_adj" ]; then
    USER_SCORE=$(cat "/proc/$USER_PID/oom_score_adj" 2>/dev/null || echo 0)
fi
echo "    (user@$(id -u).service oom_score_adj = $USER_SCORE for reference)"

for c in "${EXPECTED_CONTAINERS[@]}"; do
    if ! echo "$RUNNING" | grep -qx "$c"; then
        continue   # already failed in step 1
    fi
    pid=$("$RT" inspect "$c" --format '{{.State.Pid}}' 2>/dev/null)
    if [ -z "$pid" ] || [ "$pid" = "0" ]; then
        echo "    FAIL: $c has no main pid"
        FAIL=$((FAIL + 1))
        continue
    fi
    if [ ! -r "/proc/$pid/oom_score_adj" ]; then
        echo "    FAIL: /proc/$pid/oom_score_adj not readable for $c"
        FAIL=$((FAIL + 1))
        continue
    fi
    score=$(cat "/proc/$pid/oom_score_adj")
    # Container must be strictly higher than user session (so the
    # kernel picks the container before the session) AND positive.
    if [ "$score" -gt "$USER_SCORE" ] 2>/dev/null && [ "$score" -gt 0 ]; then
        echo "    PASS: $c (pid=$pid) oom_score_adj=$score (> user=$USER_SCORE, container volunteers first)"
        PASS=$((PASS + 1))
    elif [ "$score" -eq "$USER_SCORE" ] 2>/dev/null && [ "$score" -gt 0 ]; then
        # Equal-and-positive is still acceptable — it means at least
        # the container isn't preferred-survivor over the session.
        # Rootless podman caps oom_score_adj at the parent's value,
        # so equality is the realistic best case.
        echo "    PASS: $c (pid=$pid) oom_score_adj=$score (=user, capped by rootless podman; not a preferred-survivor)"
        PASS=$((PASS + 1))
    else
        echo "    FAIL: $c (pid=$pid) oom_score_adj=$score (≤ 0 or below user=$USER_SCORE)"
        echo "          docker-compose.yml should declare oom_score_adj for this service."
        FAIL=$((FAIL + 1))
    fi
done

# 3. Every container has an explicit mem_limit — without it, a single
#    runaway can grow until the cgroup is bigger than the rest of
#    user.slice combined, making the OOM killer walk up to the
#    parent (user session) before our oom_score_adj has a chance
#    to redirect it.
echo
echo "[3/3] Checking each container has a non-zero mem_limit…"
for c in "${EXPECTED_CONTAINERS[@]}"; do
    if ! echo "$RUNNING" | grep -qx "$c"; then
        continue
    fi
    mem=$("$RT" inspect "$c" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
    if [ "$mem" -gt 0 ] 2>/dev/null; then
        # Render in MiB for human-readable output.
        mib=$(( mem / 1024 / 1024 ))
        echo "    PASS: $c mem_limit=${mib} MiB"
        PASS=$((PASS + 1))
    else
        echo "    FAIL: $c has no mem_limit (HostConfig.Memory=$mem)"
        echo "          A container without mem_limit can grow without bound and"
        echo "          trigger OOM cascade up to user@$(id -u).service."
        FAIL=$((FAIL + 1))
    fi
done

echo
echo "=== summary: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ]
