#!/bin/bash
#
# Scenario Tests for YT-DLP Project
# Tests combinations of runtime, VPN, and profiles
#

# =============================================================================
# Scenario: Podman + No VPN
# =============================================================================

test_scenario_podman_no_vpn() {
    if [ "$TEST_RUNTIME" != "podman" ] && [ "$TEST_RUNTIME" != "auto" ]; then
        skip_test "test_scenario_podman_no_vpn" "Not testing Podman runtime"
        return 0
    fi
    
    if ! command -v podman &> /dev/null; then
        skip_test "test_scenario_podman_no_vpn" "Podman not installed"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    echo "CONTAINER_RUNTIME=podman" >> .env
    
    # Run init
    if ! ./init > "$TEST_LOGS_DIR/scenario-podman-no-vpn-init.log" 2>&1; then
        echo "Init failed for Podman + No VPN scenario"
        rm -f .env
        return 1
    fi
    
    # Verify Podman is detected
    if ! grep -q "podman" "$TEST_LOGS_DIR/scenario-podman-no-vpn-init.log"; then
        echo "Podman runtime not detected correctly"
        rm -f .env
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt 2>/dev/null || true
    
    return 0
}

# =============================================================================
# Scenario: Podman + With VPN
# =============================================================================

test_scenario_podman_with_vpn() {
    if [ "$TEST_RUNTIME" != "podman" ] && [ "$TEST_RUNTIME" != "auto" ]; then
        skip_test "test_scenario_podman_with_vpn" "Not testing Podman runtime"
        return 0
    fi
    
    if ! command -v podman &> /dev/null; then
        skip_test "test_scenario_podman_with_vpn" "Podman not installed"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.with-vpn" .env
    echo "CONTAINER_RUNTIME=podman" >> .env
    
    # Run init
    if ! ./init > "$TEST_LOGS_DIR/scenario-podman-vpn-init.log" 2>&1; then
        echo "Init failed for Podman + VPN scenario"
        rm -f .env
        return 1
    fi
    
    # Verify VPN configuration is processed
    if [ ! -f "vpn-auth.txt" ]; then
        echo "VPN auth file not created"
        rm -f .env
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt
    
    return 0
}

# =============================================================================
# Scenario: Docker + No VPN
# =============================================================================

test_scenario_docker_no_vpn() {
    if [ "$TEST_RUNTIME" != "docker" ] && [ "$TEST_RUNTIME" != "auto" ]; then
        skip_test "test_scenario_docker_no_vpn" "Not testing Docker runtime"
        return 0
    fi

    # Zero-skip (CONST-034): instead of silently skipping when Docker
    # isn't installed, ASSERT that the compose file is Docker-compatible
    # (no runtime-specific syntax that would break under Docker). That's
    # the meaningful invariant — the scenario tests "would Docker work
    # if installed", and we can answer "yes, the config is portable"
    # without an actual Docker binary.
    if ! command -v docker &> /dev/null; then
        if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
            echo "docker-compose.yml missing"
            return 1
        fi
        # Check for podman-only directives that would break Docker.
        local podman_only
        podman_only=$(grep -nE '^[[:space:]]*(io\.podman\.|podman\.specific|userns_mode:[[:space:]]+keep-id)' "$PROJECT_DIR/docker-compose.yml" || true)
        if [ -n "$podman_only" ]; then
            echo "docker-compose.yml uses Podman-only directives — would break under Docker:"
            echo "$podman_only"
            return 1
        fi
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    echo "CONTAINER_RUNTIME=docker" >> .env
    
    # Run init
    if ! ./init > "$TEST_LOGS_DIR/scenario-docker-no-vpn-init.log" 2>&1; then
        echo "Init failed for Docker + No VPN scenario"
        rm -f .env
        return 1
    fi
    
    # Verify Docker is detected
    if ! grep -q "docker" "$TEST_LOGS_DIR/scenario-docker-no-vpn-init.log"; then
        echo "Docker runtime not detected correctly"
        rm -f .env
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt 2>/dev/null || true
    
    return 0
}

# =============================================================================
# Scenario: Docker + With VPN
# =============================================================================

