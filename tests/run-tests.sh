#!/bin/bash
#
# YT-DLP Project Test Suite
# Comprehensive automated testing for all scenarios and combinations
#

set -e

# =============================================================================
# Test Configuration
# =============================================================================

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
TEST_RESULTS_DIR="$TEST_DIR/results"
TEST_LOGS_DIR="$TEST_DIR/logs"
TEST_CONFIG_DIR="$TEST_DIR/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_TOTAL=0

# Test modes
DRY_RUN=false
VERBOSE=false
TEST_RUNTIME="auto"
TEST_PROFILE="all"
TEST_SCENARIO="all"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_section() {
    echo ""
    echo -e "${MAGENTA}============================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}============================================${NC}"
    echo ""
}

# Create test directories
setup_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEST_LOGS_DIR"
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p /tmp/test-downloads
    
    # Create test .env files
    cat > "$TEST_CONFIG_DIR/.env.no-vpn" << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/test-downloads
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF

    cat > "$TEST_CONFIG_DIR/.env.with-vpn" << 'EOF'
USE_VPN=true
DOWNLOAD_DIR=/tmp/test-downloads
VPN_USERNAME=testuser
VPN_PASSWORD=testpass
VPN_OVPN_PATH=/tmp/test-vpn/config.ovpn
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=UTC
EOF
    
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
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..."
    
    # Restore original .env if it was backed up
    if [ -f .env.backup ]; then
        mv .env.backup .env
    fi
    
    rm -rf "$TEST_RESULTS_DIR"
    rm -rf "$TEST_LOGS_DIR"
    rm -rf "$TEST_CONFIG_DIR"
    
    # Remove download directory (may contain files owned by container mapped UID)
    if command -v podman &> /dev/null; then
        podman unshare rm -rf /tmp/test-downloads 2>/dev/null || rm -rf /tmp/test-downloads 2>/dev/null || true
    else
        rm -rf /tmp/test-downloads 2>/dev/null || true
    fi
    rm -rf /tmp/test-vpn
    
    # Remove test containers if they exist
    for container in test-yt-dlp test-metube test-openvpn; do
        podman rm -f "$container" 2>/dev/null || true
        docker rm -f "$container" 2>/dev/null || true
    done
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -n "Running: $test_name... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN]${NC}"
        return 0
    fi
    
    # Run the test function
    if $test_func > "$TEST_LOGS_DIR/${test_name}.log" 2>&1; then
        if grep -qE "(platform restriction|geo-restriction|upstream issue|test data stale|requires authentication)" "$TEST_LOGS_DIR/${test_name}.log" 2>/dev/null; then
            local skip_reason
            skip_reason=$(grep -oP '(?<=— ).*$' "$TEST_LOGS_DIR/${test_name}.log" 2>/dev/null | head -1 || echo "known issue")
            echo -e "${YELLOW}SKIP${NC} ($skip_reason)"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        else
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [ "$VERBOSE" = true ]; then
            echo "  Log: $TEST_LOGS_DIR/${test_name}.log"
            cat "$TEST_LOGS_DIR/${test_name}.log" | sed 's/^/    /'
        fi
        return 1
    fi
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    
    echo -e "Running: $test_name... ${YELLOW}SKIPPED${NC} ($reason)"
}

# Assert functions
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if eval "$condition"; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Condition: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if eval "$condition"; then
        echo "ASSERTION FAILED: $message"
        echo "  Condition: $condition"
        return 1
    else
        return 0
    fi
}

assert_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "ASSERTION FAILED: File does not exist: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "ASSERTION FAILED: Directory does not exist: $dir"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "ASSERTION FAILED: Command not found: $cmd"
        return 1
    fi
}

# Container runtime detection for tests
detect_runtime_for_test() {
    case "$TEST_RUNTIME" in
        podman)
            if command -v podman &> /dev/null; then
                echo "podman"
            else
                echo "none"
            fi
            ;;
        docker)
            if command -v docker &> /dev/null; then
                echo "docker"
            else
                echo "none"
            fi
            ;;
        *)
            if command -v podman &> /dev/null; then
                echo "podman"
            elif command -v docker &> /dev/null; then
                echo "docker"
            else
                echo "none"
            fi
            ;;
    esac
}

# Check if containers are running
check_containers_running() {
    local runtime="$1"
    
    if [ "$runtime" = "podman" ]; then
        podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "(metube|yt-dlp-cli)"
    elif [ "$runtime" = "docker" ]; then
        docker ps --format "{{.Names}}" 2>/dev/null | grep -qE "(metube|yt-dlp-cli)"
    else
        return 1
    fi
}

