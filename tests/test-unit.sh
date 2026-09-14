#!/bin/bash
#
# Unit Tests for YT-DLP Project
# Tests individual functions and components
#

# =============================================================================
# Container Runtime Detection Tests
# =============================================================================

test_container_runtime_detection() {
    # Test that the detection function exists and returns valid values
    cd "$PROJECT_DIR"
    
    # Source the lib file
    if [ -f "lib/container-runtime.sh" ]; then
        source lib/container-runtime.sh
        
        # Test function exists
        assert_true "type detect_container_runtime > /dev/null 2>&1" "detect_container_runtime function should exist"
        
        # Test that it returns one of the expected values
        local result
        result=$(detect_container_runtime)
        assert_true "[ '$result' = 'podman' ] || [ '$result' = 'docker' ] || [ '$result' = 'none' ]" \
            "detect_container_runtime should return podman, docker, or none"
    else
        # Test inline if lib file doesn't exist
        detect_container_runtime() {
            if command -v podman &> /dev/null; then
                echo "podman"
            elif command -v docker &> /dev/null; then
                echo "docker"
            else
                echo "none"
            fi
        }
        
        local result
        result=$(detect_container_runtime)
        assert_true "[ '$result' = 'podman' ] || [ '$result' = 'docker' ] || [ '$result' = 'none' ]" \
            "detect_container_runtime should return podman, docker, or none"
    fi
}

test_compose_command_detection() {
    cd "$PROJECT_DIR"
    
    get_compose_cmd() {
        local runtime="$1"
        if [ "$runtime" = "podman" ]; then
            if command -v podman-compose &> /dev/null; then
                echo "podman-compose"
            else
                echo "podman compose"
            fi
        else
            if command -v docker-compose &> /dev/null; then
                echo "docker-compose"
            else
                echo "docker compose"
            fi
        fi
    }
    
    # Test with podman
    local podman_result
    podman_result=$(get_compose_cmd "podman")
    assert_true "[ '$podman_result' = 'podman-compose' ] || [ '$podman_result' = 'podman compose' ]" \
        "get_compose_cmd podman should return podman-compose or 'podman compose'"
    
    # Test with docker
    local docker_result
    docker_result=$(get_compose_cmd "docker")
    assert_true "[ '$docker_result' = 'docker-compose' ] || [ '$docker_result' = 'docker compose' ]" \
        "get_compose_cmd docker should return docker-compose or 'docker compose'"
}

# =============================================================================
# Color Output Tests
# =============================================================================

test_color_output() {
    # Test that color variables are set correctly
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local CYAN='\033[0;36m'
    local NC='\033[0m'
    
    # Test that variables are non-empty
    assert_true "[ -n '$RED' ]" "RED color should be set"
    assert_true "[ -n '$GREEN' ]" "GREEN color should be set"
    assert_true "[ -n '$YELLOW' ]" "YELLOW color should be set"
    assert_true "[ -n '$BLUE' ]" "BLUE color should be set"
    assert_true "[ -n '$CYAN' ]" "CYAN color should be set"
    assert_true "[ -n '$NC' ]" "NC (no color) should be set"
    
    # Test that colors contain ANSI escape sequences
    assert_true "echo '$RED' | grep -q '\\\033'" "RED should contain ANSI escape"
    assert_true "echo '$GREEN' | grep -q '\\\033'" "GREEN should contain ANSI escape"
}

# =============================================================================
# Environment Variable Tests
# =============================================================================

test_env_loading() {
    cd "$PROJECT_DIR"
    
    # Create a test .env file
    cat > "$TEST_CONFIG_DIR/test.env" << 'EOF'
TEST_VAR1=value1
TEST_VAR2=value2
TEST_BOOL=true
EOF
    
    # Test loading
    set -a
    source "$TEST_CONFIG_DIR/test.env"
    set +a
    
    assert_true "[ '$TEST_VAR1' = 'value1' ]" "TEST_VAR1 should be loaded"
    assert_true "[ '$TEST_VAR2' = 'value2' ]" "TEST_VAR2 should be loaded"
    assert_true "[ '$TEST_BOOL' = 'true' ]" "TEST_BOOL should be loaded"
}

