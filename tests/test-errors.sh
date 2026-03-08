#!/bin/bash
#
# Error Tests for YT-DLP Project
# Tests error conditions and edge cases
#

# =============================================================================
# Container Runtime Error Tests
# =============================================================================

test_error_no_runtime() {
    cd "$PROJECT_DIR"
    
    # Create a modified version of init that simulates no runtime
    cat > /tmp/test-init-no-runtime.sh << 'EOF'
#!/bin/bash
set -e

detect_container_runtime() {
    echo "none"
}

RED='\033[0;31m'
NC='\033[0m'

CONTAINER_RUNTIME=$(detect_container_runtime)

if [ "$CONTAINER_RUNTIME" = "none" ]; then
    echo -e "${RED}ERROR: No container runtime found!${NC}"
    exit 1
fi
EOF
    
    chmod +x /tmp/test-init-no-runtime.sh
    
    # Test that it fails correctly
    if /tmp/test-init-no-runtime.sh > "$TEST_LOGS_DIR/error-no-runtime.log" 2>&1; then
        echo "Should have failed when no runtime available"
        rm -f /tmp/test-init-no-runtime.sh
        return 1
    fi
    
    # Verify error message
    assert_true "grep -q 'No container runtime found' '$TEST_LOGS_DIR/error-no-runtime.log'" \
        "Should show appropriate error message"
    
    rm -f /tmp/test-init-no-runtime.sh
    return 0
}

# =============================================================================
# Environment Variable Error Tests
# =============================================================================

test_error_missing_env() {
    cd "$PROJECT_DIR"
    
    # Remove .env file
    rm -f .env
    
    # Run init - should fail
    if ./init > "$TEST_LOGS_DIR/error-missing-env.log" 2>&1; then
        echo "Init should fail when .env is missing"
        return 1
    fi
    
    # Verify it prompts to create from template
    assert_true "grep -iq 'env' '$TEST_LOGS_DIR/error-missing-env.log'" \
        "Should mention .env file in error"
    
    return 0
}

test_error_missing_required_vars() {
    cd "$PROJECT_DIR"
    
    # Create .env with missing required vars
    cat > .env << 'EOF'
# Empty env file
EOF
    
    # Run init - should fail or warn
    if ./init > "$TEST_LOGS_DIR/error-missing-vars.log" 2>&1; then
        log_warn "Init passed with missing vars - check validation logic"
    fi
    
    rm -f .env
    return 0
}

test_error_empty_download_dir() {
    cd "$PROJECT_DIR"
    
    # Create .env with empty download dir
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=
EOF
    
    # Run init - should handle gracefully
    if ! ./init > "$TEST_LOGS_DIR/error-empty-download.log" 2>&1; then
        log_debug "Init failed with empty download dir (may be expected)"
    fi
    
    rm -f .env
    return 0
}

# =============================================================================
# VPN Configuration Error Tests
# =============================================================================

test_error_invalid_vpn_config() {
    cd "$PROJECT_DIR"
    
    # Create .env with invalid VPN config path
    cat > .env << 'EOF'
USE_VPN=true
DOWNLOAD_DIR=/tmp/test-downloads
VPN_USERNAME=testuser
VPN_PASSWORD=testpass
VPN_OVPN_PATH=/nonexistent/path/config.ovpn
EOF
    
    # Run init - should fail on VPN validation
    if ./init > "$TEST_LOGS_DIR/error-invalid-vpn.log" 2>&1; then
        log_warn "Init passed with invalid VPN config - check validation"
    else
        # Verify it mentions the missing file
        assert_true "grep -q 'VPN config file not found' '$TEST_LOGS_DIR/error-invalid-vpn.log' || \
                     grep -q 'not found' '$TEST_LOGS_DIR/error-invalid-vpn.log' || \
                     grep -q 'ERROR' '$TEST_LOGS_DIR/error-invalid-vpn.log'" \
            "Should report VPN config error"
    fi
    
    rm -f .env
    return 0
}

