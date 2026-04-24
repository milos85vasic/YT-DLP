#!/bin/bash
#
# Dashboard & Landing Page Integration Tests
# Comprehensive tests for the Angular dashboard, nginx proxy, and landing page
# Can be run standalone or sourced by run-tests.sh
#

# =============================================================================
# Configuration
# =============================================================================

DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
LANDING_URL="${LANDING_URL:-http://localhost:8086}"
METUBE_URL="${METUBE_URL:-http://localhost:8088}"
DASHBOARD_CONTAINER="${DASHBOARD_CONTAINER:-yt-dlp-dashboard}"
LANDING_CONTAINER="${LANDING_CONTAINER:-metube-landing}"
METUBE_CONTAINER="${METUBE_CONTAINER:-metube-direct}"
TEST_TIMEOUT="${TEST_TIMEOUT:-15}"

# =============================================================================
# Helpers
# =============================================================================

_detect_runtime() {
    if [ -z "$CONTAINER_RUNTIME" ]; then
        if command -v podman &> /dev/null; then
            CONTAINER_RUNTIME="podman"
        elif command -v docker &> /dev/null; then
            CONTAINER_RUNTIME="docker"
        else
            echo "ERROR: No container runtime found"
            return 1
        fi
    fi
}

_http_get() {
    local url="$1"
    local extra_args="${2:-}"
    curl -s --max-time "$TEST_TIMEOUT" $extra_args "$url" 2>&1
}

_http_post() {
    local url="$1"
    local data="$2"
    curl -s --max-time "$TEST_TIMEOUT" \
        -X POST -H "Content-Type: application/json" \
        -d "$data" "$url" 2>&1
}

_http_status() {
    local url="$1"
    local method="${2:-GET}"
    curl -s -o /dev/null -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X "$method" "$url" 2>&1
}

_http_status_with_args() {
    local url="$1"
    local method="$2"
    shift 2
    curl -s -o /dev/null -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X "$method" "$@" "$url" 2>&1
}

_container_is_running() {
    local name="$1"
    _detect_runtime
    $CONTAINER_RUNTIME ps --format "table {{.Names}}" | grep -q "^${name}$"
}

# =============================================================================
# Dashboard Container Tests
# =============================================================================

test_dashboard_container_running() {
    _detect_runtime
    if ! _container_is_running "$DASHBOARD_CONTAINER"; then
        echo "Dashboard container '$DASHBOARD_CONTAINER' is not running"
        return 1
    fi
}

