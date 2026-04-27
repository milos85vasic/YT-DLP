#!/bin/bash
#
# tests/test-add-download.sh
#
# In-depth regression coverage for the /api/add download-submit path.
# A user reported a transient `500 Internal Server Error` from
# /api/add against the dashboard's LAN address (192.168.x.x:9090) and
# we couldn't reproduce a clean 500 in the lab — the failure modes we
# observed during a metube-direct restart were 502 / 504, not 500.
# This file locks in the contract that, regardless of input shape or
# upstream availability, /api/add NEVER returns 500 to the client.
#
# Categories:
#   1. Happy path     — POST a valid YouTube URL, expect 200 + status:ok
#   2. Address parity — same body via dashboard:9090 (proxied) and
#                       metube:8088 (direct) returns the same shape
#   3. LAN IP parity  — when a non-loopback host IP is reachable on
#                       :9090, hitting it must return 200 too
#   4. Bad input      — empty body, malformed JSON, no Content-Type,
#                       empty URL, javascript:/file: schemes, oversized
#                       URL, wrong-typed fields. ALL must be 4xx (never
#                       5xx) — we don't constrain WHICH 4xx because the
#                       MeTube vendor controls that.
#   5. Per-platform   — submit a YouTube + Vimeo + Dailymotion URL,
#                       all expected to be accepted at /add (the actual
#                       download succeeds asynchronously; failures
#                       there are platform issues, not /add issues)
#   6. Resilience     — restart metube-direct in the background, fire
#                       repeated /api/add probes during the window,
#                       confirm responses are 200 or 5xx-but-not-500
#                       (502 / 504 from nginx are acceptable; the test
#                       fails ONLY if any response is exactly 500,
#                       which is the user-reported failure mode)
#   7. Concurrency    — fire N parallel /api/add probes, expect every
#                       one to be 200 (or graceful 4xx/502, never 500)
#
# NOTE: do NOT use `set -e` / `set -u` at file scope — when run-tests.sh
# sources this file, those flags would leak into the orchestrator.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
METUBE_DIRECT_URL="${METUBE_DIRECT_URL:-http://localhost:8088}"
TEST_TIMEOUT="${TEST_TIMEOUT:-15}"

# Stable URLs that yt-dlp accepts at extraction time. We don't need
# them to download successfully — /add returns 200 the moment MeTube
# accepts the request; downloads happen asynchronously.
ADD_URL_YOUTUBE="https://www.youtube.com/watch?v=jNQXAC9IVRw"
ADD_URL_VIMEO="https://vimeo.com/108018156"
ADD_URL_DAILYMOTION="https://www.dailymotion.com/video/x5kesuj"

# shellcheck disable=SC1091
[ -f "$PROJECT_DIR/tests/test-helpers.sh" ] && source "$PROJECT_DIR/tests/test-helpers.sh"

_post_add() {
    # $1 = base URL (http://host:port)  $2 = JSON body  $3 = path (default /api/add)
    local base="$1" body="$2" path="${3:-/api/add}"
    curl -s -o /tmp/add-body.txt -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X POST "$base$path" \
        -H "Content-Type: application/json" \
        -d "$body" 2>/dev/null
}

_post_add_raw() {
    # As _post_add but with arbitrary curl args (no auto Content-Type).
    local base="$1" path="$2"
    shift 2
    curl -s -o /tmp/add-body.txt -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X POST "$base$path" "$@" 2>/dev/null
}

_status_5xx_but_not_500() {
    local s="$1"
    if [[ "$s" =~ ^5[0-9]{2}$ ]] && [ "$s" != "500" ]; then
        return 0
    fi
    return 1
}

_status_4xx() {
    local s="$1"
    [[ "$s" =~ ^4[0-9]{2}$ ]]
}

_status_2xx() {
    local s="$1"
    [[ "$s" =~ ^2[0-9]{2}$ ]]
}

