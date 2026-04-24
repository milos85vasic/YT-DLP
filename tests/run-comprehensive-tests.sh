#!/bin/bash
#
# Comprehensive Test Execution with Full Setup
# This script ensures proper test environment before running tests
#

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   YT-DLP Comprehensive Test Execution${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Pre-test Setup
# =============================================================================

echo -e "${BLUE}Step 1: Setting up test environment...${NC}"

# Create required directories
mkdir -p /tmp/test-downloads
mkdir -p tests/logs
mkdir -p tests/results

# Create test .env if it doesn't exist
ENV_CREATED_BY_TEST=false
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating test .env file...${NC}"
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/test-downloads
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF
    ENV_CREATED_BY_TEST=true
fi

# Ensure test config directory exists
mkdir -p tests/config

# Create test config files if they don't exist
if [ ! -f tests/config/.env.no-vpn ]; then
    cat > tests/config/.env.no-vpn << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/test-downloads
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF
fi

if [ ! -f tests/config/.env.with-vpn ]; then
    cat > tests/config/.env.with-vpn << 'EOF'
USE_VPN=true
DOWNLOAD_DIR=/tmp/test-downloads
VPN_USERNAME=testuser
VPN_PASSWORD=testpass
VPN_OVPN_PATH=/tmp/test-vpn/config.ovpn
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF
fi

# Create test VPN config
mkdir -p /tmp/test-vpn
cat > /tmp/test-vpn/config.ovpn << 'EOF'
client
dev tun
proto udp
remote vpn.example.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass /vpn/vpn.auth
EOF

echo -e "${GREEN}✓${NC} Test environment configured"

# =============================================================================
# Run All Tests
# =============================================================================

echo ""
echo -e "${BLUE}Step 2: Executing full test suite...${NC}"
echo ""

# Run the complete test suite
TEST_START_TIME=$(date +%s)

if ./tests/run-tests.sh "$@"; then
    TEST_EXIT_CODE=0
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  All Tests Passed Successfully!${NC}"
    echo -e "${GREEN}============================================${NC}"
else
    TEST_EXIT_CODE=1
    echo ""
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  Some Tests Failed${NC}"
    echo -e "${RED}============================================${NC}"
fi

TEST_END_TIME=$(date +%s)
TEST_DURATION=$((TEST_END_TIME - TEST_START_TIME))

echo ""
echo -e "${BLUE}Test Execution Summary:${NC}"
echo "  Duration: ${TEST_DURATION} seconds"
echo "  Logs: tests/logs/"
echo "  Results: tests/results/"

# =============================================================================
# Post-test Cleanup
# =============================================================================

echo ""
echo -e "${BLUE}Step 3: Cleaning up...${NC}"

# Remove test .env only if we created it
if [ "$ENV_CREATED_BY_TEST" = true ] && [ -f .env ]; then
    rm -f .env
    echo -e "${GREEN}✓${NC} Removed test .env"
fi

# Clean up test VPN auth file
rm -f vpn-auth.txt 2>/dev/null || true

# Clean up test directories (optional - keep for debugging if tests failed)
if [ $TEST_EXIT_CODE -eq 0 ]; then
    if command -v podman &> /dev/null; then
        podman unshare rm -rf /tmp/test-downloads 2>/dev/null || rm -rf /tmp/test-downloads 2>/dev/null || true
    else
        rm -rf /tmp/test-downloads 2>/dev/null || true
    fi
    rm -rf /tmp/test-vpn
    echo -e "${GREEN}✓${NC} Cleaned up temporary directories"
else
    echo -e "${YELLOW}⚠${NC} Keeping temporary directories for debugging (tests failed)"
fi

echo ""
echo -e "${BLUE}============================================${NC}"

exit $TEST_EXIT_CODE
