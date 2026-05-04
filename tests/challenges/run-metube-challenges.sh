#!/bin/bash
#
# Run MeTube Challenges - validates that MeTube actually works (anti-bluff)
# Requires: Challenges submodule properly initialized
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Container runtime detection
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

CONTAINER_RUNTIME=$(detect_container_runtime)

if [ "$CONTAINER_RUNTIME" = "none" ]; then
    echo -e "${RED}ERROR: No container runtime found!${NC}"
    exit 1
fi

# Load .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

METUBE_URL="${METUBE_URL:-http://localhost:8088}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
LANDING_URL="${LANDING_URL:-http://localhost:8086}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$PWD/downloads}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MeTube Anti-Bluff Challenge Runner${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Container Runtime:${NC} $CONTAINER_RUNTIME"
echo -e "${CYAN}MeTube URL:${NC} $METUBE_URL"
echo -e "${CYAN}Dashboard URL:${NC} $DASHBOARD_URL"
echo -e "${CYAN}Download Dir:${NC} $DOWNLOAD_DIR"
echo ""

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"
METUBE_RUNNING=$($CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -c "metube" || true)
DASHBOARD_RUNNING=$($CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -c "dashboard" || true)

if [ "$METUBE_RUNNING" -eq 0 ] && [ "$DASHBOARD_RUNNING" -eq 0 ]; then
    echo -e "${RED}ERROR: No MeTube services running!${NC}"
    echo -e "${YELLOW}Start services with: ./start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Services detected${NC}"
echo ""

# Run the Challenges using the Challenges framework
CHALLENGES_DIR="./Challenges"
METUBE_CHALLENGES="./tests/challenges/metube-challenges.json"

if [ ! -d "$CHALLENGES_DIR" ]; then
    echo -e "${RED}ERROR: Challenges directory not found at $CHALLENGES_DIR${NC}"
    exit 1
fi

if [ ! -f "$METUBE_CHALLENGES" ]; then
    echo -e "${RED}ERROR: MeTube challenges file not found at $METUBE_CHALLENGES${NC}"
    exit 1
fi

echo -e "${BLUE}Running MeTube Anti-Bluff Challenges...${NC}"
echo ""

# Set environment variables for challenges
export METUBE_URL="$METUBE_URL"
export DASHBOARD_URL="$DASHBOARD_URL"
export LANDING_URL="$LANDING_URL"
export DOWNLOAD_DIR="$DOWNLOAD_DIR"

# Run challenges using the Challenges framework
cd "$CHALLENGES_DIR"

# Check if Go is available
if ! command -v go &> /dev/null; then
    echo -e "${RED}ERROR: Go is not installed!${NC}"
    echo -e "${YELLOW}Install Go to run the Challenges framework${NC}"
    exit 1
fi

# Build and run challenges
echo -e "${CYAN}Building Challenges runner...${NC}"
go build -o ../tests/challenges/metube-challenge-runner ./cmd/metube-challenge 2>/dev/null || \
go build -o ../tests/challenges/metube-challenge-runner . 2>/dev/null || {
    echo -e "${YELLOW}Building from source...${NC}"
    go build -o ../tests/challenges/metube-challenge-runner
}

cd - > /dev/null

echo -e "${CYAN}Executing challenges...${NC}"
./tests/challenges/metube-challenge-runner \
    --challenges "$METUBE_CHALLENGES" \
    --verbose \
    --report ./tests/results/metube-challenges-report.json \
    --format markdown

RESULT=$?

echo ""
echo -e "${BLUE}========================================${NC}"

if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ All MeTube Challenges PASSED!${NC}"
else
    echo -e "${RED}✗ Some MeTube Challenges FAILED!${NC}"
    echo -e "${YELLOW}Check the report for details.${NC}"
fi

exit $RESULT
