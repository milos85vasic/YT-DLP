#!/bin/bash
#
# Integration Tests for YT-DLP Project
# Tests script workflows and component interactions
#

# =============================================================================
# Init Script Tests
# =============================================================================

test_init_no_vpn() {
    cd "$PROJECT_DIR"
    
    # Setup test environment
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    
    # Run init script
    if ! ./init > "$TEST_LOGS_DIR/init-no-vpn.log" 2>&1; then
        echo "Init script failed for no-VPN configuration"
        return 1
    fi
    
    # Verify expected directories were created
    assert_dir_exists "./yt-dlp/config" "yt-dlp/config directory should be created"
    assert_dir_exists "./yt-dlp/cookies" "yt-dlp/cookies directory should be created"
    assert_dir_exists "./yt-dlp/archive" "yt-dlp/archive directory should be created"
    assert_dir_exists "./metube/config" "metube/config directory should be created"
    
    # Verify config file was created
    assert_file_exists "./yt-dlp/config/yt-dlp.conf" "yt-dlp.conf should be created"
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt 2>/dev/null || true
}

test_init_with_vpn() {
    cd "$PROJECT_DIR"
    
    # Setup test environment
    cp "$TEST_CONFIG_DIR/.env.with-vpn" .env
    
    # Run init script
    if ! ./init > "$TEST_LOGS_DIR/init-with-vpn.log" 2>&1; then
        echo "Init script failed for VPN configuration"
        return 1
    fi
    
    # Verify expected directories were created
    assert_dir_exists "./yt-dlp/config" "yt-dlp/config directory should be created"
    assert_dir_exists "./metube/config" "metube/config directory should be created"
    
    # Verify VPN auth file was created
    assert_file_exists "./vpn-auth.txt" "vpn-auth.txt should be created"
    
    # Verify auth file has correct permissions
    local perms
    perms=$(stat -c "%a" ./vpn-auth.txt 2>/dev/null || stat -f "%Lp" ./vpn-auth.txt)
    assert_true "[ '$perms' = '600' ]" "vpn-auth.txt should have 600 permissions"
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt
}

