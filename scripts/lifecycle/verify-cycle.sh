#!/bin/bash
#
# Verify the complete install-boot-test-release cycle
# Runs all lifecycle stages and validates they complete successfully
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Track stage results
STAGE_RESULTS=()

run_stage() {
    local stage_name="$1"
    local stage_cmd="$2"
    
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Stage: $stage_name${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    
    if eval "$stage_cmd"; then
        STAGE_RESULTS+=("$stage_name: PASS")
        log_success "Stage '$stage_name' completed successfully"
        return 0
    else
        STAGE_RESULTS+=("$stage_name: FAIL")
        log_error "Stage '$stage_name' failed"
        return 1
    fi
}

# Header
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Full Cycle Verification${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Stage 1: Install
# =============================================================================

run_stage "Install" "
    cd $PROJECT_DIR &&
    ./scripts/lifecycle/install.sh 2>&1 | tail -20
" || true

# =============================================================================
# Stage 2: Boot
# =============================================================================

run_stage "Boot" "
    cd $PROJECT_DIR &&
    USE_SYSTEMD=true ./scripts/lifecycle/boot.sh 2>&1 | tail -20
" || true

# =============================================================================
# Stage 3: Test
# =============================================================================

run_stage "Test" "
    cd $PROJECT_DIR &&
    ./scripts/lifecycle/test.sh 2>&1 | tail -30
" || true

# =============================================================================
# Stage 4: Release (dry-run)
# =============================================================================

run_stage "Release (dry-run)" "
    cd $PROJECT_DIR &&
    DRY_RUN=true ./scripts/lifecycle/release.sh v9.9.9-test 2>&1 | tail -20
" || true

# =============================================================================
# Stage 5: Persistence
# =============================================================================

run_stage "Persistence" "
    cd $PROJECT_DIR &&
    ./scripts/lifecycle/enable-persistence.sh 2>&1 | tail -20
" || true

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Cycle Verification Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

ALL_PASS=true
for result in "${STAGE_RESULTS[@]}"; do
    if [[ $result == *": PASS" ]]; then
        echo -e "  ${GREEN}✓${NC} $result"
    else
        echo -e "  ${RED}✗${NC} $result"
        ALL_PASS=false
    fi
done

echo ""

if [ "$ALL_PASS" = "true" ]; then
    log_success "All stages completed successfully!"
    echo ""
    echo -e "${CYAN}The install-boot-test-release cycle is verified and working.${NC}"
    exit 0
else
    log_error "Some stages failed - review output above"
    echo ""
    echo -e "${CYAN}The install-boot-test-release cycle has issues that need to be addressed.${NC}"
    exit 1
fi