# Start containers for testing
start_test_containers() {
    cd "$PROJECT_DIR"
    
    if [ -f .env ]; then
        log_info "Starting containers for testing..."
        
        # Initialize first
        if ! ./init > "$TEST_LOGS_DIR/container-init.log" 2>&1; then
            log_warn "Failed to initialize, attempting to continue"
        fi
        
        # Start containers
        if ! ./start > "$TEST_LOGS_DIR/container-start.log" 2>&1; then
            log_warn "Failed to start containers, some tests may be skipped"
            return 1
        fi
        
        # Wait for containers to be ready
        log_info "Waiting for containers to be ready..."
        for i in {1..30}; do
            if check_containers_running "$(detect_runtime_for_test)"; then
                log_info "Containers are running"
                return 0
            fi
            sleep 2
        done
        
        log_warn "Containers did not start in time"
        return 1
    else
        log_warn "No .env file found, cannot start containers"
        return 1
    fi
}

# Stop test containers
stop_test_containers() {
    cd "$PROJECT_DIR"
    
    if [ -f ./stop ]; then
        log_info "Stopping test containers..."
        ./stop > "$TEST_LOGS_DIR/container-stop.log" 2>&1 || true
    fi
}

# =============================================================================
# Test Suites
# =============================================================================

# Stub functions for test suites (will be overridden by sourced files)
# Only define if not already defined by sourced test files
run_unit_tests() {
    log_warn "Unit tests not loaded"
}

run_integration_tests() {
    log_warn "Integration tests not loaded"
}

run_scenario_tests() {
    log_warn "Scenario tests not loaded"
}

run_error_tests() {
    log_warn "Error tests not loaded"
}

run_media_services_tests() {
    log_warn "Media services tests not loaded"
}

run_dashboard_tests() {
    log_warn "Dashboard tests not loaded"
}

# Source all test files (these will override the stubs above)
source "$TEST_DIR/test-unit.sh" 2>/dev/null || true
source "$TEST_DIR/test-integration.sh" 2>/dev/null || true
source "$TEST_DIR/test-scenarios.sh" 2>/dev/null || true
source "$TEST_DIR/test-errors.sh" 2>/dev/null || true
source "$TEST_DIR/test-media-services.sh" 2>/dev/null || true
source "$TEST_DIR/test-dashboard.sh" 2>/dev/null || true
source "$TEST_DIR/test-cookie-validator.sh" 2>/dev/null || true

# =============================================================================
# Main Test Runner
# =============================================================================

print_usage() {
    cat << EOF
YT-DLP Test Suite

Usage: $0 [OPTIONS] [TEST_PATTERN]

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show what would be tested without running
    -r, --runtime           Specify runtime: podman, docker, or auto (default: auto)
    -p, --profile           Test profile: all, unit, integration, scenario, error (default: all)
    -s, --scenario          Specific scenario to test (default: all)
    -c, --cleanup           Cleanup test environment and exit
    -l, --list              List all available tests

Examples:
    $0                      Run all tests
    $0 -r podman            Run tests with Podman only
    $0 -r docker            Run tests with Docker only
    $0 -p unit              Run only unit tests
    $0 -p scenario          Run only scenario tests
    $0 -s vpn               Run VPN-related scenarios only
    $0 test_init            Run specific test
    $0 -v                   Run with verbose output
    $0 -d                   Dry run - show what would be tested

EOF
}

list_tests() {
    log_section "Available Tests"
    
    echo "Unit Tests:"
    echo "  - test_container_runtime_detection"
    echo "  - test_compose_command_detection"
    echo "  - test_color_output"
    echo ""
    echo "Integration Tests:"
    echo "  - test_init_no_vpn"
    echo "  - test_init_with_vpn"
    echo "  - test_start_no_vpn"
    echo "  - test_start_with_vpn"
    echo "  - test_stop_services"
    echo "  - test_restart_services"
    echo "  - test_download_helper"
    echo "  - test_update_images"
    echo ""
    echo "Scenario Tests:"
    echo "  - test_scenario_podman_no_vpn"
    echo "  - test_scenario_podman_with_vpn"
    echo "  - test_scenario_docker_no_vpn"
    echo "  - test_scenario_docker_with_vpn"
    echo "  - test_scenario_batch_download"
    echo "  - test_scenario_channel_download"
    echo ""
    echo "Dashboard Tests:"
    echo "  - test_dashboard_container_running"
    echo "  - test_dashboard_homepage_loads"
    echo "  - test_dashboard_spa_fallback"
    echo "  - test_api_proxy_history"
    echo "  - test_api_proxy_add_download"
    echo "  - test_api_proxy_cookie_status"
    echo "  - test_nginx_uses_resolver_directive"
    echo "  - test_nginx_uses_variable_proxy_pass"
    echo "  - test_proxy_works_after_container_restart"
    echo "  - test_landing_page_loads"
    echo "  - test_landing_has_dashboard_link"
    echo "  - test_landing_redirects_to_dashboard"
    echo "  - test_e2e_add_download_via_dashboard"
    echo ""
    echo "Error Tests:"
    echo "  - test_error_no_runtime"
    echo "  - test_error_missing_env"
    echo "  - test_error_invalid_vpn_config"
    echo "  - test_error_port_conflict"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -r|--runtime)
            TEST_RUNTIME="$2"
            shift 2
            ;;
        -p|--profile)
            TEST_PROFILE="$2"
            shift 2
            ;;
        -s|--scenario)
            TEST_SCENARIO="$2"
            shift 2
            ;;
        -c|--cleanup)
            cleanup_test_env
            exit 0
            ;;
        -l|--list)
            list_tests
            exit 0
            ;;
        *)
            # Assume it's a specific test pattern
            TEST_PATTERN="$1"
            shift
            ;;
    esac
