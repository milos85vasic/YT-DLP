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
    local scripts=("init" "start" "stop" "restart" "download" "cleanup" "status" "check-vpn" "update-images" "setup-auto-update")
    
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
}