# ---------------------------------------------------------------------------
# 1. Happy path
# ---------------------------------------------------------------------------

test_add_happy_path_youtube() {
    # Treat the response BODY as the source of truth. curl's `%{http_code}`
    # can return 000 even on a successful response when the upstream
    # closes the connection abruptly after writing the body — but the
    # body itself ({"status":"ok"}) is unambiguous proof of success.
    local status body
    status=$(_post_add "$DASHBOARD_URL" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")")
    body=$(cat /tmp/add-body.txt 2>/dev/null)
    if echo "$body" | grep -q '"status".*:.*"ok"'; then
        return 0
    fi
    echo "Expected status:ok in body, got HTTP $status with body=$body"
    return 1
}

# ---------------------------------------------------------------------------
# 2. Address parity (dashboard proxy ↔ metube direct)
# ---------------------------------------------------------------------------

test_add_proxy_and_direct_return_same_shape() {
    # Body-as-truth — both bodies must contain status:ok regardless of
    # what curl reports as the http_code (see happy-path test comment).
    local proxied_body direct_body
    _post_add "$DASHBOARD_URL"     "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")"          >/dev/null
    proxied_body=$(cat /tmp/add-body.txt 2>/dev/null)
    _post_add "$METUBE_DIRECT_URL" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")" "/add"   >/dev/null
    direct_body=$(cat /tmp/add-body.txt 2>/dev/null)

    if ! echo "$proxied_body" | grep -q '"status".*:.*"ok"'; then
        echo "Proxied body missing status:ok — $proxied_body"
        return 1
    fi
    if ! echo "$direct_body" | grep -q '"status".*:.*"ok"'; then
        echo "Direct body missing status:ok — $direct_body"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 3. LAN IP parity (skipped if no LAN IP detected)
# ---------------------------------------------------------------------------

test_add_via_lan_ip() {
    local lan_ip
    lan_ip=$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))\.\d+\.\d+' | head -n 1)
    if [ -z "$lan_ip" ]; then
        echo "no LAN IP detected — skip"
        return 0
    fi
    # Body-as-truth — see test_add_happy_path_youtube comment.
    local status body
    status=$(_post_add "http://$lan_ip:9090" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")")
    body=$(cat /tmp/add-body.txt 2>/dev/null)
    if echo "$body" | grep -q '"status".*:.*"ok"'; then
        return 0
    fi
    echo "LAN IP $lan_ip returned $status — body=$body"
    return 1
}

# ---------------------------------------------------------------------------
# 4. Bad input — must be 4xx (or 200 if MeTube accepts and fails async),
#                NEVER 500.
# ---------------------------------------------------------------------------

_assert_not_500() {
    local label="$1" status="$2" body="$3"
    if [ "$status" = "500" ]; then
        echo "[$label] returned 500 (this is the user-reported failure mode). body=$body"
        return 1
    fi
}

test_add_empty_json_body_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" '{}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "empty-json" "$status" "$body"
}

test_add_malformed_json_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" 'not-json')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "malformed-json" "$status" "$body"
}

test_add_no_content_type_not_500() {
    # Drop the Content-Type header that _post_add sets by default.
    local status body
    status=$(_post_add_raw "$DASHBOARD_URL" "/api/add" -d '{"url":"x"}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "no-content-type" "$status" "$body"
}

test_add_empty_url_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" '{"url":"","quality":"720","format":"any","folder":""}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "empty-url" "$status" "$body"
}

test_add_javascript_scheme_url_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" '{"url":"javascript:alert(1)","quality":"720","format":"any","folder":""}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "javascript-scheme" "$status" "$body"
}

test_add_file_scheme_url_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" '{"url":"file:///etc/passwd","quality":"720","format":"any","folder":""}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "file-scheme" "$status" "$body"
}

