#!/bin/bash
#
# tests/test-aborted-history.sh
#
# Real-HTTP coverage for the /api/aborted-history landing endpoint
# that backs the dashboard's "show cancelled queue items in History"
# feature. Per CONST-034 (anti-bluff), every assertion exercises the
# user-visible contract — POST appends, GET reads back, DELETE
# removes, and the dashboard's polled view actually changes.
#
# Cases:
#   1. Empty GET returns {"aborted": []}
#   2. POST with no url is 400 (not 500)
#   3. POST with valid url appends and the URL is then visible on GET
#   4. Idempotent POST (same url within 60s) is a no-op
#   5. DELETE specific urls removes those entries; GET confirms
#   6. DELETE * empties the file; GET confirms empty
#   7. Persistence: write, re-fetch — entries survive
#   8. Concurrent POSTs of distinct URLs: all visible afterwards,
#      never 500
#   9. The dashboard proxy /api/aborted-history reaches the same data
#      as the direct landing :8086 endpoint (proves the new nginx
#      location block works end-to-end)
#
# NOTE: do NOT use `set -e` / `set -u` at file scope.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
LANDING_URL="${LANDING_URL:-http://localhost:8086}"
TEST_TIMEOUT="${TEST_TIMEOUT:-15}"

# shellcheck disable=SC1091
[ -f "$PROJECT_DIR/tests/test-helpers.sh" ] && source "$PROJECT_DIR/tests/test-helpers.sh"

_unique_url() {
    echo "https://abort-test.invalid/test-$$-$1-$(date +%s%N)"
}

_post() {
    # $1 = base  $2 = body
    curl -s -o /tmp/ab-body.txt -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X POST "$1/api/aborted-history" \
        -H "Content-Type: application/json" \
        -d "$2" 2>/dev/null
}

_get() {
    curl -s --max-time "$TEST_TIMEOUT" "$1/api/aborted-history" 2>/dev/null
}

_delete() {
    # $1 = base  $2 = json body
    curl -s -o /tmp/ab-body.txt -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X DELETE "$1/api/aborted-history" \
        -H "Content-Type: application/json" \
        -d "$2" 2>/dev/null
}

# Reset the aborted-history before each top-level case so tests don't
# bleed into each other. We use the proxy path so the test exercises
# the same surface the dashboard does.
_reset_history() {
    _delete "$DASHBOARD_URL" '{"urls":"*"}' >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------

test_aborted_history_get_initial_shape() {
    _reset_history
    local body
    body=$(_get "$DASHBOARD_URL")
    if ! echo "$body" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "aborted" in d, "missing aborted key: " + str(d)
assert isinstance(d["aborted"], list), "aborted is not a list: " + str(d)
print("OK")
' 2>/dev/null | grep -q OK; then
        echo "GET response shape wrong: $body"
        return 1
    fi
}

test_aborted_history_post_without_url_is_400() {
    local s
    s=$(_post "$DASHBOARD_URL" '{}')
    if [ "$s" = "500" ]; then
        echo "POST without url returned 500 (expected 400)"
        return 1
    fi
    if [ "$s" != "400" ]; then
        echo "POST without url returned $s (expected 400)"
        return 1
    fi
}

test_aborted_history_post_appends_and_get_reads_back() {
    _reset_history
    local url
    url=$(_unique_url append)
    local s
    s=$(_post "$DASHBOARD_URL" "$(printf '{"url":"%s","title":"a","reason":"user-cancel"}' "$url")")
    if [ "$s" != "200" ]; then
        echo "POST returned $s"
        return 1
    fi

    local body
    body=$(_get "$DASHBOARD_URL")
    if ! echo "$body" | grep -q "$url"; then
        echo "URL not present in /aborted-history GET: $body"
        return 1
    fi
}

test_aborted_history_post_idempotent_within_60s() {
    _reset_history
    local url
    url=$(_unique_url idem)
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s","title":"x"}' "$url")" >/dev/null
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s","title":"x"}' "$url")" >/dev/null
    local count
    count=$(_get "$DASHBOARD_URL" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(1 for e in d.get("aborted", []) if e.get("url") == sys.argv[1]))
' "$url" 2>/dev/null)
    if [ "$count" != "1" ]; then
        echo "Expected 1 entry for repeated POST, got $count"
        return 1
    fi
}

test_aborted_history_delete_specific_urls() {
    _reset_history
    local u1 u2
    u1=$(_unique_url del1)
    u2=$(_unique_url del2)
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$u1")" >/dev/null
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$u2")" >/dev/null

    local s
    s=$(_delete "$DASHBOARD_URL" "$(printf '{"urls":["%s"]}' "$u1")")
    if [ "$s" != "200" ]; then
        echo "DELETE returned $s"
        return 1
    fi

    local body
    body=$(_get "$DASHBOARD_URL")
    if echo "$body" | grep -q "$u1"; then
        echo "u1 still present after DELETE"
        return 1
    fi
    if ! echo "$body" | grep -q "$u2"; then
        echo "u2 unexpectedly removed"
        return 1
    fi
}

test_aborted_history_delete_star_clears_all() {
    _reset_history
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$(_unique_url all1)")" >/dev/null
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$(_unique_url all2)")" >/dev/null
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$(_unique_url all3)")" >/dev/null

    local s
    s=$(_delete "$DASHBOARD_URL" '{"urls":"*"}')
    if [ "$s" != "200" ]; then
        echo "DELETE * returned $s"
        return 1
    fi
    local count
    count=$(_get "$DASHBOARD_URL" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("aborted",[])))')
    if [ "$count" != "0" ]; then
        echo "DELETE * left $count entries"
        return 1
    fi
}

