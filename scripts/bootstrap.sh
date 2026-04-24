#!/bin/bash
#
# Bootstrap a new development environment
# Run this once after cloning the repository.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  YT-DLP Development Environment Bootstrap${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ── Check prerequisites ──────────────────────────────────────────────
echo -e "${BLUE}Checking prerequisites...${NC}"

MISSING=0

if command -v podman &> /dev/null; then
    echo -e "${GREEN}✓${NC} Podman found: $(podman --version)"
elif command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker found: $(docker --version)"
else
    echo -e "${RED}✗${NC} Neither Podman nor Docker found. Install one to continue."
    MISSING=1
fi

if command -v curl &> /dev/null; then
    echo -e "${GREEN}✓${NC} curl found"
else
    echo -e "${RED}✗${NC} curl not found"
    MISSING=1
fi

if command -v node &> /dev/null; then
    echo -e "${GREEN}✓${NC} Node.js found: $(node --version)"
else
    echo -e "${YELLOW}⚠${NC} Node.js not found — needed for dashboard development"
fi

if [ "$MISSING" -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing prerequisites. Please install them and re-run.${NC}"
    exit 1
fi

# ── Initialize environment ───────────────────────────────────────────
echo ""
echo -e "${BLUE}Initializing environment...${NC}"

if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✓${NC} Created .env from template — please edit it with your settings"
else
    echo -e "${GREEN}✓${NC} .env already exists"
fi

./init

# ── Install git hooks ────────────────────────────────────────────────
echo ""
echo -e "${BLUE}Installing git hooks...${NC}"
if [ -f scripts/install-hooks.sh ]; then
    ./scripts/install-hooks.sh
else
    echo -e "${YELLOW}⚠${NC} install-hooks.sh not found"
fi

# ── Install dashboard dependencies ───────────────────────────────────
echo ""
echo -e "${BLUE}Installing dashboard dependencies...${NC}"
if [ -d dashboard ] && [ -f dashboard/package.json ]; then
    if [ ! -d dashboard/node_modules ]; then
        (cd dashboard && npm ci --legacy-peer-deps)
        echo -e "${GREEN}✓${NC} Dashboard dependencies installed"
    else
        echo -e "${GREEN}✓${NC} Dashboard dependencies already installed"
    fi
else
    echo -e "${YELLOW}⚠${NC} Dashboard not found"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}  Bootstrap complete!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your settings (DOWNLOAD_DIR, VPN config, etc.)"
echo "  2. Start services: ./start_no_vpn"
echo "  3. Open dashboard: http://localhost:9090"
echo "  4. Run smoke tests: make smoke"
echo "  5. Before every push: make dev-check"
echo ""
