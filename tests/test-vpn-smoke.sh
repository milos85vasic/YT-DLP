#!/bin/bash
#
# VPN Profile Smoke Tests
# Validates VPN-routed services when USE_VPN is enabled
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
skip() { echo -e "${YELLOW}⚠ SKIP${NC} $1"; }
info() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Container runtime
detect_runtime() {
    if command -v podman &> /dev/null; then echo "podman"; elif command -v docker &> /dev/null; then echo "docker"; else echo "none"; fi
}
RUNTIME=${CONTAINER_RUNTIME:-$(detect_runtime)}
if [ "$RUNTIME" = "none" ]; then
    fail "No container runtime found"
    exit 1
fi

COMPOSE_CMD=$([ "$RUNTIME" = "podman" ] && (command -v podman-compose &> /dev/null && echo "podman-compose" || echo "podman compose") || (command -v docker-compose &> /dev/null && echo "docker-compose" || echo "docker compose"))

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  VPN Profile Smoke Tests${NC}"
echo -e "${CYAN}============================================${NC}"

# ── Pre-checks ──
info "Pre-flight checks"

if [ "${USE_VPN:-false}" != "true" ]; then
    skip "USE_VPN is not true in .env — VPN tests cannot run"
    echo -e "${YELLOW}Set USE_VPN=true and configure VPN_OVPN_PATH to enable${NC}"
    exit 0
fi

if [ -z "${VPN_OVPN_PATH:-}" ] || [ ! -f "$VPN_OVPN_PATH" ]; then
    skip "VPN_OVPN_PATH not set or file missing: ${VPN_OVPN_PATH:-<not set>}"
    exit 0
fi

if [ ! -f "vpn-auth.txt" ]; then
    skip "vpn-auth.txt missing — required for OpenVPN authentication"
    exit 0
fi

pass "VPN configuration present"

# ── Start VPN profile ──
info "Starting VPN profile"
$COMPOSE_CMD --profile vpn up -d

# Wait for VPN to establish
echo "Waiting for VPN tunnel (up to 60s)..."
for ((i=0; i<60; i++)); do
    if $RUNTIME exec openvpn-yt-dlp sh -c 'ping -c 1 8.8.8.8' > /dev/null 2>&1; then
        pass "VPN tunnel established"
        break
    fi
    sleep 1
done

if [ "$i" -eq 60 ]; then
    fail "VPN tunnel failed to establish within 60s"
    $COMPOSE_CMD --profile vpn down
    exit 1
fi

# ── Smoke Tests ──
TESTS_PASSED=0
TESTS_FAILED=0

check() {
    local msg="$1"
    shift
    if "$@"; then
        pass "$msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        fail "$msg"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

info "VPN Smoke Tests"

# 1. VPN container is healthy
check "VPN container is running" \
    $RUNTIME ps --format '{{.Names}}' | grep -q "openvpn-yt-dlp"

# 2. VPN-routed MeTube is accessible
check "VPN-routed MeTube responds" \
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:8081/" | grep -qE "200|301|302"

# 3. VPN landing page responds
check "VPN landing page (8087) responds" \
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:8087/" | grep -q "200"

# 4. VPN-routed MeTube API returns history
check "VPN MeTube API returns history" \
    curl -s --connect-timeout 5 "http://localhost:8081/history" | grep -q "done"

# 5. VPN-routed MeTube API returns version
check "VPN MeTube API returns version" \
    curl -s --connect-timeout 5 "http://localhost:8081/version" | grep -q "version"

# 6. yt-dlp-cli-vpn container is running
check "yt-dlp-cli-vpn container is running" \
    $RUNTIME ps --format '{{.Names}}' | grep -q "yt-dlp-cli-vpn"

# 7. External IP check (optional — may fail if VPN blocks ipinfo)
info "External IP verification (optional)"
VPN_IP=$(curl -s --connect-timeout 5 --max-time 10 "https://ipinfo.io/ip" 2>/dev/null || echo "")
HOST_IP=$(curl -s --connect-timeout 5 --max-time 10 "https://ipinfo.io/ip" 2>/dev/null || echo "")

if [ -n "$VPN_IP" ] && [ -n "$HOST_IP" ]; then
    if [ "$VPN_IP" != "$HOST_IP" ]; then
        pass "External IP differs through VPN ($VPN_IP vs $HOST_IP)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        warn "External IP same as host — VPN may not be routing correctly"
    fi
else
    skip "Could not determine external IP (ipinfo.io blocked or unreachable)"
fi

# ── Cleanup ──
info "Stopping VPN profile"
$COMPOSE_CMD --profile vpn down
pass "VPN profile stopped"

# ── Summary ──
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  VPN Smoke Test Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL VPN SMOKE TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}VPN SMOKE TESTS FAILED${NC}"
    exit 1
fi