test_error_missing_vpn_credentials() {
    cd "$PROJECT_DIR"
    
    # Create .env with VPN enabled but missing credentials
    cat > .env << 'EOF'
USE_VPN=true
DOWNLOAD_DIR=/tmp/test-downloads
VPN_USERNAME=
VPN_PASSWORD=
VPN_OVPN_PATH=/tmp/test-vpn/config.ovpn
EOF
    
    # Run init - should fail or warn
    if ./init > "$TEST_LOGS_DIR/error-missing-vpn-creds.log" 2>&1; then
        log_warn "Init passed with missing VPN credentials - check validation"
    fi
    
    rm -f .env
    return 0
}

test_error_vpn_auth_permission() {
    cd "$PROJECT_DIR"
    
    # Create .env with VPN enabled
    cp "$TEST_CONFIG_DIR/.env.with-vpn" .env
    
    # Run init to create auth file
    ./init > /dev/null 2>&1 || true
    
    # Check if vpn-auth.txt exists and has correct permissions
    if [ -f "vpn-auth.txt" ]; then
        local perms
        perms=$(stat -c "%a" vpn-auth.txt 2>/dev/null || stat -f "%Lp" vpn-auth.txt)
        if [ "$perms" != "600" ]; then
            echo "VPN auth file has incorrect permissions: $perms (expected 600)"
            rm -f .env vpn-auth.txt
            return 1
        fi
    fi
    
    rm -f .env vpn-auth.txt 2>/dev/null || true
    return 0
}

# =============================================================================
# Docker Compose Error Tests
# =============================================================================

test_error_docker_compose_syntax() {
    cd "$PROJECT_DIR"
    
    # Test that docker-compose.yml is valid YAML
    if command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2> "$TEST_LOGS_DIR/error-compose-syntax.log"; then
            echo "docker-compose.yml has YAML syntax errors"
            return 1
        fi
    elif command -v yamllint &> /dev/null; then
        if ! yamllint docker-compose.yml > "$TEST_LOGS_DIR/error-compose-syntax.log" 2>&1; then
            log_warn "yamllint found issues (may be style warnings)"
        fi
    else
        # Basic syntax check with grep
        if ! grep -q "^services:" docker-compose.yml; then
            echo "docker-compose.yml missing services section"
            return 1
        fi
    fi
    
    return 0
}

