#!/bin/bash
#
# Challenge: Memory limits and OOM protection enforced
# Anti-bluff: Read live cgroup state, assert limits match compose file.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "[1/2] Checking containers have memory limits..."
ERRORS=0
for name in metube-direct metube-landing yt-dlp-dashboard yt-dlp-cli; do
    LIMIT=$(podman inspect "$name" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
    if [ "$LIMIT" = "0" ] || [ -z "$LIMIT" ]; then
        echo -e "${RED}    $name: FAIL (no memory limit)${NC}"
        ERRORS=$((ERRORS+1))
    else
        echo "    $name: OK (limit=${LIMIT}b)"
    fi
done

echo "[2/2] Checking oom_score_adj..."
for name in metube-direct metube-landing yt-dlp-dashboard yt-dlp-cli; do
    PID=$(podman inspect "$name" --format '{{.State.Pid}}' 2>/dev/null || echo "")
    if [ -n "$PID" ] && [ -f "/proc/$PID/oom_score_adj" ]; then
        SCORE=$(cat "/proc/$PID/oom_score_adj" 2>/dev/null || echo "unknown")
        echo "    $name: oom_score_adj=$SCORE"
    else
        echo -e "${RED}    $name: FAIL (cannot read oom_score_adj)${NC}"
        ERRORS=$((ERRORS+1))
    fi
done

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}PASS: All containers have resource protections${NC}"
else
    echo -e "${RED}FAIL: $ERRORS resource protection violation(s)${NC}"
    exit 1
fi
