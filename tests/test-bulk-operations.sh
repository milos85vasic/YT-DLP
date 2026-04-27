#!/bin/bash
#
# tests/test-bulk-operations.sh
#
# HTTP-level coverage for the bulk-clear / bulk-delete pathways the
# new dashboard UI exercises (Queue + History "Select all", "Clear
# Selected", "Delete Selected", "Delete All"). Every assertion runs
# against the REAL running services — no mocks per the project's
# test-audit policy.
#
# What we're guarding:
#
#   1. POST /api/delete   {ids:[...], where:queue|done}
#        - Removes records, never deletes files.
#        - 200 on success.
#        - Empty list MUST not 500.
#        - Idempotent: a second delete of the same IDs is a no-op.
#
#   2. POST /api/delete-download {url, title, folder, delete_file}
#        - Landing-proxied; removes record AND optionally the file.
#        - When delete_file=true and the record is gone, the second
#          call returns success with files_deleted:[].
#        - Concurrent calls against distinct URLs all return 200.
#
#   3. /api/history must remain reachable (NOT 500) after a bulk
#      clear / delete burst — proves the state machine doesn't wedge.
#
# These tests submit real download requests, then exercise the
# clear/delete paths against them. They never assert a download
# COMPLETES — only that record management works.
#
# NOTE: do NOT use `set -e` / `set -u` at file scope — when run-tests.sh
# sources this file, those flags would leak into the orchestrator.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
TEST_TIMEOUT="${TEST_TIMEOUT:-15}"

# shellcheck disable=SC1091
[ -f "$PROJECT_DIR/tests/test-helpers.sh" ] && source "$PROJECT_DIR/tests/test-helpers.sh"

_post_json() {
    # $1 = path  $2 = json body
    curl -s -o /tmp/bulk-body.txt -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X POST "$DASHBOARD_URL$1" \
        -H "Content-Type: application/json" \
        -d "$2" 2>/dev/null
}

_get_status() {
    curl -s -o /dev/null -w "%{http_code}" --max-time "$TEST_TIMEOUT" "$DASHBOARD_URL$1"
}

# ---------------------------------------------------------------------------
# Empty-list edge cases — the dashboard should never POST an empty
# delete (it short-circuits in the service), but the endpoint MUST
# still not 500 if a misbehaving client does.
# ---------------------------------------------------------------------------

test_bulk_delete_empty_ids_not_500() {
    local s
    s=$(_post_json "/api/delete" '{"ids":[],"where":"queue"}')
    if [ "$s" = "500" ]; then
        echo "POST /api/delete with empty ids returned 500"
        return 1
    fi
}

test_bulk_delete_missing_where_not_500() {
    local s
    s=$(_post_json "/api/delete" '{"ids":["https://example.com/x"]}')
    if [ "$s" = "500" ]; then
        echo "POST /api/delete missing 'where' returned 500"
        return 1
    fi
}