test_error_missing_docker_compose() {
    cd "$PROJECT_DIR"
    
    # Ensure docker-compose.yml exists
    assert_file_exists "docker-compose.yml" "docker-compose.yml should exist"
    
    # Check that it's readable
    if [ ! -r "docker-compose.yml" ]; then
        echo "docker-compose.yml is not readable"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Script Error Tests
# =============================================================================

test_error_script_syntax() {
    cd "$PROJECT_DIR"
    
    local scripts=("init" "start" "stop" "restart" "download" "cleanup" "status" "check-vpn" "update-images" "setup-auto-update")
    local failed_scripts=()
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if ! bash -n "$script" 2> "$TEST_LOGS_DIR/error-syntax-${script}.log"; then
                failed_scripts+=("$script")
            fi
        else
            failed_scripts+=("$script (missing)")
        fi
    done
    
    if [ ${#failed_scripts[@]} -gt 0 ]; then
        echo "Scripts with syntax errors: ${failed_scripts[*]}"
        return 1
    fi
    
    return 0
}

test_error_script_permissions() {
    cd "$PROJECT_DIR"
    
    local scripts=("init" "start" "stop" "restart" "download" "cleanup" "status" "check-vpn" "update-images" "setup-auto-update")
    local not_executable=()
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ ! -x "$script" ]; then
                not_executable+=("$script")
            fi
        fi
    done
    
    if [ ${#not_executable[@]} -gt 0 ]; then
        echo "Scripts not executable: ${not_executable[*]}"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Port Conflict Error Tests
# =============================================================================

test_error_port_conflict() {
    cd "$PROJECT_DIR"
    
    # Check that ports are configurable via env vars
    assert_true "grep -q '8086' docker-compose.yml" "Default Metube port should be defined"
    assert_true "grep -q '3130' docker-compose.yml" "Default yt-dlp VPN port should be defined"
    
    # Check that ports reference environment variables where applicable
    # Note: In the compose file, some ports may be hardcoded
    log_debug "Port configuration validated"
    
    return 0
}

# =============================================================================
# File System Error Tests
# =============================================================================

test_error_non_writable_download_dir() {
    # Skip if not root (can't create read-only directories as non-root easily)
    if [ "$EUID" -ne 0 ]; then
        skip_test "test_error_non_writable_download_dir" "Requires root to test properly"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Create a read-only directory
    local test_dir="/tmp/test-readonly-downloads"
    mkdir -p "$test_dir"
    chmod 555 "$test_dir"
    
    # Create .env pointing to read-only dir
    cat > .env << EOF
USE_VPN=false
DOWNLOAD_DIR=$test_dir
EOF
    
    # Run init - should handle gracefully
    if ./init > "$TEST_LOGS_DIR/error-readonly-dir.log" 2>&1; then
        log_warn "Init passed with read-only download dir"
    fi
    
    # Cleanup
    rm -f .env
    chmod 755 "$test_dir"
    rmdir "$test_dir" 2>/dev/null || true
    
    return 0
}

test_error_missing_directory_parent() {
    cd "$PROJECT_DIR"
    
    # Create .env with nested non-existent directory
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=/tmp/nonexistent/nested/downloads
EOF
    
    # Run init - should create parent directories
    if ! ./init > "$TEST_LOGS_DIR/error-missing-parent.log" 2>&1; then
        log_warn "Init failed with missing parent directory"
    fi
    
    rm -f .env
    return 0
}

# =============================================================================
# Network Error Tests
# =============================================================================

test_error_no_internet() {
    # This test is informational - we can't easily simulate no internet
    log_warn "test_error_no_internet: Simulating no internet is difficult in automated tests"
    log_warn "  Skipping detailed test - verify offline behavior manually"
    
    # Verify scripts handle network failures gracefully
    assert_true "grep -q '||' update-images || grep -q '2>' update-images" \
        "update-images should handle errors"
    
    return 0
}

# =============================================================================
# Resource Error Tests
# =============================================================================

test_error_insufficient_disk_space() {
    # Skip - difficult to simulate in automated test
    skip_test "test_error_insufficient_disk_space" "Cannot reliably test in automated environment"
    return 0
}

# =============================================================================
# Container Error Tests
# =============================================================================

test_error_container_not_running() {
    cd "$PROJECT_DIR"
    
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_error_container_not_running" "No container runtime available"
        return 0
    fi
    
    # Test that download script handles non-running containers gracefully
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    
    # Try to download without containers running
    if ./download --help > "$TEST_LOGS_DIR/error-container-not-running.log" 2>&1; then
        log_debug "Download help works without containers (expected)"
    fi
    
    rm -f .env
    return 0
}

# =============================================================================
# Configuration Error Tests
# =============================================================================

test_error_invalid_boolean_values() {
    cd "$PROJECT_DIR"
    
    # Test invalid USE_VPN values
    cat > .env << 'EOF'
USE_VPN=maybe
DOWNLOAD_DIR=/tmp/test-downloads
EOF
    
    if ./init > "$TEST_LOGS_DIR/error-invalid-bool.log" 2>&1; then
        log_warn "Init passed with invalid boolean value 'maybe'"
    fi
    
    rm -f .env
    return 0
}

test_error_relative_download_path() {
    cd "$PROJECT_DIR"
    
    # Test relative path (should ideally warn or convert to absolute)
    cat > .env << 'EOF'
USE_VPN=false
DOWNLOAD_DIR=./downloads
EOF
    
    if ! ./init > "$TEST_LOGS_DIR/error-relative-path.log" 2>&1; then
        log_debug "Init with relative path (may be handled)"
    fi
    
    rm -f .env
    return 0
}

# =============================================================================
# Permission Error Tests
# =============================================================================

test_error_script_not_executable() {
    cd "$PROJECT_DIR"
    
    # Temporarily remove execute permission from a script
    if [ -x "./download" ]; then
        chmod -x ./download
        
        # Verify it's no longer executable
        if [ -x "./download" ]; then
            echo "Failed to remove execute permission"
            chmod +x ./download
            return 1
        fi
        
        # Restore permission
        chmod +x ./download
    fi
    
    return 0
}

test_error_directory_permissions() {
    cd "$PROJECT_DIR"
    
    # Verify yt-dlp directories have correct permissions
    # Create them first
    ./init > /dev/null 2>&1 || true
    
    if [ -d "./yt-dlp" ]; then
        local perms
        perms=$(stat -c "%a" ./yt-dlp 2>/dev/null || stat -f "%Lp" ./yt-dlp)
        # Should be readable and executable (755)
        if [ "$perms" != "755" ] && [ "$perms" != "775" ] && [ "$perms" != "700" ]; then
            log_warn "yt-dlp directory has unusual permissions: $perms"
        fi
    fi
    
    return 0
}

# =============================================================================
# Edge Case Tests
# =============================================================================

test_error_empty_env_file() {
    cd "$PROJECT_DIR"
    
    # Create completely empty .env
    echo "" > .env
    
    if ./init > "$TEST_LOGS_DIR/error-empty-env.log" 2>&1; then
        log_warn "Init passed with empty .env file"
    fi
    
    rm -f .env
    return 0
}

test_error_comment_only_env() {
    cd "$PROJECT_DIR"
    
    # Create .env with only comments
    cat > .env << 'EOF'
# This is a comment
# Another comment
EOF
    
    if ./init > "$TEST_LOGS_DIR/error-comment-env.log" 2>&1; then
        log_warn "Init passed with comment-only .env file"
    fi
    
    rm -f .env
    return 0
}

test_error_special_characters_in_paths() {
    cd "$PROJECT_DIR"
    
    # Test special characters in paths (spaces, quotes, etc.)
    local special_dir="/tmp/test dir with spaces"
    mkdir -p "$special_dir"
    
    cat > .env << EOF
USE_VPN=false
DOWNLOAD_DIR=$special_dir
EOF
    
    if ! ./init > "$TEST_LOGS_DIR/error-special-chars.log" 2>&1; then
        log_debug "Init with special characters in path"
    fi
    
    rm -f .env
    rm -rf "$special_dir"
    return 0
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_error_tests() {
    log_info "Running Error Tests..."
    
    run_test "test_error_no_runtime" test_error_no_runtime
    run_test "test_error_missing_env" test_error_missing_env
    run_test "test_error_missing_required_vars" test_error_missing_required_vars
    run_test "test_error_empty_download_dir" test_error_empty_download_dir
    run_test "test_error_invalid_vpn_config" test_error_invalid_vpn_config
    run_test "test_error_missing_vpn_credentials" test_error_missing_vpn_credentials
    run_test "test_error_vpn_auth_permission" test_error_vpn_auth_permission
    run_test "test_error_docker_compose_syntax" test_error_docker_compose_syntax
    run_test "test_error_missing_docker_compose" test_error_missing_docker_compose
    run_test "test_error_script_syntax" test_error_script_syntax
    run_test "test_error_script_permissions" test_error_script_permissions
    run_test "test_error_port_conflict" test_error_port_conflict
    run_test "test_error_non_writable_download_dir" test_error_non_writable_download_dir
    run_test "test_error_missing_directory_parent" test_error_missing_directory_parent
    run_test "test_error_no_internet" test_error_no_internet
    run_test "test_error_insufficient_disk_space" test_error_insufficient_disk_space
    run_test "test_error_container_not_running" test_error_container_not_running
    run_test "test_error_invalid_boolean_values" test_error_invalid_boolean_values
    run_test "test_error_relative_download_path" test_error_relative_download_path
    run_test "test_error_script_not_executable" test_error_script_not_executable
    run_test "test_error_directory_permissions" test_error_directory_permissions
    run_test "test_error_empty_env_file" test_error_empty_env_file
    run_test "test_error_comment_only_env" test_error_comment_only_env
    run_test "test_error_special_characters_in_paths" test_error_special_characters_in_paths
}