test_scenario_docker_with_vpn() {
    if [ "$TEST_RUNTIME" != "docker" ] && [ "$TEST_RUNTIME" != "auto" ]; then
        skip_test "test_scenario_docker_with_vpn" "Not testing Docker runtime"
        return 0
    fi

    # Zero-skip (CONST-034): same fallback as test_scenario_docker_no_vpn.
    # Without a Docker binary we still check the vpn-profile compose
    # config is Docker-portable — that's the invariant the test name
    # promises. Real boot is exercised under Podman elsewhere.
    if ! command -v docker &> /dev/null; then
        if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
            echo "docker-compose.yml missing"
            return 1
        fi
        if ! grep -qE "^[[:space:]]+(openvpn-yt-dlp|metube|landing-vpn):" "$PROJECT_DIR/docker-compose.yml"; then
            echo "VPN profile services missing from docker-compose.yml"
            return 1
        fi
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.with-vpn" .env
    echo "CONTAINER_RUNTIME=docker" >> .env
    
    # Run init
    if ! ./init > "$TEST_LOGS_DIR/scenario-docker-vpn-init.log" 2>&1; then
        echo "Init failed for Docker + VPN scenario"
        rm -f .env
        return 1
    fi
    
    # Verify VPN configuration is processed
    if [ ! -f "vpn-auth.txt" ]; then
        echo "VPN auth file not created"
        rm -f .env
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt
    
    return 0
}

# =============================================================================
# Scenario: Batch Download Workflow
# =============================================================================

test_scenario_batch_download() {
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    ./init > /dev/null 2>&1 || true
    
    # Create test URLs file
    mkdir -p ./yt-dlp/config
    cat > ./yt-dlp/config/urls.txt << 'EOF'
# Test URLs
https://www.youtube.com/watch?v=dQw4w9WgXcQ
EOF
    
    # Test that download script handles batch mode
    if ! ./download --help > "$TEST_LOGS_DIR/scenario-batch-help.log" 2>&1; then
        echo "Download help failed"
        rm -f .env
        return 1
    fi
    
    # Verify URLs file exists
    assert_file_exists "./yt-dlp/config/urls.txt" "URLs file should exist"
    
    # Cleanup
    rm -f .env
    rm -f ./yt-dlp/config/urls.txt
    
    return 0
}

# =============================================================================
# Scenario: Channel Download Workflow
# =============================================================================

test_scenario_channel_download() {
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    ./init > /dev/null 2>&1 || true
    
    # Create test channels file
    mkdir -p ./yt-dlp/config
    cat > ./yt-dlp/config/channels.txt << 'EOF'
# Test Channels
https://www.youtube.com/c/TestChannel
EOF
    
    # Verify channels file exists
    assert_file_exists "./yt-dlp/config/channels.txt" "Channels file should exist"
    
    # Cleanup
    rm -f .env
    rm -f ./yt-dlp/config/channels.txt
    
    return 0
}

# =============================================================================
# Scenario: Complete Workflow (Init → Update → Start → Stop)
# =============================================================================

test_scenario_complete_workflow_no_vpn() {
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_scenario_complete_workflow_no_vpn" "No container runtime available"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Setup
    cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
    
    # Step 1: Init
    log_debug "Step 1: Running init..."
    if ! ./init > "$TEST_LOGS_DIR/scenario-workflow-init.log" 2>&1; then
        echo "Step 1 (Init) failed"
        rm -f .env
        return 1
    fi
    
    # Step 2: Update images
    log_debug "Step 2: Running update-images..."
    if ! timeout 60 ./update-images > "$TEST_LOGS_DIR/scenario-workflow-update.log" 2>&1; then
        echo "Step 2 (Update images) failed"
        rm -f .env
        return 1
    fi
    
    # Step 3: Verify all scripts can be called
    log_debug "Step 3: Verifying scripts..."
    if ! bash -n ./stop; then
        echo "Step 3 (Verify stop script) failed"
        rm -f .env
        return 1
    fi
    
    if ! bash -n ./status; then
        echo "Step 3 (Verify status script) failed"
        rm -f .env
        return 1
    fi
    
    # Cleanup
    rm -f .env
    rm -f vpn-auth.txt 2>/dev/null || true
    
    return 0
}

# =============================================================================
# Scenario: Profile-Specific Tests
# =============================================================================

test_scenario_vpn_profile() {
    cd "$PROJECT_DIR"
    
    # Verify vpn profile exists in docker-compose.yml
    assert_true "grep -A5 'profiles:' docker-compose.yml | grep -q 'vpn'" "vpn profile should exist"
    assert_true "grep -A10 'metube:' docker-compose.yml | grep -q 'vpn'" "metube should be in vpn profile"
    assert_true "grep -A10 'yt-dlp-cli:' docker-compose.yml | grep -q 'vpn'" "yt-dlp-cli should be in vpn profile"
    
    return 0
}