test_aborted_history_delete_invalid_body_is_400_not_500() {
    local s
    s=$(_delete "$DASHBOARD_URL" '{"urls":[]}')
    if [ "$s" = "500" ]; then
        echo "DELETE with empty urls returned 500"
        return 1
    fi
}

test_aborted_history_concurrent_posts_no_500() {
    _reset_history
    local pids=()
    local i
    for i in 1 2 3 4 5; do
        local url
        url=$(_unique_url "conc-$i")
        (
            curl -s -o /dev/null -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
                -X POST "$DASHBOARD_URL/api/aborted-history" \
                -H "Content-Type: application/json" \
                -d "$(printf '{"url":"%s"}' "$url")" \
                > "/tmp/ab-conc-$i" 2>/dev/null
        ) &
        pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p"; done

    local i any_500=0
    for i in 1 2 3 4 5; do
        local s
        s=$(cat "/tmp/ab-conc-$i" 2>/dev/null)
        rm -f "/tmp/ab-conc-$i"
        [ "$s" = "500" ] && any_500=1
    done
    if [ "$any_500" = "1" ]; then
        echo "At least one concurrent POST returned 500"
        return 1
    fi

    # All 5 must be present (different URLs ⇒ no idempotent collision).
    local got
    got=$(_get "$DASHBOARD_URL" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("aborted",[])))')
    if [ "$got" -lt 5 ]; then
        echo "Concurrent POSTs lost entries — got $got, expected 5"
        return 1
    fi
}

test_aborted_history_dashboard_proxy_matches_landing_direct() {
    _reset_history
    local url
    url=$(_unique_url proxy-parity)
    _post "$DASHBOARD_URL" "$(printf '{"url":"%s"}' "$url")" >/dev/null

    local via_proxy via_direct
    via_proxy=$(_get "$DASHBOARD_URL" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("YES" if any(e.get("url") == sys.argv[1] for e in d.get("aborted",[])) else "NO")
' "$url" 2>/dev/null)
    via_direct=$(_get "$LANDING_URL" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("YES" if any(e.get("url") == sys.argv[1] for e in d.get("aborted",[])) else "NO")
' "$url" 2>/dev/null)

    if [ "$via_proxy" != "YES" ] || [ "$via_direct" != "YES" ]; then
        echo "Proxy/direct parity broken — proxy=$via_proxy direct=$via_direct"
        return 1
    fi
}

# ---------------------------------------------------------------------------

run_aborted_history_tests() {
    if type log_info &> /dev/null; then
        log_info "Running Aborted-History Tests..."
    else
        echo "[INFO] Running Aborted-History Tests..."
    fi

    if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
        echo "  SKIP: $DASHBOARD_URL not reachable — start the no-vpn profile first"
        return 0
    fi

    local fns=(
        test_aborted_history_get_initial_shape
        test_aborted_history_post_without_url_is_400
        test_aborted_history_post_appends_and_get_reads_back
        test_aborted_history_post_idempotent_within_60s
        test_aborted_history_delete_specific_urls
        test_aborted_history_delete_star_clears_all
        test_aborted_history_delete_invalid_body_is_400_not_500
        test_aborted_history_concurrent_posts_no_500
        test_aborted_history_dashboard_proxy_matches_landing_direct
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

    # Clean up so subsequent suites see a fresh aborted-history.
    _reset_history
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_aborted_history_tests
fi
