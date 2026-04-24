#!/bin/bash
#
# dev-check.sh — Pre-push validation gate
# Run this before every commit/push to catch issues locally.
# This is the developer's equivalent of CI.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

FAILED=0
PASSED=0

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)) || true; }
fail() { echo -e "${RED}✗${NC} $1"; ((FAILED++)) || true; }
info() { echo -e "${CYAN}▶${NC} $1"; }

# ── Gate 0: Shell script syntax ──────────────────────────────────────
info "Gate 0: Shell script syntax"
for script in init start stop restart download cleanup status check-vpn update-images setup-auto-update start_no_vpn prepare-release.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            pass "$script syntax OK"
        else
            fail "$script has syntax errors"
        fi
    fi
done

for script in tests/*.sh scripts/*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            pass "$(basename "$script") syntax OK"
        else
            fail "$(basename "$script") has syntax errors"
        fi
    fi
done

# ── Gate 1: Python syntax ────────────────────────────────────────────
info "Gate 1: Python syntax"
if python3 -m py_compile landing/app.py 2>/dev/null; then
    pass "landing/app.py syntax OK"
else
    fail "landing/app.py has syntax errors"
fi

# ── Gate 2: Docker Compose validation ────────────────────────────────
info "Gate 2: Docker Compose validation"
if [ ! -f .env ]; then
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/test-downloads
PUID=1001
PGID=1001
VPN_OVPN_PATH=/tmp/test-vpn/config.ovpn
EOF
    ENV_CREATED=1
fi

# Create required directories for compose validation
mkdir -p /tmp/test-downloads
mkdir -p /tmp/test-vpn
touch /tmp/test-vpn/config.ovpn

if docker compose config > /dev/null 2>&1 || docker-compose config > /dev/null 2>&1 || podman-compose config > /dev/null 2>&1; then
    pass "Compose config valid"
else
    fail "Compose config invalid"
fi

if [ "${ENV_CREATED:-0}" = "1" ] && [ -f .env ]; then
    rm -f .env
fi

# ── Gate 3: Dashboard build ──────────────────────────────────────────
info "Gate 3: Dashboard build"
if [ -d dashboard/node_modules ]; then
    if (cd dashboard && npx ng build --configuration production > /dev/null 2>&1); then
        pass "Dashboard builds successfully"
    else
        fail "Dashboard build failed"
    fi
else
    log_warn "Dashboard node_modules missing — skipping build check"
fi

# ── Gate 4: Smoke tests (if containers running) ──────────────────────
info "Gate 4: Smoke tests"
if curl -s --max-time 2 http://localhost:9090/ > /dev/null 2>&1; then
    if ./scripts/smoke-test.sh > /tmp/smoke.log 2>&1; then
        pass "Smoke tests passed"
    else
        fail "Smoke tests failed (see /tmp/smoke.log)"
    fi
else
    echo -e "${YELLOW}  ⚠ Containers not running — smoke tests skipped${NC}"
    echo -e "${YELLOW}    Run: ./start_no_vpn && ./scripts/smoke-test.sh${NC}"
fi

# ── Gate 5: Test audit ───────────────────────────────────────────────
info "Gate 5: Test suite audit"
if ./scripts/test-audit.sh > /tmp/audit.log 2>&1; then
    SCORE=$(grep "Audit Score:" /tmp/audit.log | grep -o '[0-9]\+/[0-9]\+' | cut -d'/' -f1)
    if [ "${SCORE:-0}" -ge 60 ]; then
        pass "Test audit score: ${SCORE}/70"
    else
        fail "Test audit score too low: ${SCORE}/70 (need ≥ 60)"
    fi
else
    fail "Test audit failed"
fi

# ── Gate 6: Git status check ─────────────────────────────────────────
info "Gate 6: Git hygiene"
if git diff --cached --quiet; then
    if git diff --quiet; then
        pass "Working tree clean"
    else
        echo -e "${YELLOW}  ⚠ Unstaged changes present — did you forget 'git add'?${NC}"
    fi
else
    pass "Staged changes ready to commit"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  dev-check Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL CHECKS PASSED — Safe to commit/push${NC}"
    exit 0
else
    echo -e "${RED}CHECKS FAILED — Fix before pushing${NC}"
    exit 1
fi
