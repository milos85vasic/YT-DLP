#!/bin/bash
#
# Full test suite execution with container lifecycle management
# Starts containers, runs all tests, then shuts down
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  YT-DLP Full Test Suite with Containers${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Parse arguments
TEST_PROFILE="all"
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            TEST_PROFILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# =============================================================================
# Pre-Test Setup
# =============================================================================

echo -e "${BLUE}Step 1: Setting up test environment...${NC}"
cd "$PROJECT_DIR"

# Create test .env if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating test .env file...${NC}"
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/test-downloads
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF
fi

# Initialize environment
echo -e "${BLUE}Step 2: Initializing environment...${NC}"
./init > /dev/null 2>&1 || {
    echo -e "${RED}Failed to initialize environment${NC}"
    exit 1
}

# =============================================================================
# Start Containers
# =============================================================================

echo -e "${BLUE}Step 3: Starting containers for testing...${NC}"

# Check if containers are already running
if ./status 2>/dev/null | grep -q "running"; then
    echo -e "${YELLOW}Containers already running, skipping start${NC}"
else
    ./start > /dev/null 2>&1 &
    START_PID=$!
    
    # Wait for containers to be ready
    echo -e "${YELLOW}Waiting for containers to start...${NC}"
    for i in {1..30}; do
        if ./status 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}✓ Containers are running${NC}"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
    
    # Verify containers started
    if ! ./status 2>/dev/null | grep -q "running"; then
        echo -e "${RED}Failed to start containers${NC}"
        echo "Check logs with: ./status"
        exit 1
    fi
fi

# =============================================================================
# Run Tests
# =============================================================================

echo ""
echo -e "${BLUE}Step 4: Running test suite...${NC}"
echo ""

# Run the test suite
TEST_EXIT_CODE=0
if ! "$SCRIPT_DIR/run-tests.sh" -p "$TEST_PROFILE" $VERBOSE; then
    TEST_EXIT_CODE=1
fi

# =============================================================================
# Post-Test Cleanup
# =============================================================================

echo ""
echo -e "${BLUE}Step 5: Shutting down containers...${NC}"
./stop > /dev/null 2>&1 || true

# Verify containers are stopped
for i in {1..10}; do
    if ! ./status 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✓ All containers stopped${NC}"
        break
    fi
    sleep 1
done

echo ""
echo -e "${BLUE}============================================${NC}"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}  Test Suite Completed Successfully${NC}"
    echo -e "${BLUE}============================================${NC}"
    exit 0
else
    echo -e "${RED}  Test Suite Failed${NC}"
    echo -e "${BLUE}============================================${NC}"
    exit 1
fi