done

# Main execution
main() {
    log_section "YT-DLP Test Suite"
    
    # Show configuration
    log_info "Test Configuration:"
    echo "  Runtime: $TEST_RUNTIME"
    echo "  Profile: $TEST_PROFILE"
    echo "  Scenario: $TEST_SCENARIO"
    echo "  Verbose: $VERBOSE"
    echo "  Dry Run: $DRY_RUN"
    echo ""
    
    # Backup existing .env so tests can restore it later
    if [ -f .env ] && [ ! -f .env.backup ]; then
        cp .env .env.backup
    fi
    
    # Setup test environment
    if [ "$DRY_RUN" = false ]; then
        setup_test_env
    fi
    
    # Detect available runtime
    local available_runtime
    available_runtime=$(detect_runtime_for_test)
    
    if [ "$available_runtime" = "none" ]; then
        log_fail "No container runtime available for testing!"
        exit 1
    fi
    
    log_info "Detected runtime: $available_runtime"
    echo ""
    
    # Check if containers are already running
    local containers_already_running=false
    local containers_started_by_test=false
    
    if check_containers_running "$available_runtime"; then
        log_info "Containers already running, will use existing containers"
        containers_already_running=true
    fi
    
    # Run tests based on profile
    case "$TEST_PROFILE" in
        unit)
            log_section "Running Unit Tests"
            run_unit_tests
            if type run_cookie_validator_tests &> /dev/null; then
                log_section "Running Cookie Validator Tests"
                run_cookie_validator_tests
            fi
            ;;
        integration)
            # Start containers if needed
            if [ "$containers_already_running" = false ] && [ "$DRY_RUN" = false ]; then
                if start_test_containers; then
                    containers_started_by_test=true
                fi
            fi
            log_section "Running Integration Tests"
            run_integration_tests
            log_section "Running Dashboard Tests"
            run_dashboard_tests
            log_section "Running Media Services Tests"
            run_media_services_tests
            # Stop containers if we started them
            if [ "$containers_started_by_test" = true ] && [ "$DRY_RUN" = false ]; then
                stop_test_containers
            fi
            ;;
        scenario)
            # Start containers if needed
            if [ "$containers_already_running" = false ] && [ "$DRY_RUN" = false ]; then
                if start_test_containers; then
                    containers_started_by_test=true
                fi
            fi
            log_section "Running Scenario Tests"
            run_scenario_tests
            # Stop containers if we started them
            if [ "$containers_started_by_test" = true ] && [ "$DRY_RUN" = false ]; then
                stop_test_containers
            fi
            ;;
        error)
            log_section "Running Error Tests"
            run_error_tests
            ;;
        all)
            log_section "Running All Tests"
            run_unit_tests
            if type run_cookie_validator_tests &> /dev/null; then
                log_section "Running Cookie Validator Tests"
                run_cookie_validator_tests
            fi

            # Start containers for integration and scenario tests
            if [ "$containers_already_running" = false ] && [ "$DRY_RUN" = false ]; then
                if start_test_containers; then
                    containers_started_by_test=true
                fi
            fi
            
            run_integration_tests
            run_dashboard_tests
            run_media_services_tests
            run_scenario_tests
            run_error_tests
            
            # Stop containers if we started them
            if [ "$containers_started_by_test" = true ] && [ "$DRY_RUN" = false ]; then
                stop_test_containers
            fi
            ;;
        *)
            log_fail "Unknown test profile: $TEST_PROFILE"
            exit 1
            ;;
    esac
    
    # Print summary
    log_section "Test Summary"
    echo -e "Total:   ${TESTS_TOTAL}"
    echo -e "Passed:  ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:  ${RED}${TESTS_FAILED}${NC}"
    echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""
    
    # Cleanup
    if [ "$DRY_RUN" = false ]; then
        cleanup_test_env
    fi
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        log_pass "All tests passed!"
        exit 0
    fi
}

# Run main function
main "$@"
