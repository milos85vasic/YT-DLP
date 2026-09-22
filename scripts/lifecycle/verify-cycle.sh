#!/bin/bash
#
# Verify the complete install-boot-test-release cycle
# Runs all lifecycle stages and validates they complete successfully
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When invoked from project root, PROJECT_DIR is the current directory
PROJECT_DIR="$PWD"

# Load environment for variable access
if [ -f "$PROJECT_DIR/.env" ]; then
    . "$PROJECT_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found at $PROJECT_DIR/.env${NC}"
    exit 1
fi

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

# Service list expected to be active after boot
EXPECTED_SERVICES=(
    metube.service
    metube-direct.service
    landing-vpn.service
    landing-no-vpn.service
    dashboard.service
    yt-dlp-cli.service
    yt-dlp-cli-vpn.service
    openvpn-yt-dlp.service
    watchtower.service
    media-postprocessor.service
)

run_stage() {
    local stage_name="$1"
    local stage_cmd="$2"
    local validate_cmd="$3"  # optional validation command to run after stage
    
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Stage: $stage_name${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    
    # Capture both stdout and stderr so we can inspect it later
    STAGE_OUTPUT=$(eval "$stage_cmd" 2>&1)
    STAGE_EXIT_CODE=$?
    echo "STAGE_EXIT_CODE=$STAGE_EXIT_CODE"
    
    # Echo tail of output for progress
    echo "$STAGE_OUTPUT" | tail -20
    
    # Default: stage passes if command succeeded
    local stage_passed=true
    
    # Run optional validation if provided
    if [ -n "$validate_cmd" ]; then
        if ! eval "$validate_cmd"; then
            stage_passed=false
            log_error "Validation failed for stage '$stage_name'"
        fi
    fi
    
    # Override with command exit code if validation didn't explicitly fail
    if [ $STAGE_EXIT_CODE -ne 0 ] && [ "$stage_passed" = true ]; then
        stage_passed=false
        log_error "Stage command failed with exit code $STAGE_EXIT_CODE"
    fi
    
    if [ "$stage_passed" = true ]; then
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
    # Ensure download directory exists to avoid interactive prompt in init.sh
    mkdir -p \"$DOWNLOAD_DIR\" &&
    cd $PROJECT_DIR &&
    AUTO_INSTALL=1 ./scripts/lifecycle/install.sh
"

# =============================================================================
# Stage 2: Boot
# =============================================================================

run_stage "Boot" "
    cd $PROJECT_DIR &&
    USE_SYSTEMD=true ./scripts/lifecycle/boot.sh
" "
    # Validation: all expected services must be active
    cd $PROJECT_DIR &&
    all_active=true
    for service in \"${EXPECTED_SERVICES[@]}\"; do
        if ! systemctl --user is-active --quiet \"$service\"; then
            echo \"Service $service is not active\"
            all_active=false
        fi
    done
    if [ \"$all_active\" = true ]; then
        true  # validation passes
    else
        false  # validation fails
    fi
"

# =============================================================================
# Stage 3: Test
# =============================================================================

run_stage "Test" "
    cd $PROJECT_DIR &&
    ./scripts/lifecycle/test.sh
" "
    # Validation: no test should FAIL in the output
    cd $PROJECT_DIR &&
    ! grep -q '\\[0;31mFAIL\\[0m' <<< \"$STAGE_OUTPUT\"
"

# =============================================================================
# Stage 4: Release (dry-run)
# =============================================================================

run_stage "Release (dry-run)" "
    cd $PROJECT_DIR &&
    DRY_RUN=true ./scripts/lifecycle/release.sh v9.9.9-test
"

# =============================================================================
# Stage 5: Persistence
# =============================================================================

run_stage "Persistence" "
    cd $PROJECT_DIR &&
    ./scripts/lifecycle/enable-persistence.sh
"

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