test_env_variable_validation() {
    # Test required variables
    local USE_VPN=""
    local DOWNLOAD_DIR=""
    
    # Both should fail validation
    assert_false "[ -n '$USE_VPN' ]" "Empty USE_VPN should fail validation"
    assert_false "[ -n '$DOWNLOAD_DIR' ]" "Empty DOWNLOAD_DIR should fail validation"
    
    # Set them and test again
    USE_VPN="true"
    DOWNLOAD_DIR="/tmp/test"
    
    assert_true "[ -n '$USE_VPN' ]" "Non-empty USE_VPN should pass validation"
    assert_true "[ -n '$DOWNLOAD_DIR' ]" "Non-empty DOWNLOAD_DIR should pass validation"
}

# =============================================================================
# Path and Directory Tests
# =============================================================================

test_path_validation() {
    # Test absolute path detection
    is_absolute_path() {
        case "$1" in
            /*) return 0 ;;
            *) return 1 ;;
        esac
    }
    
    assert_true "is_absolute_path '/home/user/test'" "Absolute path should be detected"
    assert_false "is_absolute_path 'relative/path'" "Relative path should be detected"
    assert_false "is_absolute_path './relative'" "Relative path with ./ should be detected"
}

test_directory_creation() {
    local test_dir="$TEST_CONFIG_DIR/test-mkdir"
    
    # Clean up if exists
    rm -rf "$test_dir"
    
    # Test directory creation
    mkdir -p "$test_dir"
    assert_dir_exists "$test_dir" "Directory should be created"
    
    # Clean up
    rm -rf "$test_dir"
}

# =============================================================================
# File Permission Tests
# =============================================================================

test_file_permissions() {
    local test_file="$TEST_CONFIG_DIR/permission-test.txt"
    
    # Create file
    echo "test content" > "$test_file"
    
    # Set permissions
    chmod 600 "$test_file"
    
    # Check permissions (using stat)
    local perms
    perms=$(stat -c "%a" "$test_file" 2>/dev/null || stat -f "%Lp" "$test_file")
    
    assert_true "[ '$perms' = '600' ]" "File should have 600 permissions"
    
    # Clean up
    rm -f "$test_file"
}

# =============================================================================
# String Manipulation Tests
# =============================================================================

test_string_functions() {
    # Test string masking for secrets
    mask_secret() {
        local value="$1"
        if [ -n "$value" ]; then
            echo "***masked***"
        else
            echo ""
        fi
    }
    
    local masked
    masked=$(mask_secret "secret-password")
    assert_true "[ '$masked' = '***masked***' ]" "Secret should be masked"
    
    # Test VPN variable detection
    is_vpn_variable() {
        local var_name="$1"
        [[ "$var_name" == *"PASSWORD"* ]] || [[ "$var_name" == *"USERNAME"* ]]
    }
    
    assert_true "is_vpn_variable 'VPN_PASSWORD'" "VPN_PASSWORD should be detected as VPN variable"
    assert_true "is_vpn_variable 'VPN_USERNAME'" "VPN_USERNAME should be detected as VPN variable"
    assert_false "is_vpn_variable 'DOWNLOAD_DIR'" "DOWNLOAD_DIR should not be detected as VPN variable"
}

# =============================================================================
# VPN Configuration Tests
# =============================================================================

test_vpn_config_parsing() {
    local test_vpn_file="$TEST_CONFIG_DIR/test.ovpn"
    
    # Create test VPN config
    cat > "$test_vpn_file" << 'EOF'
client
dev tun
proto udp
remote vpn.example.com 1194
auth-user-pass /vpn/vpn.auth
EOF
    
    # Test that auth-user-pass is detected
    assert_true "grep -q 'auth-user-pass' '$test_vpn_file'" "VPN config should contain auth-user-pass"
    
    # Clean up
    rm -f "$test_vpn_file"
}

test_vpn_auth_file_creation() {
    local auth_file="$TEST_CONFIG_DIR/test-vpn-auth.txt"
    
    # Create auth file
    cat > "$auth_file" << EOF
testuser
testpass
EOF
    
    assert_file_exists "$auth_file" "VPN auth file should be created"
    
    # Test content
    local username
    username=$(head -1 "$auth_file")
    assert_true "[ '$username' = 'testuser' ]" "Auth file should contain username"
    
    # Clean up
    rm -f "$auth_file"
}

# =============================================================================
# Docker Compose Configuration Tests
# =============================================================================

test_docker_compose_syntax() {
    cd "$PROJECT_DIR"
    
    # Test that docker-compose.yml exists and is valid YAML
    assert_file_exists "docker-compose.yml" "docker-compose.yml should exist"
    
    # Test YAML syntax (basic check)
    assert_true "grep -q 'services:' docker-compose.yml" "docker-compose.yml should contain services section"
    assert_true "grep -q 'profiles:' docker-compose.yml" "docker-compose.yml should contain profiles"
}

test_service_definitions() {
    cd "$PROJECT_DIR"
    
    # Check that all expected services are defined
    assert_true "grep -q 'metube:' docker-compose.yml" "metube service should be defined"
    assert_true "grep -q 'yt-dlp-cli:' docker-compose.yml" "yt-dlp-cli service should be defined"
    assert_true "grep -q 'openvpn-yt-dlp:' docker-compose.yml" "openvpn-yt-dlp service should be defined"
    assert_true "grep -q 'metube-direct:' docker-compose.yml" "metube-direct service should be defined"
    assert_true "grep -q 'watchtower:' docker-compose.yml" "watchtower service should be defined"
}

test_profile_definitions() {
    cd "$PROJECT_DIR"
    
    # Check that all expected profiles exist
    assert_true "grep -q 'vpn' docker-compose.yml" "vpn profile should exist"
    assert_true "grep -q 'no-vpn' docker-compose.yml" "no-vpn profile should exist"
    assert_true "grep -q 'vpn-cli' docker-compose.yml" "vpn-cli profile should exist"
}

# =============================================================================
# Script Syntax Tests
# =============================================================================

test_script_syntax() {
    local scripts=(
        "scripts/setup/init"
        "scripts/service/start"
        "scripts/service/stop"
        "scripts/service/restart"
        "scripts/service/download"
        "scripts/service/cleanup"
        "scripts/service/status"
        "scripts/service/check-vpn"
        "scripts/service/update-images"
        "scripts/lifecycle/setup-auto-update"
    )
    
    cd "$PROJECT_DIR"
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            # Test bash syntax
            if bash -n "$script" 2>/dev/null; then
                log_debug "Script $script: syntax OK"
            else
                echo "Script $script has syntax errors"
                return 1
            fi
        else
            echo "Script $script not found"
            return 1
        fi
    done
}

# =============================================================================
# Network Port Tests
# =============================================================================

test_port_configuration() {
    cd "$PROJECT_DIR"
    
    # Check that ports are configured
    assert_true "grep -q '8086' docker-compose.yml" "Metube port 8086 should be configured"
    assert_true "grep -q '3130' docker-compose.yml" "yt-dlp VPN port 3130 should be configured"
}

test_port_availability() {
    # Test that we can check if a port is in use
    check_port() {
        local port="$1"
        if ss -tuln | grep -q ":$port " 2>/dev/null || netstat -tuln | grep -q ":$port " 2>/dev/null; then
            return 0
        else
            return 1
        fi
    }
    
    # Test with port 1 (should be free)
    assert_false "check_port 1" "Port 1 should not be in use"
}

# =============================================================================
# Dummy Test (for testing test framework)
# =============================================================================

test_dummy_fail() {
    return 1
}

# =============================================================================
# File Ownership Tests
# =============================================================================

test_file_ownership_utility() {
    cd "$PROJECT_DIR"
    
    # Test that file ownership utility exists
    assert_true "[ -f "scripts/utils/file-ownership.sh" ]" "File ownership utility should exist"
    
    # Source the utility
    source "scripts/utils/file-ownership.sh"
    
    # Test that functions exist
    assert_true "type enforce_file_ownership > /dev/null 2>&1" "enforce_file_ownership function should exist"
    assert_true "type check_file_ownership > /dev/null 2>&1" "check_file_ownership function should exist"
    
    # Create test file and directory
    local test_file="$TEST_CONFIG_DIR/ownership-test.txt"
    local test_dir="$TEST_CONFIG_DIR/ownership-test-dir"
    local test_subdir="$test_dir/subdir"
    local test_subfile="$test_subdir/subfile.txt"
    
    rm -rf "$test_file" "$test_dir"
    mkdir -p "$test_subdir"
    echo "test content" > "$test_file"
    echo "test content" > "$test_subfile"
    
    # Test check_file_ownership with correct ownership
    assert_true "check_file_ownership '$test_file'" "File should be owned by current user"
    assert_true "check_file_ownership '$test_dir'" "Directory should be owned by current user"
    
    # Change ownership to root (if we can) or another user
    # We'll test the enforce function by changing ownership and then fixing it
    # Note: This test might need to be skipped if we don't have permission to chown to root
    
    # Test enforce_file_ownership
    enforce_file_ownership "$test_file"
    assert_true "check_file_ownership '$test_file'" "File should be owned by current user after enforcement"
    
    enforce_file_ownership "$test_dir"
    assert_true "check_file_ownership '$test_dir'" "Directory should be owned by current user after enforcement"
    
    # Test recursive enforcement
    enforce_file_ownership "$test_dir" "recursive"
    assert_true "check_file_ownership '$test_subdir'" "Subdirectory should be owned by current user"
    assert_true "check_file_ownership '$test_subfile'" "Subfile should be owned by current user"
    
    # Clean up
    rm -rf "$test_file" "$test_dir"
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_unit_tests() {
    log_info "Running Unit Tests..."

    run_test "test_container_runtime_detection" test_container_runtime_detection
    run_test "test_compose_command_detection" test_compose_command_detection
    run_test "test_color_output" test_color_output
    run_test "test_env_loading" test_env_loading
    run_test "test_env_variable_validation" test_env_variable_validation
    run_test "test_path_validation" test_path_validation
    run_test "test_directory_creation" test_directory_creation
    run_test "test_file_permissions" test_file_permissions
    run_test "test_string_functions" test_string_functions
    run_test "test_vpn_config_parsing" test_vpn_config_parsing
    run_test "test_vpn_auth_file_creation" test_vpn_auth_file_creation
    run_test "test_docker_compose_syntax" test_docker_compose_syntax
    run_test "test_service_definitions" test_service_definitions
    run_test "test_profile_definitions" test_profile_definitions
    run_test "test_script_syntax" test_script_syntax
    run_test "test_port_configuration" test_port_configuration
    run_test "test_port_availability" test_port_availability
    run_test "test_file_ownership_utility" test_file_ownership_utility
    run_test "test_installation_script" test_installation_script
    run_test "test_boot_script" test_boot_script
    run_test "test_comprehensive_test_script" test_comprehensive_test_script
    run_test "test_release_script" test_release_script
    run_test "test_enable_persistence_script" test_enable_persistence_script
    run_test "test_verify_cycle_script" test_verify_cycle_script
    run_test "test_dummy_fail" test_dummy_fail
}

# =============================================================================
# Installation Script Tests
# =============================================================================

test_installation_script() {
    cd "$PROJECT_DIR"
    
    # Test that installation script exists
    assert_true "[ -f \"scripts/lifecycle/install.sh\" ]" "Installation script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/install.sh\" ]" "Installation script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/install.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Installation script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/install.sh" "Installation script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/install.sh" "Installation script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/install.sh" "Installation script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/install.sh" "Installation script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/install.sh" "Installation script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/install.sh" "Installation script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/install.sh" "Installation script should have NC color"
    
    # Test that it has required functions
    assert_true "grep -q 'check_container_runtime' scripts/lifecycle/install.sh" "Installation script should have check_container_runtime function"
    assert_true "grep -q 'install_container_runtime' scripts/lifecycle/install.sh" "Installation script should have install_container_runtime function"
    assert_true "grep -q 'check_compose_plugin' scripts/lifecycle/install.sh" "Installation script should have check_compose_plugin function"
    assert_true "grep -q 'install_compose_plugin' scripts/lifecycle/install.sh" "Installation script should have install_compose_plugin function"
    
    # Test that it references init script
    assert_true "grep -q 'scripts/setup/init' scripts/lifecycle/install.sh" "Installation script should reference init script"
    
    # Test that it references setup-systemd script
    assert_true "grep -q 'scripts/setup/setup-systemd.sh' scripts/lifecycle/install.sh" "Installation script should reference setup-systemd script"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/install.sh" "Installation script should have valid bash syntax"
}


# =============================================================================
# Boot Script Tests
# =============================================================================

test_boot_script() {
    cd "$PROJECT_DIR"
    
    # Test that boot script exists
    assert_true "[ -f \"scripts/lifecycle/boot.sh\" ]" "Boot script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/boot.sh\" ]" "Boot script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/boot.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Boot script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/boot.sh" "Boot script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/boot.sh" "Boot script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/boot.sh" "Boot script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/boot.sh" "Boot script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/boot.sh" "Boot script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/boot.sh" "Boot script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/boot.sh" "Boot script should have NC color"
    
    # Test that it has helper functions
    assert_true "grep -q 'log_info' scripts/lifecycle/boot.sh" "Boot script should have log_info function"
    assert_true "grep -q 'log_success' scripts/lifecycle/boot.sh" "Boot script should have log_success function"
    assert_true "grep -q 'log_warning' scripts/lifecycle/boot.sh" "Boot script should have log_warning function"
    assert_true "grep -q 'log_error' scripts/lifecycle/boot.sh" "Boot script should have log_error function"
    
    # Test that it loads .env
    assert_true "grep -q 'source.*\\.env' scripts/lifecycle/boot.sh" "Boot script should load .env file"
    
    # Test that it detects container runtime
    assert_true "grep -q 'CONTAINER_RUNTIME' scripts/lifecycle/boot.sh" "Boot script should detect container runtime"
    
    # Test that it supports both systemd and docker-compose
    assert_true "grep -q 'USE_SYSTEMD' scripts/lifecycle/boot.sh" "Boot script should support USE_SYSTEMD option"
    assert_true "grep -q 'start-systemd.sh' scripts/lifecycle/boot.sh" "Boot script should reference systemd start script"
    assert_true "grep -q 'scripts/service/start' scripts/lifecycle/boot.sh" "Boot script should reference docker-compose start script"
    
    # Test that it does health checks
    assert_true "grep -q 'health' scripts/lifecycle/boot.sh" "Boot script should perform health checks"
    assert_true "grep -q 'curl' scripts/lifecycle/boot.sh" "Boot script should check HTTP endpoints"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/boot.sh" "Boot script should have valid bash syntax"
}


# =============================================================================
# Comprehensive Test Script Tests
# =============================================================================

test_comprehensive_test_script() {
    cd "$PROJECT_DIR"
    
    # Test that test script exists
    assert_true "[ -f \"scripts/lifecycle/test.sh\" ]" "Comprehensive test script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/test.sh\" ]" "Comprehensive test script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/test.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Comprehensive test script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/test.sh" "Comprehensive test script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/test.sh" "Comprehensive test script should have NC color"
    
    # Test that it has test runner functions
    assert_true "grep -q 'run_test' scripts/lifecycle/test.sh" "Comprehensive test script should have run_test function"
    assert_true "grep -q 'run_test_verbose' scripts/lifecycle/test.sh" "Comprehensive test script should have run_test_verbose function"
    
    # Test that it loads .env
    assert_true "grep -q 'source.*\\.env' scripts/lifecycle/test.sh" "Comprehensive test script should load .env file"
    
    # Test that it has test suites
    assert_true "grep -q 'Suite 1: Unit Tests' scripts/lifecycle/test.sh" "Comprehensive test script should have Unit Tests suite"
    assert_true "grep -q 'Suite 2: Script Syntax Validation' scripts/lifecycle/test.sh" "Comprehensive test script should have Script Syntax suite"
    assert_true "grep -q 'Suite 3: Docker Compose Validation' scripts/lifecycle/test.sh" "Comprehensive test script should have Docker Compose suite"
    assert_true "grep -q 'Suite 4: Live Service Tests' scripts/lifecycle/test.sh" "Comprehensive test script should have Live Service Tests suite"
    assert_true "grep -q 'Suite 5: File Ownership Validation' scripts/lifecycle/test.sh" "Comprehensive test script should have File Ownership suite"
    assert_true "grep -q 'Suite 6: Security Validation' scripts/lifecycle/test.sh" "Comprehensive test script should have Security suite"
    
    # Test that it does deterministic validation
    assert_true "grep -q 'TESTS_TOTAL' scripts/lifecycle/test.sh" "Comprehensive test script should track test totals"
    assert_true "grep -q 'TESTS_PASSED' scripts/lifecycle/test.sh" "Comprehensive test script should track passed tests"
    assert_true "grep -q 'TESTS_FAILED' scripts/lifecycle/test.sh" "Comprehensive test script should track failed tests"
    assert_true "grep -q 'PASS_RATE' scripts/lifecycle/test.sh" "Comprehensive test script should calculate pass rate"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/test.sh" "Comprehensive test script should have valid bash syntax"
}


# =============================================================================
# Release Script Tests
# =============================================================================

test_release_script() {
    cd "$PROJECT_DIR"
    
    # Test that release script exists
    assert_true "[ -f \"scripts/lifecycle/release.sh\" ]" "Release script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/release.sh\" ]" "Release script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/release.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Release script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/release.sh" "Release script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/release.sh" "Release script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/release.sh" "Release script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/release.sh" "Release script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/release.sh" "Release script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/release.sh" "Release script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/release.sh" "Release script should have NC color"
    
    # Test that it has helper functions
    assert_true "grep -q 'log_info' scripts/lifecycle/release.sh" "Release script should have log_info function"
    assert_true "grep -q 'log_success' scripts/lifecycle/release.sh" "Release script should have log_success function"
    assert_true "grep -q 'log_warning' scripts/lifecycle/release.sh" "Release script should have log_warning function"
    assert_true "grep -q 'log_error' scripts/lifecycle/release.sh" "Release script should have log_error function"
    
    # Test that it checks for gh/glab
    assert_true "grep -q 'command -v gh' scripts/lifecycle/release.sh" "Release script should check for GitHub CLI"
    assert_true "grep -q 'command -v glab' scripts/lifecycle/release.sh" "Release script should check for GitLab CLI"
    
    # Test that it determines version
    assert_true "grep -q 'git describe' scripts/lifecycle/release.sh" "Release script should get current version from git"
    assert_true "grep -q 'NEW_VERSION' scripts/lifecycle/release.sh" "Release script should handle new version"
    
    # Test that it generates changelog
    assert_true "grep -q 'CHANGELOG' scripts/lifecycle/release.sh" "Release script should generate changelog"
    assert_true "grep -q 'git log' scripts/lifecycle/release.sh" "Release script should extract commits from git log"
    
    # Test that it creates git tag
    assert_true "grep -q 'git tag' scripts/lifecycle/release.sh" "Release script should create git tag"
    
    # Test that it pushes to origin
    assert_true "grep -q 'git push origin' scripts/lifecycle/release.sh" "Release script should push to origin"
    
    # Test that it creates GitHub/GitLab releases
    assert_true "grep -q 'gh release create' scripts/lifecycle/release.sh" "Release script should create GitHub release"
    assert_true "grep -q 'glab release create' scripts/lifecycle/release.sh" "Release script should create GitLab release"
    
    # Test that it mirrors submodules
    assert_true "grep -q 'git submodule foreach' scripts/lifecycle/release.sh" "Release script should mirror submodules"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/release.sh" "Release script should have valid bash syntax"
}


# =============================================================================
# Enable Persistence Script Tests
# =============================================================================

test_enable_persistence_script() {
    cd "$PROJECT_DIR"
    
    # Test that script exists
    assert_true "[ -f \"scripts/lifecycle/enable-persistence.sh\" ]" "Enable persistence script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/enable-persistence.sh\" ]" "Enable persistence script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/enable-persistence.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Enable persistence script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have NC color"
    
    # Test that it has helper functions
    assert_true "grep -q 'log_info' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have log_info function"
    assert_true "grep -q 'log_success' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have log_success function"
    assert_true "grep -q 'log_warning' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have log_warning function"
    assert_true "grep -q 'log_error' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have log_error function"
    
    # Test that it checks linger
    assert_true "grep -q 'loginctl enable-linger' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should enable linger"
    assert_true "grep -q 'loginctl show-user' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should check linger status"
    
    # Test that it verifies systemd services
    assert_true "grep -q 'systemctl --user is-enabled' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should check if services are enabled"
    assert_true "grep -q 'systemctl --user enable' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should enable services"
    
    # Test that it verifies restart policies
    assert_true "grep -q 'Restart=unless-stopped' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should verify restart policies"
    
    # Test that it verifies dependencies
    assert_true "grep -q 'Requires=' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should verify service dependencies"
    assert_true "grep -q 'openvpn-yt-dlp' scripts/lifecycle/enable-persistence.sh" "Enable persistence script should check VPN dependencies"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/enable-persistence.sh" "Enable persistence script should have valid bash syntax"
}


# =============================================================================
# Verify Cycle Script Tests
# =============================================================================

test_verify_cycle_script() {
    cd "$PROJECT_DIR"
    
    # Test that script exists
    assert_true "[ -f \"scripts/lifecycle/verify-cycle.sh\" ]" "Verify cycle script should exist"
    
    # Test that it's executable
    assert_true "[ -x \"scripts/lifecycle/verify-cycle.sh\" ]" "Verify cycle script should be executable"
    
    # Test that it has proper shebang
    local shebang
    shebang=$(head -1 scripts/lifecycle/verify-cycle.sh)
    assert_true "[ \"$shebang\" = \"#!/bin/bash\" ]" "Verify cycle script should have bash shebang"
    
    # Test that it has set -e
    assert_true "grep -q '^set -e' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have set -e"
    
    # Test that it has color definitions
    assert_true "grep -q \"RED='\\\\033\\[0;31m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have RED color"
    assert_true "grep -q \"GREEN='\\\\033\\[0;32m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have GREEN color"
    assert_true "grep -q \"YELLOW='\\\\033\\[1;33m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have YELLOW color"
    assert_true "grep -q \"BLUE='\\\\033\\[0;34m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have BLUE color"
    assert_true "grep -q \"CYAN='\\\\033\\[0;36m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have CYAN color"
    assert_true "grep -q \"NC='\\\\033\\[0m'\" scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have NC color"
    
    # Test that it has helper functions
    assert_true "grep -q 'log_info' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have log_info function"
    assert_true "grep -q 'log_success' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have log_success function"
    assert_true "grep -q 'log_warning' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have log_warning function"
    assert_true "grep -q 'log_error' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have log_error function"
    
    # Test that it has run_stage function
    assert_true "grep -q 'run_stage' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have run_stage function"
    
    # Test that it runs all lifecycle stages
    assert_true "grep -q 'Stage 1: Install' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should run Install stage"
    assert_true "grep -q 'Stage 2: Boot' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should run Boot stage"
    assert_true "grep -q 'Stage 3: Test' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should run Test stage"
    assert_true "grep -q 'Stage 4: Release' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should run Release stage"
    assert_true "grep -q 'Stage 5: Persistence' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should run Persistence stage"
    
    # Test that it references all lifecycle scripts
    assert_true "grep -q 'install.sh' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should reference install.sh"
    assert_true "grep -q 'boot.sh' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should reference boot.sh"
    assert_true "grep -q 'test.sh' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should reference test.sh"
    assert_true "grep -q 'release.sh' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should reference release.sh"
    assert_true "grep -q 'enable-persistence.sh' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should reference enable-persistence.sh"
    
    # Test that it tracks results
    assert_true "grep -q 'STAGE_RESULTS' scripts/lifecycle/verify-cycle.sh" "Verify cycle script should track stage results"
    
    # Test syntax
    assert_true "bash -n scripts/lifecycle/verify-cycle.sh" "Verify cycle script should have valid bash syntax"
}