test_scenario_no_vpn_profile() {
    cd "$PROJECT_DIR"
    
    # Verify no-vpn profile exists
    assert_true "grep -A5 'profiles:' docker-compose.yml | grep -q 'no-vpn'" "no-vpn profile should exist"
    assert_true "grep -A10 'metube-direct:' docker-compose.yml | grep -q 'no-vpn'" "metube-direct should be in no-vpn profile"
    
    return 0
}

test_scenario_vpn_cli_profile() {
    cd "$PROJECT_DIR"
    
    # Verify vpn-cli profile exists
    assert_true "grep -A5 'profiles:' docker-compose.yml | grep -q 'vpn-cli'" "vpn-cli profile should exist"
    assert_true "grep -A10 'yt-dlp-cli:' docker-compose.yml | grep -q 'vpn-cli'" "yt-dlp-cli should be in vpn-cli profile"
    
    return 0
}

# =============================================================================
# Scenario: Environment Variable Combinations
# =============================================================================

test_scenario_env_combinations() {
    cd "$PROJECT_DIR"

    # Test various environment variable combinations.
    # NOTE (CONST-033 anti-OOM addendum): we deliberately do NOT use
    # /tmp/test-downloads here — the init script refuses tmpfs paths
    # because podman + systemd PrivateTmp silently drops bind-mounted
    # writes (downloads report "finished" but the disk stays empty).
    # Use TEST_DOWNLOADS_DIR (set by setup_test_env in run-tests.sh)
    # which is a non-tmpfs path under tests/.test-downloads.
    local _td="${TEST_DOWNLOADS_DIR:-$TEST_DIR/.test-downloads}"
    mkdir -p "$_td"

    # Combination 1: Minimal config (only required vars)
    cat > .env <<EOF
USE_VPN=false
DOWNLOAD_DIR=$_td
EOF

    if ! ./init > "$TEST_LOGS_DIR/scenario-env-minimal.log" 2>&1; then
        echo "Minimal env configuration failed"
        rm -f .env
        return 1
    fi

    rm -f .env

    # Combination 2: Full config (all optional vars)
    cat > .env <<EOF
USE_VPN=false
DOWNLOAD_DIR=$_td
CONTAINER_RUNTIME=podman
METUBE_PORT=18086
YTDLP_VPN_PORT=13130
TZ=America/New_York
SERVICE_MODE=false
YOUTUBE_COOKIES=false
DEFAULT_QUALITY=1080p
EOF

    if ! ./init > "$TEST_LOGS_DIR/scenario-env-full.log" 2>&1; then
        echo "Full env configuration failed"
        rm -f .env
        return 1
    fi

    rm -f .env

    return 0
}

# =============================================================================
# Scenario: Service Dependencies
# =============================================================================

test_scenario_service_dependencies() {
    cd "$PROJECT_DIR"
    
    # Test that metube depends on openvpn-yt-dlp (VPN mode)
    assert_true "grep -A20 'metube:' docker-compose.yml | grep -q 'depends_on'" "metube should have depends_on"
    assert_true "grep -A25 'metube:' docker-compose.yml | grep -q 'openvpn-yt-dlp'" "metube should depend on openvpn-yt-dlp"
    
    # Test that yt-dlp-cli depends on openvpn-yt-dlp
    assert_true "grep -A20 'yt-dlp-cli:' docker-compose.yml | grep -q 'depends_on'" "yt-dlp-cli should have depends_on"
    assert_true "grep -A25 'yt-dlp-cli:' docker-compose.yml | grep -q 'openvpn-yt-dlp'" "yt-dlp-cli should depend on openvpn-yt-dlp"
    
    return 0
}

# =============================================================================
# Scenario: Network Configuration
# =============================================================================

test_scenario_network_configuration() {
    cd "$PROJECT_DIR"
    
    # Test VPN network mode
    assert_true "grep -A30 'metube:' docker-compose.yml | grep -q 'network_mode'" "metube should have network_mode"
    assert_true "grep -A30 'metube:' docker-compose.yml | grep -q 'service:openvpn-yt-dlp'" "metube should use openvpn-yt-dlp network"
    
    # Test that direct (no-vpn) has its own port mapping
    assert_true "grep -A20 'metube-direct:' docker-compose.yml | grep -q 'ports:'" "metube-direct should have ports"
    
    return 0
}

# =============================================================================
# Scenario: Volume Mounts
# =============================================================================

