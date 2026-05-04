#!/bin/bash
#
# Run ALL MeTube challenges in sequence
# Usage: ./challenges/scripts/run_all_challenges.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}       MeTube Challenge Runner${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_footer() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}   ALL CHALLENGES PASSED ($PASS/$PASS)${NC}"
    else
        echo -e "${RED}   CHALLENGES FAILED: $FAIL / $((PASS + FAIL))${NC}"
    fi
    echo -e "${BLUE}============================================${NC}"
}

run_challenge() {
    local script="$1"
    local name="$(basename "$script" .sh)"
    echo -e "${CYAN}[RUN]${NC} $name"
    if bash "$script" > /tmp/challenge_"$name".log 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} $name"
        echo -e "${YELLOW}      Log: /tmp/challenge_${name}.log${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# Ensure containers are running
if ! command -v podman &> /dev/null || ! podman ps | grep -q metube-direct; then
    echo -e "${YELLOW}Containers not running — starting them...${NC}"
    "$PROJECT_ROOT/start"
fi

print_header

# Run all challenge scripts in sorted order
for script in "$SCRIPT_DIR"/*.sh; do
    [ -f "$script" ] || continue
    # Skip the runner itself
    [[ "$(basename "$script")" == "run_all_challenges.sh" ]] && continue
    run_challenge "$script"
done

print_footer

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