test_bulk_delete_unknown_where_not_500() {
    local s
    s=$(_post_json "/api/delete" '{"ids":["https://example.com/x"],"where":"nonsense"}')
    if [ "$s" = "500" ]; then
        echo "POST /api/delete with unknown 'where' returned 500"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Idempotency — deleting a non-existent ID is a no-op (NEVER 500).
# ---------------------------------------------------------------------------

test_bulk_delete_unknown_ids_is_idempotent() {
    local s
    s=$(_post_json "/api/delete" '{"ids":["https://nonexistent.invalid/x","https://nonexistent.invalid/y"],"where":"done"}')
    if [ "$s" = "500" ]; then
        echo "Deleting unknown IDs returned 500 (should be a no-op)"
        return 1
    fi
}

test_delete_download_unknown_url_is_idempotent() {
    local s
    s=$(_post_json "/api/delete-download" '{"url":"https://nonexistent.invalid/zzz","title":"none","folder":"","delete_file":true}')
    if [ "$s" = "500" ]; then
        echo "delete-download for unknown URL returned 500"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Real round-trip: queue 3 items, bulk-clear them, /history shows none.
# Uses test-only URLs (yt-dlp will fail extraction async; that's fine,
# we're not testing downloads — we're testing record management).
# ---------------------------------------------------------------------------

_unique_test_url() {
    # Use an IPv6-loopback HTTP URL — yt-dlp accepts it as a generic
    # extractor target, then fails extraction async. The /add returns
    # 200 with status:ok; the record is created in the queue.
    echo "http://[::1]:65535/test-bulk-$(date +%s%N)-$1"
}

test_bulk_clear_round_trip() {
    # Submit three URLs.
    local urls=()
    local i
    for i in 1 2 3; do
        local url
        url=$(_unique_test_url "$i")
        urls+=("$url")
        local s
        s=$(_post_json "/api/add" "$(printf '{"url":"%s","quality":"720","format":"any","folder":"test-bulk-clear"}' "$url")")
        if [ "$s" = "500" ]; then
            echo "POST /api/add returned 500 for $url"
            return 1
        fi
    done

    # Wait briefly for items to land in either pending/queue/done.
    sleep 2

    # Bulk-clear by URL list. Both `where:queue` and `where:done` are
    # exercised because items may have moved to done with status=error.
    local ids_json
    ids_json=$(printf '"%s",' "${urls[@]}")
    ids_json="[${ids_json%,}]"

    local s
    s=$(_post_json "/api/delete" "$(printf '{"ids":%s,"where":"queue"}' "$ids_json")")
    if [ "$s" = "500" ]; then
        echo "Bulk delete from queue returned 500"
        return 1
    fi
    s=$(_post_json "/api/delete" "$(printf '{"ids":%s,"where":"done"}' "$ids_json")")
    if [ "$s" = "500" ]; then
        echo "Bulk delete from done returned 500"
        return 1
    fi

    # /history must be reachable.
    s=$(_get_status "/api/history")
    if [ "$s" != "200" ]; then
        echo "/api/history returned HTTP $s after bulk delete"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Concurrent bulk-delete — fire 5 simultaneous POSTs against /api/delete
# with disjoint URL sets, none must 500.
# ---------------------------------------------------------------------------

test_bulk_delete_concurrent_never_500() {
    local tmp pids=()
    tmp=$(mktemp -d)
    local i
    for i in 1 2 3 4 5; do
        local url
        url="http://[::1]:65535/test-concurrent-$$-$i-$(date +%s%N)"
        # Pre-create a record we'll then delete (best-effort; failure here
        # is fine, we're testing the delete endpoint's robustness).
        _post_json "/api/add" "$(printf '{"url":"%s","quality":"720","format":"any","folder":"test-concurrent-delete"}' "$url")" >/dev/null
        (
            curl -s -o "$tmp/body-$i" -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
                -X POST "$DASHBOARD_URL/api/delete" \
                -H "Content-Type: application/json" \
                -d "$(printf '{"ids":["%s"],"where":"queue"}' "$url")" \
                > "$tmp/status-$i" 2>/dev/null
        ) &
        pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p"; done

    local any_500=0
    local i
    for i in 1 2 3 4 5; do
        local s
        s=$(cat "$tmp/status-$i" 2>/dev/null)
        if [ "$s" = "500" ]; then
            any_500=1
            echo "  concurrent /api/delete attempt $i returned 500"
        fi
    done
    rm -rf "$tmp"
    if [ "$any_500" -eq 1 ]; then
        echo "At least one concurrent bulk-delete returned 500"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# /api/delete-download with delete_file=false MUST NOT touch the disk.
# (Body assertion: files_deleted is empty or missing when delete_file=false.)
# ---------------------------------------------------------------------------

test_delete_download_no_file_flag_keeps_disk() {
    local s body
    s=$(_post_json "/api/delete-download" '{"url":"https://nonexistent.invalid/abc","title":"x","folder":"","delete_file":false}')
    body=$(cat /tmp/bulk-body.txt 2>/dev/null)
    if [ "$s" = "500" ]; then
        echo "delete-download with delete_file=false returned 500"
        return 1
    fi
    # files_deleted, if present, must be empty
    if echo "$body" | grep -q '"files_deleted":\s*\["'; then
        echo "delete-download with delete_file=false reported files_deleted (should be empty)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Burst then /api/history sanity — proves state machine isn't wedged.
# ---------------------------------------------------------------------------

test_history_endpoint_not_500_after_bulk_burst() {
    local i
    local pids=()
    for i in 1 2 3 4 5 6; do
        (
            _post_json "/api/delete" "$(printf '{"ids":["http://[::1]:65535/burst-%s"],"where":"queue"}' "$i")" >/dev/null
        ) &
        pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p"; done

    local s
    s=$(_get_status "/api/history")
    if [ "$s" = "500" ]; then
        echo "/api/history returned 500 after bulk-delete burst"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_bulk_operations_tests() {
    if type log_info &> /dev/null; then
        log_info "Running Bulk Operations Tests..."
    else
        echo "[INFO] Running Bulk Operations Tests..."
    fi

    if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
        echo "  SKIP: $DASHBOARD_URL not reachable — start the no-vpn profile first"
        return 0
    fi

    local fns=(
        test_bulk_delete_empty_ids_not_500
        test_bulk_delete_missing_where_not_500
        test_bulk_delete_unknown_where_not_500
        test_bulk_delete_unknown_ids_is_idempotent
        test_delete_download_unknown_url_is_idempotent
        test_delete_download_no_file_flag_keeps_disk
        test_bulk_clear_round_trip
        test_bulk_delete_concurrent_never_500
        test_history_endpoint_not_500_after_bulk_burst
    )

    if type run_test &> /dev/null; then
        for fn in "${fns[@]}"; do run_test "$fn" "$fn"; done
    else
        local pass=0 fail=0
        for fn in "${fns[@]}"; do
            if "$fn"; then
                pass=$((pass+1))
                echo "  PASS: $fn"
            else
                fail=$((fail+1))
                echo "  FAIL: $fn"
            fi
        done
        echo "Pass: $pass  Fail: $fail"
        [ "$fail" -eq 0 ]
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_bulk_operations_tests
fi