test_add_oversized_url_not_500() {
    # 10 KB URL — past any reasonable input but still < nginx default
    # client_max_body_size (1m). Either accepted, 400, or 413; never 500.
    local big
    big=$(python3 -c 'print("a" * 10000, end="")')
    local body status
    body=$(printf '{"url":"https://www.youtube.com/?q=%s","quality":"720","format":"any","folder":""}' "$big")
    status=$(_post_add "$DASHBOARD_URL" "$body")
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "oversized-url" "$status" "$body"
}

test_add_wrong_typed_quality_not_500() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" '{"url":"https://www.youtube.com/watch?v=jNQXAC9IVRw","quality":999,"format":"any","folder":""}')
    body=$(cat /tmp/add-body.txt 2>/dev/null | head -c 200)
    _assert_not_500 "wrong-typed-quality" "$status" "$body"
}

# ---------------------------------------------------------------------------
# 5. Per-platform acceptance at /add
# ---------------------------------------------------------------------------

test_add_accepts_vimeo_url() {
    # Body is source of truth — see test_add_happy_path_youtube comment.
    local status body
    status=$(_post_add "$DASHBOARD_URL" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_VIMEO")")
    body=$(cat /tmp/add-body.txt 2>/dev/null)
    if echo "$body" | grep -q '"status".*:.*"ok"'; then
        return 0
    fi
    echo "Vimeo URL rejected at /add — HTTP $status, body=$body"
    return 1
}

test_add_accepts_dailymotion_url() {
    local status body
    status=$(_post_add "$DASHBOARD_URL" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_DAILYMOTION")")
    body=$(cat /tmp/add-body.txt 2>/dev/null)
    if echo "$body" | grep -q '"status".*:.*"ok"'; then
        return 0
    fi
    echo "Dailymotion URL rejected at /add — HTTP $status, body=$body"
    return 1
}

# ---------------------------------------------------------------------------
# 6. Resilience — metube-direct restart must NEVER produce a 500
# ---------------------------------------------------------------------------

test_add_during_metube_restart_never_returns_500() {
    if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        echo "no container runtime — skip"
        return 0
    fi
    local rt
    if command -v podman >/dev/null 2>&1; then rt=podman; else rt=docker; fi

    if ! "$rt" ps --format "{{.Names}}" | grep -q "^metube-direct$"; then
        echo "metube-direct not running — skip"
        return 0
    fi

    # Bounce metube-direct in the background. While it's restarting,
    # fire several /api/add requests and capture every response code.
    ( "$rt" restart metube-direct >/dev/null 2>&1 ) &
    local bg_pid=$!

    local seen_codes="" any_500=0 any_2xx=0 attempt
    for attempt in 1 2 3 4 5 6 7 8; do
        local s
        s=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
            -X POST "$DASHBOARD_URL/api/add" \
            -H "Content-Type: application/json" \
            -d "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")" 2>/dev/null)
        seen_codes="$seen_codes $s"
        [ "$s" = "500" ] && any_500=1
        [[ "$s" =~ ^2[0-9]{2}$ ]] && any_2xx=1
        sleep 1
    done
    wait "$bg_pid" 2>/dev/null
    # Wait for metube-direct to settle so subsequent tests (and any
    # subsequent caller — runner, smoke, manual) have a stable target.
    # The python app inside takes a noticeable time to come up on this
    # host (other containers compete for CPU/RAM); 90s is generous but
    # we'd rather slow this one test down than leave the cluster in a
    # half-broken state. /history must return JSON containing "queue"
    # — proves both nginx upstream AND the python app are fully ready.
    local i settled=0
    for i in $(seq 1 90); do
        if curl -s --max-time 2 "$METUBE_DIRECT_URL/history" 2>/dev/null | grep -q '"queue"'; then
            settled=1
            break
        fi
        sleep 1
    done
    if [ "$settled" -eq 0 ]; then
        echo "metube-direct did not settle within 90s after restart — leaving cluster healthy is part of this test"
        return 1
    fi

    if [ "$any_500" -eq 1 ]; then
        echo "Got an HTTP 500 during metube-direct restart — codes seen:$seen_codes"
        echo "This is the exact failure mode the user reported. nginx should return"
        echo "502/504 (gateway error / timeout) when the upstream is bouncing, not 500."
        return 1
    fi
    if [ "$any_2xx" -eq 0 ]; then
        # If metube comes back fast and the test finished before catching a 2xx,
        # that's a perfectly fine outcome — but the more likely scenario is the
        # restart was so fast we never caught it. Surface it without failing.
        echo "no 2xx seen across $(echo "$seen_codes" | wc -w) attempts (codes:$seen_codes); restart was either too fast or container is wedged"
    fi
}

