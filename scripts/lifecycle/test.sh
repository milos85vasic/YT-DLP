#!/bin/bash
#
# Comprehensive Testing Script for YT-DLP Container System
# Performs exhaustive live testing with deterministic validation
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

# Test results tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local description="${3:-$test_name}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "Running: $description... "
    
    if eval "$test_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test_verbose() {
    local test_name="$1"
    local test_cmd="$2"
    local description="${3:-$test_name}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "Running: $description... "
    
    if eval "$test_cmd" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Header
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    YT-DLP Comprehensive Test Suite${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Load Environment
# =============================================================================

if [ ! -f "$PROJECT_DIR/.env" ]; then
    log_error ".env file not found in $PROJECT_DIR"
    exit 1
fi

set -a
source "$PROJECT_DIR/.env"
set +a

# Determine container runtime
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_RUNTIME="docker"
else
    log_error "No container runtime found"
    exit 1
fi

log_info "Container Runtime: $CONTAINER_RUNTIME"
log_info "VPN Enabled: ${USE_VPN:-false}"
echo ""

# =============================================================================
# Test Suite 1: Unit Tests
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 1: Unit Tests${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

run_test "unit_container_runtime" "bash -c 'source tests/test-unit.sh; test_container_runtime_detection'" "Container runtime detection"
run_test "unit_compose_cmd" "bash -c 'source tests/test-unit.sh; test_compose_command_detection'" "Compose command detection"
run_test "unit_color_output" "bash -c 'source tests/test-unit.sh; test_color_output'" "Color output"
run_test "unit_env_loading" "bash -c 'source tests/test-unit.sh; test_env_loading'" "Environment loading"
run_test "unit_env_validation" "bash -c 'source tests/test-unit.sh; test_env_variable_validation'" "Environment validation"
run_test "unit_path_validation" "bash -c 'source tests/test-unit.sh; test_path_validation'" "Path validation"
run_test "unit_dir_creation" "bash -c 'source tests/test-unit.sh; test_directory_creation'" "Directory creation"
run_test "unit_file_perms" "bash -c 'source tests/test-unit.sh; test_file_permissions'" "File permissions"
run_test "unit_string_funcs" "bash -c 'source tests/test-unit.sh; test_string_functions'" "String functions"
run_test "unit_vpn_parsing" "bash -c 'source tests/test-unit.sh; test_vpn_config_parsing'" "VPN config parsing"
run_test "unit_vpn_auth" "bash -c 'source tests/test-unit.sh; test_vpn_auth_file_creation'" "VPN auth file creation"
run_test "unit_compose_syntax" "bash -c 'source tests/test-unit.sh; test_docker_compose_syntax'" "Docker compose syntax"
run_test "unit_service_defs" "bash -c 'source tests/test-unit.sh; test_service_definitions'" "Service definitions"
run_test "unit_profile_defs" "bash -c 'source tests/test-unit.sh; test_profile_definitions'" "Profile definitions"
run_test "unit_script_syntax" "bash -c 'source tests/test-unit.sh; test_script_syntax'" "Script syntax"
run_test "unit_port_config" "bash -c 'source tests/test-unit.sh; test_port_configuration'" "Port configuration"
run_test "unit_port_avail" "bash -c 'source tests/test-unit.sh; test_port_availability'" "Port availability"
run_test "unit_file_ownership" "bash -c 'source tests/test-unit.sh; test_file_ownership_utility'" "File ownership utility"
run_test "unit_install_script" "bash -c 'source tests/test-unit.sh; test_installation_script'" "Installation script"
run_test "unit_boot_script" "bash -c 'source tests/test-unit.sh; test_boot_script'" "Boot script"

echo ""

# =============================================================================
# Test Suite 2: Script Syntax Tests
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 2: Script Syntax Validation${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Find all bash scripts and validate syntax
SCRIPTS=(
    "scripts/setup/init"
    "scripts/service/start"
    "scripts/service/stop"
    "scripts/service/status"
    "scripts/service/restart"
    "scripts/service/download"
    "scripts/service/check-vpn"
    "scripts/service/update-images"
    "scripts/service/start-systemd.sh"
    "scripts/service/stop-systemd.sh"
    "scripts/service/status-systemd.sh"
    "scripts/service/restart-systemd.sh"
    "scripts/lifecycle/setup-auto-update"
    "scripts/lifecycle/prepare-release.sh"
    "scripts/lifecycle/install.sh"
    "scripts/lifecycle/boot.sh"
    "scripts/lifecycle/test.sh"
    "scripts/utils/file-ownership.sh"
    "scripts/setup/setup-systemd.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$PROJECT_DIR/$script" ]; then
        run_test "syntax_$(basename "$script" .sh)" "bash -n $PROJECT_DIR/$script" "Syntax check: $script"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo -e "Running: Syntax check: $script... ${YELLOW}SKIP${NC} (not found)"
    fi
done

echo ""

# =============================================================================
# Test Suite 3: Docker Compose Validation
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 3: Docker Compose Validation${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

run_test "compose_syntax" "cd $PROJECT_DIR && $CONTAINER_RUNTIME compose config > /dev/null 2>&1" "Docker compose config validation"
run_test "compose_services" "cd $PROJECT_DIR && $CONTAINER_RUNTIME compose config --services | grep -q 'metube'" "Required services defined"

echo ""

# =============================================================================
# Test Suite 4: Live Service Tests (if services are running)
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 4: Live Service Tests${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if services are running
SERVICES_RUNNING=false

if [ "${USE_VPN:-false}" = "true" ]; then
    # Check VPN mode services
    if curl -sf "http://localhost:8087/health" > /dev/null 2>&1 || curl -sf "http://localhost:8087" > /dev/null 2>&1; then
        SERVICES_RUNNING=true
    fi
else
    # Check no-VPN mode services
    if curl -sf "http://localhost:9090" > /dev/null 2>&1; then
        SERVICES_RUNNING=true
    fi
fi

if [ "$SERVICES_RUNNING" = "true" ]; then
    log_info "Services detected as running - executing live tests"
    echo ""
    
    # Dashboard tests
    run_test "live_dashboard_homepage" "curl -sf 'http://localhost:9090' | grep -q 'YT-DLP'" "Dashboard homepage loads"
    run_test "live_dashboard_api_history" "curl -sf 'http://localhost:9090/api/history' | grep -q '\['" "Dashboard API /history returns array"
    run_test "live_dashboard_api_version" "curl -sf 'http://localhost:9090/api/version' | grep -q 'version'" "Dashboard API /version returns version"
    
    # Landing page tests
    if [ "${USE_VPN:-false}" = "true" ]; then
        run_test "live_landing_vpn" "curl -sf 'http://localhost:8087/health' | grep -q 'healthy'" "Landing page VPN health check"
        run_test "live_landing_cookie_status" "curl -sf 'http://localhost:8087/api/cookie-status' | grep -q 'hasCookies'" "Landing page cookie status API"
    else
        run_test "live_landing_novpn" "curl -sf 'http://localhost:8086/health' | grep -q 'healthy'" "Landing page health check"
        run_test "live_landing_cookie_status" "curl -sf 'http://localhost:8086/api/cookie-status' | grep -q 'hasCookies'" "Landing page cookie status API"
    fi
    
    # MeTube tests
    if [ "${USE_VPN:-false}" = "true" ]; then
        run_test "live_metube_vpn" "curl -sf 'http://localhost:8086/api/version' | grep -q 'version'" "MeTube VPN API version"
    else
        run_test "live_metube_direct" "curl -sf 'http://localhost:8088/api/version' | grep -q 'version'" "MeTube Direct API version"
    fi
    
    # VPN check
    if [ "${USE_VPN:-false}" = "true" ]; then
        run_test "live_vpn_check" "./scripts/service/check-vpn 2>&1 | grep -q 'VPN is working'" "VPN connection check"
    fi
    
    # Download test (if URL provided)
    if [ -n "${TEST_DOWNLOAD_URL:-}" ]; then
        run_test_verbose "live_download" "./scripts/service/download '$TEST_DOWNLOAD_URL' 2>&1 | grep -q 'finished'" "Live download test"
    else
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo -e "Running: Live download test... ${YELLOW}SKIP${NC} (TEST_DOWNLOAD_URL not set)"
    fi
    
else
    log_warning "Services not running - skipping live tests"
    echo "  Start services with ./scripts/service/start or ./scripts/service/start-systemd.sh"
    echo "  Set TEST_DOWNLOAD_URL to enable download testing"
    echo ""
    
    # Count skipped tests
    SKIPPED_LIVE=8
    if [ "${USE_VPN:-false}" = "true" ]; then
        SKIPPED_LIVE=7
    fi
    if [ -n "${TEST_DOWNLOAD_URL:-}" ]; then
        SKIPPED_LIVE=$((SKIPPED_LIVE - 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + SKIPPED_LIVE))
    TESTS_SKIPPED=$((TESTS_SKIPPED + SKIPPED_LIVE))
fi

echo ""

# =============================================================================
# Test Suite 5: File Ownership Tests
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 5: File Ownership Validation${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

run_test "ownership_download_dir" "[ -d \"$DOWNLOAD_DIR\" ] && stat -c '%U' \"$DOWNLOAD_DIR\" | grep -q '$(whoami)'" "Download directory ownership"
run_test "ownership_yt_dlp_config" "[ -d \"$PROJECT_DIR/yt-dlp/config\" ] && stat -c '%U' \"$PROJECT_DIR/yt-dlp/config\" | grep -q '$(whoami)'" "yt-dlp config directory ownership"
run_test "ownership_metube_config" "[ -d \"$PROJECT_DIR/metube/config\" ] && stat -c '%U' \"$PROJECT_DIR/metube/config\" | grep -q '$(whoami)'" "Metube config directory ownership"
run_test "ownership_vpn_auth" "[ ! -f \"$PROJECT_DIR/vpn-auth.txt\" ] || stat -c '%U' \"$PROJECT_DIR/vpn-auth.txt\" | grep -q '$(whoami)'" "VPN auth file ownership"

echo ""

# =============================================================================
# Test Suite 6: Security Tests
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Suite 6: Security Validation${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

run_test "security_vpn_auth_perms" "[ ! -f \"$PROJECT_DIR/vpn-auth.txt\" ] || [ \"$(stat -c '%a' \"$PROJECT_DIR/vpn-auth.txt\")\" = \"600\" ]" "VPN auth file permissions (600)"
run_test "security_env_not_committed" "! git ls-files --error-unmatch .env > /dev/null 2>&1" ".env not committed to git"
run_test "security_no_secrets_in_scripts" "! grep -r 'PASSWORD.*=' scripts/ --include='*.sh' | grep -v 'VPN_PASSWORD' | grep -v '^#' | grep -q ." "No hardcoded passwords in scripts"

echo ""

# =============================================================================
# Summary
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Total Tests:    $TESTS_TOTAL"
echo -e "${GREEN}Passed:         $TESTS_PASSED${NC}"
echo -e "${RED}Failed:         $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped:        $TESTS_SKIPPED${NC}"
echo ""

# Calculate pass rate
if [ $TESTS_TOTAL -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / (TESTS_TOTAL - TESTS_SKIPPED)))
    echo -e "Pass Rate:      ${PASS_RATE}%"
    echo ""
fi

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "$TESTS_FAILED test(s) failed"
    exit 1
fi