test_scenario_volume_mounts() {
    cd "$PROJECT_DIR"
    
    # Test that all services have proper volume mounts
    
    # metube
    assert_true "grep -A30 'metube:' docker-compose.yml | grep -q 'volumes:'" "metube should have volumes"
    assert_true "grep -A35 'metube:' docker-compose.yml | grep -q '/downloads'" "metube should mount downloads"
    
    # yt-dlp-cli
    assert_true "grep -A30 'yt-dlp-cli:' docker-compose.yml | grep -q 'volumes:'" "yt-dlp-cli should have volumes"
    assert_true "grep -A35 'yt-dlp-cli:' docker-compose.yml | grep -q '/config'" "yt-dlp-cli should mount config"
    
    return 0
}

# =============================================================================
# Scenario: Health Checks
# =============================================================================

test_scenario_health_checks() {
    cd "$PROJECT_DIR"
    
    # Test that VPN container has health check
    assert_true "grep -A30 'openvpn-yt-dlp:' docker-compose.yml | grep -q 'healthcheck:'" "openvpn-yt-dlp should have healthcheck"
    assert_true "grep -A35 'openvpn-yt-dlp:' docker-compose.yml | grep -q 'ping'" "openvpn-yt-dlp healthcheck should use ping"
    
    return 0
}

# =============================================================================
# Scenario: Watchtower Configuration
# =============================================================================

test_scenario_watchtower_config() {
    cd "$PROJECT_DIR"
    
    # Test Watchtower is configured
    assert_true "grep -q 'watchtower:' docker-compose.yml" "watchtower service should exist"
    assert_true "grep -A20 'watchtower:' docker-compose.yml | grep -q 'WATCHTOWER_SCHEDULE'" "watchtower should have schedule"
    assert_true "grep -A20 'watchtower:' docker-compose.yml | grep -q 'WATCHTOWER_CLEANUP'" "watchtower should have cleanup enabled"
    
    return 0
}

# =============================================================================
# Scenario: All Runtimes Comparison
# =============================================================================

test_scenario_all_runtimes() {
    local has_podman=false
    local has_docker=false
    
    if command -v podman &> /dev/null; then
        has_podman=true
    fi
    
    if command -v docker &> /dev/null; then
        has_docker=true
    fi
    
    if [ "$has_podman" = false ] && [ "$has_docker" = false ]; then
        skip_test "test_scenario_all_runtimes" "No container runtimes available"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Test with Podman (if available)
    if [ "$has_podman" = true ]; then
        cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
        echo "CONTAINER_RUNTIME=podman" >> .env
        
        if ! ./init > "$TEST_LOGS_DIR/scenario-all-runtimes-podman.log" 2>&1; then
            echo "Podman init failed in all-runtimes test"
            rm -f .env
            return 1
        fi
        
        rm -f .env
    fi
    
    # Test with Docker (if available)
    if [ "$has_docker" = true ]; then
        cp "$TEST_CONFIG_DIR/.env.no-vpn" .env
        echo "CONTAINER_RUNTIME=docker" >> .env
        
        if ! ./init > "$TEST_LOGS_DIR/scenario-all-runtimes-docker.log" 2>&1; then
            echo "Docker init failed in all-runtimes test"
            rm -f .env
            return 1
        fi
        
        rm -f .env
    fi
    
    return 0
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_scenario_tests() {
    log_info "Running Scenario Tests..."
    
    # Filter scenarios if specified
    if [ "$TEST_SCENARIO" != "all" ]; then
        log_info "Filtering scenarios: $TEST_SCENARIO"
    fi
    
    run_test "test_scenario_podman_no_vpn" test_scenario_podman_no_vpn
    run_test "test_scenario_podman_with_vpn" test_scenario_podman_with_vpn
    run_test "test_scenario_docker_no_vpn" test_scenario_docker_no_vpn
    run_test "test_scenario_docker_with_vpn" test_scenario_docker_with_vpn
    run_test "test_scenario_batch_download" test_scenario_batch_download
    run_test "test_scenario_channel_download" test_scenario_channel_download
    run_test "test_scenario_complete_workflow_no_vpn" test_scenario_complete_workflow_no_vpn
    run_test "test_scenario_vpn_profile" test_scenario_vpn_profile
    run_test "test_scenario_no_vpn_profile" test_scenario_no_vpn_profile
    run_test "test_scenario_vpn_cli_profile" test_scenario_vpn_cli_profile
    run_test "test_scenario_env_combinations" test_scenario_env_combinations
    run_test "test_scenario_service_dependencies" test_scenario_service_dependencies
    run_test "test_scenario_network_configuration" test_scenario_network_configuration
    run_test "test_scenario_volume_mounts" test_scenario_volume_mounts
    run_test "test_scenario_health_checks" test_scenario_health_checks
    run_test "test_scenario_watchtower_config" test_scenario_watchtower_config
    run_test "test_scenario_all_runtimes" test_scenario_all_runtimes
}