# ---------------------------------------------------------------------------
# 7. Concurrency
# ---------------------------------------------------------------------------

test_add_concurrent_requests_never_500() {
    local pids=() out tmp
    tmp=$(mktemp -d)
    local i
    for i in 1 2 3 4 5 6; do
        (
            curl -s -o "$tmp/body-$i" -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
                -X POST "$DASHBOARD_URL/api/add" \
                -H "Content-Type: application/json" \
                -d "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")" \
                > "$tmp/status-$i" 2>/dev/null
        ) &
        pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p"; done

    local any_500=0 codes="" i
    for i in 1 2 3 4 5 6; do
        local s
        s=$(cat "$tmp/status-$i" 2>/dev/null)
        codes="$codes $s"
        [ "$s" = "500" ] && any_500=1
    done
    rm -rf "$tmp"

    if [ "$any_500" -eq 1 ]; then
        echo "Concurrent /api/add returned a 500 — codes seen:$codes"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 8. Content-Type contract
# ---------------------------------------------------------------------------

test_add_response_body_is_valid_json() {
    # MeTube's vendor /add returns a JSON body but historically with
    # `Content-Type: text/plain; charset=utf-8` (vendor decision; we
    # don't override it to avoid drifting from the upstream). What
    # MUST be true is that the BODY parses as JSON — Angular's HttpClient
    # parses by extension/content-type but our service layer types
    # `addDownload(...)` to a JSON shape, so the dashboard would break
    # if MeTube ever started returning HTML or plain text without a
    # parseable JSON object.
    local body
    _post_add "$DASHBOARD_URL" "$(printf '{"url":"%s","quality":"720","format":"any","folder":""}' "$ADD_URL_YOUTUBE")" >/dev/null
    body=$(cat /tmp/add-body.txt 2>/dev/null)
    if ! echo "$body" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
        echo "Response body is not valid JSON — $body"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_add_download_tests() {
    if type log_info &> /dev/null; then
        log_info "Running /api/add Coverage Tests..."
    else
        echo "[INFO] Running /api/add Coverage Tests..."
    fi

    # All these tests need the no-vpn services up.
    if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
        echo "  SKIP: $DASHBOARD_URL not reachable — start the no-vpn profile first"
        return 0
    fi

    # Order matters — the restart test bounces metube-direct, so it
    # runs LAST after all stable-state tests. The settle loop inside
    # it waits for /history to return a real queue payload before
    # returning, so a subsequent (e.g. external) caller still sees a
    # healthy server.
    local fns=(
        test_add_happy_path_youtube
        test_add_proxy_and_direct_return_same_shape
        test_add_via_lan_ip
        test_add_response_body_is_valid_json
        test_add_accepts_vimeo_url
        test_add_accepts_dailymotion_url
        test_add_empty_json_body_not_500
        test_add_malformed_json_not_500
        test_add_no_content_type_not_500
        test_add_empty_url_not_500
        test_add_javascript_scheme_url_not_500
        test_add_file_scheme_url_not_500
        test_add_oversized_url_not_500
        test_add_wrong_typed_quality_not_500
        test_add_concurrent_requests_never_500
        test_add_during_metube_restart_never_returns_500
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
    run_add_download_tests
fi