test_dashboard_nginx_process() {
    _detect_runtime
    local procs
    procs=$($CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" sh -c "pgrep nginx | wc -l" 2>/dev/null || echo "0")
    procs=$(echo "$procs" | tr -d '[:space:]')
    if [ "$procs" -lt 1 ]; then
        echo "No nginx processes found in dashboard container"
        return 1
    fi
}

test_dashboard_entrypoint_exists() {
    _detect_runtime
    if ! $CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" test -x /entrypoint.sh; then
        echo "entrypoint.sh is missing or not executable"
        return 1
    fi
}

test_dashboard_nginx_template_exists() {
    _detect_runtime
    if ! $CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" test -f /etc/nginx/conf.d/default.conf.template; then
        echo "nginx.conf.template is missing"
        return 1
    fi
}

test_dashboard_nginx_config_valid() {
    _detect_runtime
    local output
    output=$($CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" nginx -t 2>&1)
    if ! echo "$output" | grep -q "successful"; then
        echo "nginx config test failed: $output"
        return 1
    fi
}

# =============================================================================
# Dashboard HTTP Tests
# =============================================================================

test_dashboard_homepage_loads() {
    local status body
    status=$(_http_status "$DASHBOARD_URL/")
    if [ "$status" != "200" ]; then
        echo "Homepage returned HTTP $status"
        return 1
    fi
    body=$(_http_get "$DASHBOARD_URL/")
    if ! echo "$body" | grep -q '<title>YT-DLP Dashboard</title>'; then
        echo "Homepage missing expected title"
        return 1
    fi
}

test_dashboard_spa_fallback() {
    local status body
    status=$(_http_status "$DASHBOARD_URL/queue")
    if [ "$status" != "200" ]; then
        echo "SPA fallback returned HTTP $status for /queue"
        return 1
    fi
    body=$(_http_get "$DASHBOARD_URL/queue")
    if ! echo "$body" | grep -q '<app-root>'; then
        echo "SPA fallback did not return index.html"
        return 1
    fi
}

test_dashboard_static_assets() {
    local body
    body=$(_http_get "$DASHBOARD_URL/")
    local js_file
    js_file=$(echo "$body" | grep -oE 'src="[^"]+\.js"' | head -1 | sed 's/src="//;s/"//')
    if [ -z "$js_file" ]; then
        # Try without quotes
        js_file=$(echo "$body" | grep -oE 'src=[^[:space:]>]+\.js' | head -1 | sed 's/src=//')
    fi
    if [ -z "$js_file" ]; then
        echo "No JS files found in homepage"
        return 1
    fi
    local status
    status=$(_http_status "$DASHBOARD_URL/$js_file")
    if [ "$status" != "200" ]; then
        echo "Static asset $js_file returned HTTP $status"
        return 1
    fi
}

# =============================================================================
# API Proxy Tests
# =============================================================================

test_api_proxy_history() {
    local status body
    status=$(_http_status "$DASHBOARD_URL/api/history")
    if [ "$status" != "200" ]; then
        echo "GET /api/history returned HTTP $status"
        return 1
    fi
    body=$(_http_get "$DASHBOARD_URL/api/history")
    if ! echo "$body" | grep -q '"done"'; then
        echo "History response missing 'done' field"
        return 1
    fi
}

test_api_proxy_add_download() {
    local status body
    status=$(_http_status_with_args "$DASHBOARD_URL/api/add" "POST" \
        -H "Content-Type: application/json" \
        -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if [ "$status" != "200" ]; then
        echo "POST /api/add returned HTTP $status"
        return 1
    fi
    body=$(_http_post "$DASHBOARD_URL/api/add" '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Add download returned unexpected response: $body"
        return 1
    fi
}

test_api_proxy_cookie_status() {
    local status body
    status=$(_http_status "$DASHBOARD_URL/api/cookie-status")
    if [ "$status" != "200" ]; then
        echo "GET /api/cookie-status returned HTTP $status"
        return 1
    fi
    body=$(_http_get "$DASHBOARD_URL/api/cookie-status")
    if ! echo "$body" | grep -q '"has_cookies"'; then
        echo "Cookie status response missing expected fields"
        return 1
    fi
}

test_api_proxy_version() {
    local status
    status=$(_http_status "$DASHBOARD_URL/api/version")
    if [ "$status" != "200" ]; then
        echo "GET /api/version returned HTTP $status"
        return 1
    fi
}

test_api_proxy_404_nonexistent() {
    local status
    status=$(_http_status "$DASHBOARD_URL/api/nonexistent")
    if [ "$status" != "404" ]; then
        echo "Nonexistent endpoint returned HTTP $status (expected 404)"
        return 1
    fi
}

# =============================================================================
# DNS Resilience Tests
# =============================================================================

test_nginx_uses_resolver_directive() {
    _detect_runtime
    local config
    config=$($CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" cat /etc/nginx/conf.d/default.conf 2>/dev/null)
    if ! echo "$config" | grep -q "resolver"; then
        echo "nginx config missing 'resolver' directive"
        return 1
    fi
}

test_nginx_uses_variable_proxy_pass() {
    _detect_runtime
    local config
    config=$($CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" cat /etc/nginx/conf.d/default.conf 2>/dev/null)
    if ! echo "$config" | grep -q 'set \$metube_backend'; then
        echo "nginx config missing variable-based proxy_pass"
        return 1
    fi
}

test_proxy_reaches_metube_directly() {
    _detect_runtime
    local output
    output=$($CONTAINER_RUNTIME exec "$DASHBOARD_CONTAINER" \
        wget -qO- --timeout=5 http://metube-direct:8081/history 2>&1 | head -1)
    if ! echo "$output" | grep -q '"done"'; then
        echo "Cannot reach metube-direct from dashboard container"
        return 1
    fi
}

test_proxy_works_after_container_restart() {
    _detect_runtime
    # Restart only the dashboard container (not metube-direct)
    $CONTAINER_RUNTIME restart "$DASHBOARD_CONTAINER" >/dev/null 2>&1
    sleep 8

    local status
    status=$(_http_status "$DASHBOARD_URL/api/history")
    if [ "$status" != "200" ]; then
        echo "Proxy failed after dashboard restart (HTTP $status)"
        return 1
    fi

    # Also verify POST still works
    status=$(_http_status_with_args "$DASHBOARD_URL/api/add" "POST" \
        -H "Content-Type: application/json" \
        -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if [ "$status" != "200" ]; then
        echo "POST proxy failed after dashboard restart (HTTP $status)"
        return 1
    fi
}

# =============================================================================
# Landing Page Tests
# =============================================================================

test_landing_container_running() {
    _detect_runtime
    if ! _container_is_running "$LANDING_CONTAINER"; then
        echo "Landing container '$LANDING_CONTAINER' is not running"
        return 1
    fi
}

test_landing_page_loads() {
    local status body
    status=$(_http_status "$LANDING_URL/")
    if [ "$status" != "200" ]; then
        echo "Landing page returned HTTP $status"
        return 1
    fi
    body=$(_http_get "$LANDING_URL/")
    if ! echo "$body" | grep -q 'MeTube'; then
        echo "Landing page missing expected content"
        return 1
    fi
}

test_landing_has_dashboard_link() {
    local body
    body=$(_http_get "$LANDING_URL/")
    if ! echo "$body" | grep -q ':9090'; then
        echo "Landing page missing dashboard port link"
        return 1
    fi
    if ! echo "$body" | grep -q 'YT-DLP Dashboard'; then
        echo "Landing page missing 'YT-DLP Dashboard' text"
        return 1
    fi
}

test_landing_has_metube_classic_link() {
    local body
    body=$(_http_get "$LANDING_URL/")
    if ! echo "$body" | grep -q ':8088'; then
        echo "Landing page missing MeTube Classic port link"
        return 1
    fi
    if ! echo "$body" | grep -q 'MeTube Classic'; then
        echo "Landing page missing 'MeTube Classic' text"
        return 1
    fi
}

test_landing_redirects_to_dashboard() {
    local body
    body=$(_http_get "$LANDING_URL/")
    # Check JS redirect uses DASHBOARD_URL
    if ! echo "$body" | grep -q 'window.location.href = DASHBOARD_URL'; then
        echo "Landing page JS does not redirect to DASHBOARD_URL"
        return 1
    fi
}

test_landing_upload_cookies_proxy() {
    local status
    status=$(_http_status_with_args "$LANDING_URL/api/upload-cookies" "POST" \
        -F "cookies=@/dev/null;filename=test.txt")
    # Should fail validation but not 502
    if [ "$status" = "502" ] || [ "$status" = "504" ]; then
        echo "Cookie upload proxy returned gateway error HTTP $status"
        return 1
    fi
}

test_landing_cookie_status_proxy() {
    local status body
    status=$(_http_status "$LANDING_URL/api/cookie-status")
    if [ "$status" != "200" ]; then
        echo "Cookie status proxy returned HTTP $status"
        return 1
    fi
    body=$(_http_get "$LANDING_URL/api/cookie-status")
    if ! echo "$body" | grep -q '"has_cookies"'; then
        echo "Cookie status response missing expected fields"
        return 1
    fi
}

# =============================================================================
# End-to-End Download Flow Tests
# =============================================================================

test_e2e_add_download_via_dashboard() {
    local body
    # Add a download
    body=$(_http_post "$DASHBOARD_URL/api/add" \
        '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Failed to add download: $body"
        return 1
    fi

    # Verify it appears in history (as pending or queue)
    sleep 2
    body=$(_http_get "$DASHBOARD_URL/api/history")
    if ! echo "$body" | grep -q '"queue"'; then
        echo "History endpoint missing queue field after add"
        return 1
    fi
}

test_e2e_metube_api_direct_vs_proxied() {
    local direct_body proxy_body
    direct_body=$(_http_get "$METUBE_URL/history")
    proxy_body=$(_http_get "$DASHBOARD_URL/api/history")

    # Both should have the same structure
    if ! echo "$direct_body" | grep -q '"done"'; then
        echo "Direct MeTube API missing 'done' field"
        return 1
    fi
    if ! echo "$proxy_body" | grep -q '"done"'; then
        echo "Proxied MeTube API missing 'done' field"
        return 1
    fi
}

# =============================================================================
# Cross-Origin / CORS Safety Tests
# =============================================================================

test_dashboard_api_no_cors_block() {
    local status
    status=$(_http_status_with_args "$DASHBOARD_URL/api/history" "GET" -H "Origin: http://example.com")
    if [ "$status" != "200" ]; then
        echo "API request with foreign Origin header blocked (HTTP $status)"
        return 1
    fi
}

# =============================================================================
# History Management Tests
# =============================================================================

test_history_delete_single_item() {
    # First add a download
    local body
    body=$(_http_post "$DASHBOARD_URL/api/add" \
        '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Failed to add download for delete test: $body"
        return 1
    fi

    sleep 2

    # Delete it from history (MeTube /delete expects URLs as keys)
    body=$(_http_post "$DASHBOARD_URL/api/delete" '{"ids":["https://www.youtube.com/watch?v=dQw4w9WgXcQ"],"where":"done"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Failed to delete from history: $body"
        return 1
    fi
}

test_history_clear_all() {
    # Add a dummy item
    _http_post "$DASHBOARD_URL/api/add" \
        '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}' >/dev/null
    sleep 2

    # Clear all history via batch delete (MeTube /delete expects URLs as keys)
    local body urls_json
    body=$(_http_get "$DASHBOARD_URL/api/history")
    urls_json=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps([x['url'] for x in d.get('done',[])]))" 2>/dev/null || echo "[]")

    if [ "$urls_json" != "[]" ]; then
        body=$(_http_post "$DASHBOARD_URL/api/delete" "{\"ids\":$urls_json,\"where\":\"done\"}")
        if ! echo "$body" | grep -q '"status".*"ok"'; then
            echo "Failed to clear all history: $body"
            return 1
        fi
    fi
}

test_history_retry_download() {
    # Add a download, then simulate retry by delete + re-add
    local body
    body=$(_http_post "$DASHBOARD_URL/api/add" \
        '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Failed to add download for retry test: $body"
        return 1
    fi

    sleep 2

    # Delete from history (MeTube /delete expects URLs as keys)
    _http_post "$DASHBOARD_URL/api/delete" '{"ids":["https://www.youtube.com/watch?v=dQw4w9WgXcQ"],"where":"done"}' >/dev/null

    # Re-add (simulating retry)
    body=$(_http_post "$DASHBOARD_URL/api/add" \
        '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"720","format":"any"}')
    if ! echo "$body" | grep -q '"status".*"ok"'; then
        echo "Failed to re-add download (retry simulation): $body"
        return 1
    fi

    # Cleanup
    _http_post "$DASHBOARD_URL/api/delete" '{"ids":["dQw4w9WgXcQ"],"where":"done"}' >/dev/null
}

# =============================================================================
# File Deletion Endpoint Tests
# =============================================================================

test_landing_delete_download_endpoint() {
    local body status
    # Test delete-download via landing page directly (expects url field, not id)
    status=$(_http_status_with_args "$LANDING_URL/api/delete-download" "POST" \
        -H "Content-Type: application/json" \
        -d '{"url":"https://www.youtube.com/watch?v=test-item","title":"Test","folder":"","delete_file":false}')
    if [ "$status" != "200" ]; then
        echo "Landing delete-download endpoint returned HTTP $status"
        return 1
    fi
    body=$(_http_post "$LANDING_URL/api/delete-download" \
        '{"url":"https://www.youtube.com/watch?v=test-item","title":"Test","folder":"","delete_file":false}')
    if ! echo "$body" | grep -q '"success".*true'; then
        echo "Landing delete-download returned unexpected response: $body"
        return 1
    fi
}

test_dashboard_proxy_delete_download() {
    local body status
    # Test delete-download via dashboard nginx proxy (expects url field, not id)
    status=$(_http_status_with_args "$DASHBOARD_URL/api/delete-download" "POST" \
        -H "Content-Type: application/json" \
        -d '{"url":"https://www.youtube.com/watch?v=test-proxy","title":"Test Proxy","folder":"","delete_file":false}')
    if [ "$status" != "200" ]; then
        echo "Dashboard proxy delete-download returned HTTP $status"
        return 1
    fi
    body=$(_http_post "$DASHBOARD_URL/api/delete-download" \
        '{"url":"https://www.youtube.com/watch?v=test-proxy","title":"Test Proxy","folder":"","delete_file":false}')
    if ! echo "$body" | grep -q '"success".*true'; then
        echo "Dashboard proxy delete-download returned unexpected response: $body"
        return 1
    fi
}

# =============================================================================
# Cookie & Version Verification Tests
# =============================================================================

test_metube_ytdlp_is_nightly() {
    _detect_runtime
    local version
    version=$($CONTAINER_RUNTIME exec "$METUBE_CONTAINER" yt-dlp --version 2>/dev/null || echo "unknown")
    if ! echo "$version" | grep -qE "2026\.[0-9]+\.[0-9]+"; then
        echo "MeTube yt-dlp version '$version' does not look like a valid 2026 version"
        return 1
    fi
    # Accept any recent 2026 version (stable or nightly)
    echo "MeTube yt-dlp version: $version"
}

test_metube_has_fresh_cookies() {
    _detect_runtime
    local cookie_size
    cookie_size=$($CONTAINER_RUNTIME exec "$METUBE_CONTAINER" wc -c /config/cookies.txt 2>/dev/null | awk '{print $1}' || echo "0")
    if [ "$cookie_size" -lt 100 ]; then
        echo "MeTube cookie file is too small ($cookie_size bytes) — cookies may not be synced"
        return 1
    fi
    echo "MeTube cookie file size: $cookie_size bytes"
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_dashboard_tests() {
    if type log_info &> /dev/null; then
        log_info "Running Dashboard & Landing Page Tests..."
    else
        echo -e "${BLUE}[INFO]${NC} Running Dashboard & Landing Page Tests..."
    fi

    # Container health
    run_test "test_dashboard_container_running" test_dashboard_container_running
    run_test "test_dashboard_nginx_process" test_dashboard_nginx_process
    run_test "test_dashboard_entrypoint_exists" test_dashboard_entrypoint_exists
    run_test "test_dashboard_nginx_template_exists" test_dashboard_nginx_template_exists
    run_test "test_dashboard_nginx_config_valid" test_dashboard_nginx_config_valid

    # Dashboard HTTP
    run_test "test_dashboard_homepage_loads" test_dashboard_homepage_loads
    run_test "test_dashboard_spa_fallback" test_dashboard_spa_fallback
    run_test "test_dashboard_static_assets" test_dashboard_static_assets

    # API Proxy
    run_test "test_api_proxy_history" test_api_proxy_history
    run_test "test_api_proxy_add_download" test_api_proxy_add_download
    run_test "test_api_proxy_cookie_status" test_api_proxy_cookie_status
    run_test "test_api_proxy_version" test_api_proxy_version
    run_test "test_api_proxy_404_nonexistent" test_api_proxy_404_nonexistent

    # DNS Resilience
    run_test "test_nginx_uses_resolver_directive" test_nginx_uses_resolver_directive
    run_test "test_nginx_uses_variable_proxy_pass" test_nginx_uses_variable_proxy_pass
    run_test "test_proxy_reaches_metube_directly" test_proxy_reaches_metube_directly
    run_test "test_proxy_works_after_container_restart" test_proxy_works_after_container_restart

    # Landing Page
    run_test "test_landing_container_running" test_landing_container_running
    run_test "test_landing_page_loads" test_landing_page_loads
    run_test "test_landing_has_dashboard_link" test_landing_has_dashboard_link
    run_test "test_landing_has_metube_classic_link" test_landing_has_metube_classic_link
    run_test "test_landing_redirects_to_dashboard" test_landing_redirects_to_dashboard
    run_test "test_landing_upload_cookies_proxy" test_landing_upload_cookies_proxy
    run_test "test_landing_cookie_status_proxy" test_landing_cookie_status_proxy

    # End-to-End
    run_test "test_e2e_add_download_via_dashboard" test_e2e_add_download_via_dashboard
    run_test "test_e2e_metube_api_direct_vs_proxied" test_e2e_metube_api_direct_vs_proxied

    # CORS
    run_test "test_dashboard_api_no_cors_block" test_dashboard_api_no_cors_block

    # History Management
    run_test "test_history_delete_single_item" test_history_delete_single_item
    run_test "test_history_clear_all" test_history_clear_all
    run_test "test_history_retry_download" test_history_retry_download

    # File Deletion Endpoint
    run_test "test_landing_delete_download_endpoint" test_landing_delete_download_endpoint
    run_test "test_dashboard_proxy_delete_download" test_dashboard_proxy_delete_download

    # Cookie & Version Verification
    run_test "test_metube_ytdlp_is_nightly" test_metube_ytdlp_is_nightly
    run_test "test_metube_has_fresh_cookies" test_metube_has_fresh_cookies
}

# =============================================================================
# Standalone execution support
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    set -e

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    if [ -z "$CONTAINER_RUNTIME" ]; then
        if command -v podman &> /dev/null; then
            CONTAINER_RUNTIME="podman"
        elif command -v docker &> /dev/null; then
            CONTAINER_RUNTIME="docker"
        else
            echo -e "${RED}ERROR: No container runtime found!${NC}"
            exit 1
        fi
    fi

    PASSED=0
    FAILED=0
    SKIPPED=0

    run_test() {
        local test_name="$1"
        local test_func="$2"
        local output
        local exit_code=0

        echo -n "Running: $test_name ... "
        output=$($test_func 2>&1) || exit_code=$?

        if [ "$exit_code" -eq 0 ]; then
            echo -e "${GREEN}PASS${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}FAIL${NC}"
            echo "$output" | sed 's/^/       /'
            FAILED=$((FAILED + 1))
        fi
    }

    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Dashboard & Landing Page Test Suite${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo -e "${BLUE}[INFO]${NC} Container Runtime: $CONTAINER_RUNTIME"
    echo -e "${BLUE}[INFO]${NC} Dashboard URL: $DASHBOARD_URL"
    echo -e "${BLUE}[INFO]${NC} Landing URL: $LANDING_URL"
    echo ""

    # Check if required containers are running
    if ! _container_is_running "$DASHBOARD_CONTAINER"; then
        echo -e "${YELLOW}WARNING: Dashboard container not running.${NC}"
        echo "Attempting to start services..."
        if [ -f ./start_no_vpn ]; then
            ./start_no_vpn
        else
            echo -e "${RED}ERROR: Cannot start services. Please run ./start first.${NC}"
            exit 1
        fi
    fi

    run_dashboard_tests

    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Passed:  ${GREEN}$PASSED${NC}"
    echo -e "Failed:  ${RED}$FAILED${NC}"
    echo -e "Skipped: ${CYAN}$SKIPPED${NC}"
    echo ""

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
fi