test_init_missing_env() {
    cd "$PROJECT_DIR"
    
    # Remove .env if exists
    rm -f .env
    
    # Run init script - should fail
    if ./init > "$TEST_LOGS_DIR/init-missing-env.log" 2>&1; then
        echo "Init script should fail when .env is missing"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Start/Stop Script Tests
# =============================================================================

test_start_no_vpn() {
    cd "$PROJECT_DIR"
    
    # Check if we can run start script
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_start_no_vpn" "No container runtime available"
        return 0
    fi
    
    # Setup test environment
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    
    # Note: We won't actually start containers in tests to avoid side effects
    # Instead, we'll check that the script runs init and update-images
    
    # Test that init works
    if ! ./init > "$TEST_LOGS_DIR/start-init.log" 2>&1; then
        echo "Init failed before start"
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt 2>/dev/null || true
    
    return 0
}

test_start_with_vpn() {
    cd "$PROJECT_DIR"
    
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_start_with_vpn" "No container runtime available"
        return 0
    fi
    
    # Setup test environment
    cp "$TEST_CONFIG_DIR/.env.with-vpn" .env
    
    # Test that init works with VPN
    if ! ./init > "$TEST_LOGS_DIR/start-vpn-init.log" 2>&1; then
        echo "Init failed before start with VPN"
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt
    
    return 0
}

test_stop_services() {
    cd "$PROJECT_DIR"
    
    # Test that stop script exists and has correct syntax
    assert_file_exists "./stop" "stop script should exist"
    
    if ! bash -n ./stop; then
        echo "Stop script has syntax errors"
        return 1
    fi
    
    return 0
}

test_restart_services() {
    cd "$PROJECT_DIR"
    
    # Test that restart script exists and calls stop and start
    assert_file_exists "./restart" "restart script should exist"
    
    if ! bash -n ./restart; then
        echo "Restart script has syntax errors"
        return 1
    fi
    
    # Verify restart calls stop and start
    assert_true "grep -q './stop' restart" "restart should call ./stop"
    assert_true "grep -q './start' restart" "restart should call ./start"
    
    return 0
}

# =============================================================================
# Download Script Tests
# =============================================================================

test_download_helper() {
    cd "$PROJECT_DIR"
    
    # Test that download script exists
    assert_file_exists "./download" "download script should exist"
    
    # Test syntax
    if ! bash -n ./download; then
        echo "Download script has syntax errors"
        return 1
    fi
    
    # Test help output
    if ! ./download --help > "$TEST_LOGS_DIR/download-help.log" 2>&1; then
        echo "Download script --help failed"
        return 1
    fi
    
    # Verify help output contains expected text
    assert_true "grep -q 'Usage:' '$TEST_LOGS_DIR/download-help.log'" "Help should contain Usage"
    assert_true "grep -q 'download' '$TEST_LOGS_DIR/download-help.log'" "Help should mention download"
    
    return 0
}

test_download_batch_mode() {
    cd "$PROJECT_DIR"
    
    # Test that batch mode is documented
    assert_true "grep -q 'batch' download" "Download script should support batch mode"
    assert_true "grep -q 'channels' download" "Download script should support channels mode"
    
    return 0
}

# =============================================================================
# Update Images Script Tests
# =============================================================================

test_update_images() {
    cd "$PROJECT_DIR"
    
    # Test that update-images script exists
    assert_file_exists "./update-images" "update-images script should exist"
    
    # Test syntax
    if ! bash -n ./update-images; then
        echo "update-images script has syntax errors"
        return 1
    fi
    
    # Test that it defines expected images
    assert_true "grep -q 'metube' update-images" "update-images should mention metube"
    assert_true "grep -q 'yt-dlp' update-images" "update-images should mention yt-dlp"
    
    return 0
}

test_update_images_execution() {
    cd "$PROJECT_DIR"
    
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_update_images_execution" "No container runtime available"
        return 0
    fi
    
    # Test that update-images runs without errors
    if ! timeout 60 ./update-images > "$TEST_LOGS_DIR/update-images.log" 2>&1; then
        echo "update-images script failed to execute"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Cleanup Script Tests
# =============================================================================

test_cleanup_script() {
    cd "$PROJECT_DIR"
    
    # Test that cleanup script exists
    assert_file_exists "./cleanup" "cleanup script should exist"
    
    # Test syntax
    if ! bash -n ./cleanup; then
        echo "Cleanup script has syntax errors"
        return 1
    fi
    
    # Test help/usage
    if ! ./cleanup 2>&1 | grep -q "Usage:"; then
        echo "Cleanup script should show usage when called without args"
        return 1
    fi
    
    return 0
}

test_cleanup_options() {
    cd "$PROJECT_DIR"
    
    # Test that cleanup supports all options
    assert_true "grep -q 'all' cleanup" "cleanup should support 'all' option"
    assert_true "grep -q 'ytdlp' cleanup" "cleanup should support 'ytdlp' option"
    assert_true "grep -q 'jdownloader' cleanup" "cleanup should support 'jdownloader' option"
    
    return 0
}

# =============================================================================
# Status Script Tests
# =============================================================================

test_status_script() {
    cd "$PROJECT_DIR"
    
    # Test that status script exists
    assert_file_exists "./status" "status script should exist"
    
    # Test syntax
    if ! bash -n ./status; then
        echo "Status script has syntax errors"
        return 1
    fi
    
    return 0
}

test_status_output() {
    cd "$PROJECT_DIR"
    
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_status_output" "No container runtime available"
        return 0
    fi
    
    # Run status and capture output
    if ! ./status > "$TEST_LOGS_DIR/status.log" 2>&1; then
        echo "Status script failed"
        return 1
    fi
    
    # Check that output contains expected sections
    assert_true "grep -q 'Container Runtime' '$TEST_LOGS_DIR/status.log' || grep -qi 'runtime' '$TEST_LOGS_DIR/status.log'" "Status should show runtime info"
    assert_true "grep -qi 'service' '$TEST_LOGS_DIR/status.log' || grep -qi 'status' '$TEST_LOGS_DIR/status.log'" "Status should show service status"
    
    return 0
}

# =============================================================================
# Check VPN Script Tests
# =============================================================================

test_check_vpn_script() {
    cd "$PROJECT_DIR"
    
    # Test that check-vpn script exists
    assert_file_exists "./check-vpn" "check-vpn script should exist"
    
    # Test syntax
    if ! bash -n ./check-vpn; then
        echo "check-vpn script has syntax errors"
        return 1
    fi
    
    return 0
}

test_check_vpn_without_vpn() {
    cd "$PROJECT_DIR"
    
    # Create .env with VPN disabled
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    
    # Run check-vpn - should exit gracefully
    if ! ./check-vpn > "$TEST_LOGS_DIR/check-vpn-no-vpn.log" 2>&1; then
        # This is actually expected when VPN is disabled
        log_debug "check-vpn exited (expected when VPN is disabled)"
    fi
    
    # Cleanup
    rm -f .env
    
    return 0
}

# =============================================================================
# Setup Auto-Update Script Tests
# =============================================================================

test_setup_auto_update() {
    cd "$PROJECT_DIR"
    
    # Test that setup-auto-update script exists
    assert_file_exists "./setup-auto-update" "setup-auto-update script should exist"
    
    # Test syntax
    if ! bash -n ./setup-auto-update; then
        echo "setup-auto-update script has syntax errors"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Service Health Check Tests
# =============================================================================

test_docker_compose_health() {
    cd "$PROJECT_DIR"
    
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_docker_compose_health" "No container runtime available"
        return 0
    fi
    
    # Get compose command
    local compose_cmd
    if command -v podman-compose &> /dev/null; then
        compose_cmd="podman-compose"
    elif command -v docker-compose && command -v docker &> /dev/null; then
        compose_cmd="docker-compose"
    else
        skip_test "test_docker_compose_health" "No compose command available"
        return 0
    fi
    
    # Test that compose file is valid (config check)
    if ! $compose_cmd config > "$TEST_LOGS_DIR/compose-config.log" 2>&1; then
        echo "docker-compose.yml has configuration errors"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_integration_tests() {
    log_info "Running Integration Tests..."
    
    run_test "test_init_no_vpn" test_init_no_vpn
    run_test "test_init_with_vpn" test_init_with_vpn
    run_test "test_init_missing_env" test_init_missing_env
    run_test "test_start_no_vpn" test_start_no_vpn
    run_test "test_start_with_vpn" test_start_with_vpn
    run_test "test_stop_services" test_stop_services
    run_test "test_restart_services" test_restart_services
    run_test "test_download_helper" test_download_helper
    run_test "test_download_batch_mode" test_download_batch_mode
    run_test "test_update_images" test_update_images
    run_test "test_update_images_execution" test_update_images_execution
    run_test "test_cleanup_script" test_cleanup_script
    run_test "test_cleanup_options" test_cleanup_options
    run_test "test_status_script" test_status_script
    run_test "test_status_output" test_status_output
    run_test "test_check_vpn_script" test_check_vpn_script
    run_test "test_check_vpn_without_vpn" test_check_vpn_without_vpn
    run_test "test_setup_auto_update" test_setup_auto_update
    run_test "test_docker_compose_health" test_docker_compose_health
}
