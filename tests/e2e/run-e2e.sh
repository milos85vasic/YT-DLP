#!/bin/bash
#
# Browser E2E test runner using Playwright
# Tests against real running services (landing, dashboard, metube)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
info() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}ERROR: Node.js is required${NC}"
    exit 1
fi

# Check services
info "Checking services"
for url in "http://localhost:8086" "http://localhost:8088" "http://localhost:9090"; do
    if ! curl -s -o /dev/null --connect-timeout 2 "$url"; then
        echo -e "${RED}ERROR: $url is not reachable${NC}"
        echo -e "${YELLOW}Run ./start_no_vpn first${NC}"
        exit 1
    fi
done
pass "All services reachable"

# Install deps if needed
if [ ! -d "node_modules" ]; then
    info "Installing dependencies"
    npm install
fi

# Install browsers if needed
if [ ! -d "$HOME/.cache/ms-playwright" ] && [ ! -d "$HOME/Library/Caches/ms-playwright" ]; then
    info "Installing Playwright browsers"
    npx playwright install chromium
fi

# Run tests
info "Running Playwright E2E tests"
npx playwright test "$@"

info "E2E tests complete"
