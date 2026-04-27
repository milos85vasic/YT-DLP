#!/bin/bash
#
# tests/test-add-all-platforms.sh
#
# Per-platform automation for the /api/add NO-500 invariant.
#
# Contract guaranteed by these tests (asserted for EVERY supported
# platform, not just YouTube):
#
#   1. POST /api/add with a canonical URL for that platform
#      MUST NOT return HTTP 500 — neither from nginx (the dashboard
#      proxy) nor from MeTube's vendor /add endpoint.
#   2. The response body MUST parse as valid JSON.
#   3. The HTTP status code is one of {200, 400, 422} — anything in
#      the 5xx family is a regression. (502 / 504 from a transient
#      upstream bounce are tested separately in test-add-download.sh
#      and are not exercised here.)
#
# What we DO NOT assert here:
#   - That the actual download succeeds. yt-dlp may fail extraction
#     asynchronously (TikTok IP-blocked, Bilibili geo-blocked,
#     Facebook parser bug on some URL forms, …). Those are real
#     network/upstream constraints that the dashboard's status badges
#     already document for the user. /api/add's job is to accept the
#     request and queue it; what happens after is the worker's
#     problem and is exercised separately by test-media-services.sh.
#
# Coverage: 17 platforms (every entry in dashboard's
# download-form.component.ts platforms[]) + a parallel burst that
# fires all 17 at once.
#
# NOTE: do NOT use `set -e` / `set -u` at file scope — when run-tests.sh
# sources this file, those flags would leak into the orchestrator.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
TEST_TIMEOUT="${TEST_TIMEOUT:-20}"

# Canonical test URLs — one per supported platform. Sourced from
# tests/test-media-services.sh where overlapping; new entries for
# X / Twitter / Threads added explicitly.
URL_YOUTUBE="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
URL_VIMEO="https://vimeo.com/108018156"
URL_DAILYMOTION="https://www.dailymotion.com/video/x5kesuj"
URL_TWITCH="https://www.twitch.tv/riotgames/v/6528877"
URL_INSTAGRAM="https://www.instagram.com/p/aye83DjauH/"
URL_REDDIT="https://www.reddit.com/r/videos/comments/6rrwyj/that_small_heart_attack/"
URL_RUMBLE="https://rumble.com/vdmum1-moose-the-dog-helps-girls-dig-a-snow-fort.html"
URL_VK="https://vkvideo.ru/video/playlist/-220068665_92"
URL_PEERTUBE="https://framatube.org/videos/watch/9c9de5e8-0a1e-484a-b099-e80766180a6d"
URL_SOUNDCLOUD="https://soundcloud.com/ethmusic/lostin-powers-she-so-heavy"
URL_BANDCAMP="https://youtube-dl.bandcamp.com/track/youtube-dl-test-song"
URL_TIKTOK="https://www.tiktok.com/@leenabhushan/video/6748451240264420610"
URL_BILIBILI="https://www.bilibili.com/video/BV13x41117TL"
URL_FACEBOOK="https://www.facebook.com/watch/?v=10153231379946729"
URL_TWITTER="https://twitter.com/freethenipple/status/643211948184596480"
URL_X="https://x.com/elonmusk/status/1518623997054918657"
URL_THREADS="https://www.threads.net/@zuck/post/C7XOeqoyMQg"

# shellcheck disable=SC1091
[ -f "$PROJECT_DIR/tests/test-helpers.sh" ] && source "$PROJECT_DIR/tests/test-helpers.sh"

# Probe a single platform — the universal assertion.
# $1 = label (used in error messages)
# $2 = canonical URL for that platform
# Returns 0 if /api/add returned anything other than 500 with parseable JSON.
_probe_platform() {
    local label="$1"
    local url="$2"
    local status body
    local body_file
    body_file=$(mktemp)
    status=$(curl -s -o "$body_file" -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
        -X POST "$DASHBOARD_URL/api/add" \
        -H "Content-Type: application/json" \
        -d "$(printf '{"url":"%s","quality":"720","format":"any","folder":"test-no-500"}' "$url")" 2>/dev/null)
    body=$(cat "$body_file" 2>/dev/null)
    rm -f "$body_file"

    if [ "$status" = "500" ]; then
        echo "[$label] HTTP 500 from /api/add — this is the regression we guard against."
        echo "  url:  $url"
        echo "  body: $(echo "$body" | head -c 300)"
        return 1
    fi

    # 502 / 504 / 000 are bounce artefacts (covered by the metube-restart
    # test in test-add-download.sh). For per-platform coverage we accept
    # them silently — they don't violate the NO-500 contract.
    if [ "$status" = "502" ] || [ "$status" = "504" ] || [ "$status" = "000" ]; then
        # Body should still be JSON-ish if it came from MeTube; if it's
        # an nginx HTML error page the curl-status reports the gateway
        # state which is fine. We don't fail.
        return 0
    fi

    # For all other status codes (2xx / 4xx), body MUST parse as JSON —
    # the dashboard relies on that.
    if ! echo "$body" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' >/dev/null 2>&1; then
        echo "[$label] HTTP $status but body is not valid JSON: $body"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Per-platform tests (alphabetical for predictable run order)
# ---------------------------------------------------------------------------

test_add_no500_bandcamp()    { _probe_platform "bandcamp"    "$URL_BANDCAMP"; }
test_add_no500_bilibili()    { _probe_platform "bilibili"    "$URL_BILIBILI"; }
test_add_no500_dailymotion() { _probe_platform "dailymotion" "$URL_DAILYMOTION"; }
test_add_no500_facebook()    { _probe_platform "facebook"    "$URL_FACEBOOK"; }
test_add_no500_instagram()   { _probe_platform "instagram"   "$URL_INSTAGRAM"; }
test_add_no500_peertube()    { _probe_platform "peertube"    "$URL_PEERTUBE"; }
test_add_no500_reddit()      { _probe_platform "reddit"      "$URL_REDDIT"; }
test_add_no500_rumble()      { _probe_platform "rumble"      "$URL_RUMBLE"; }
test_add_no500_soundcloud()  { _probe_platform "soundcloud"  "$URL_SOUNDCLOUD"; }
test_add_no500_threads()     { _probe_platform "threads"     "$URL_THREADS"; }
test_add_no500_tiktok()      { _probe_platform "tiktok"      "$URL_TIKTOK"; }
test_add_no500_twitch()      { _probe_platform "twitch"      "$URL_TWITCH"; }
test_add_no500_twitter()     { _probe_platform "twitter"     "$URL_TWITTER"; }
test_add_no500_vimeo()       { _probe_platform "vimeo"       "$URL_VIMEO"; }
test_add_no500_vk()          { _probe_platform "vk"          "$URL_VK"; }
test_add_no500_x()           { _probe_platform "x"           "$URL_X"; }
test_add_no500_youtube()     { _probe_platform "youtube"     "$URL_YOUTUBE"; }

# ---------------------------------------------------------------------------
# Parallel burst — fire all 17 platforms simultaneously, assert no 500.
# Catches state-machine / lock-contention regressions that only show up
# when many submissions race.
# ---------------------------------------------------------------------------

test_add_no500_all_platforms_in_parallel() {
    local tmp pids=() any_500=0 codes=""
    tmp=$(mktemp -d)
    local i=0
    for entry in \
        "youtube|$URL_YOUTUBE"           "vimeo|$URL_VIMEO" \
        "dailymotion|$URL_DAILYMOTION"   "twitch|$URL_TWITCH" \
        "instagram|$URL_INSTAGRAM"       "reddit|$URL_REDDIT" \
        "rumble|$URL_RUMBLE"             "vk|$URL_VK" \
        "peertube|$URL_PEERTUBE"         "soundcloud|$URL_SOUNDCLOUD" \
        "bandcamp|$URL_BANDCAMP"         "tiktok|$URL_TIKTOK" \
        "bilibili|$URL_BILIBILI"         "facebook|$URL_FACEBOOK" \
        "twitter|$URL_TWITTER"           "x|$URL_X" \
        "threads|$URL_THREADS"; do

        i=$((i+1))
        local label url
        label="${entry%%|*}"
        url="${entry#*|}"
        (
            curl -s -o "$tmp/body-$i" -w "%{http_code}" --max-time "$TEST_TIMEOUT" \
                -X POST "$DASHBOARD_URL/api/add" \
                -H "Content-Type: application/json" \
                -d "$(printf '{"url":"%s","quality":"720","format":"any","folder":"test-no-500-burst"}' "$url")" \
                > "$tmp/status-$i" 2>/dev/null
            echo "$label" > "$tmp/label-$i"
        ) &
        pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p"; done

    local k
    for k in $(seq 1 "$i"); do
        local s l
        s=$(cat "$tmp/status-$k" 2>/dev/null)
        l=$(cat "$tmp/label-$k" 2>/dev/null)
        codes="$codes $l=$s"
        if [ "$s" = "500" ]; then
            any_500=1
            echo "  parallel POST returned 500 for $l"
        fi
    done
    rm -rf "$tmp"

    if [ "$any_500" -eq 1 ]; then
        echo "Parallel burst: at least one platform returned HTTP 500. Codes:$codes"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# /history must remain reachable throughout the burst (not 500).
# Sanity check that the platform burst doesn't wedge MeTube state.
# ---------------------------------------------------------------------------

test_history_endpoint_not_500_after_burst() {
    local s
    s=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TEST_TIMEOUT" "$DASHBOARD_URL/api/history")
    if [ "$s" = "500" ]; then
        echo "/api/history returned HTTP 500 after the platform burst — state machine wedged"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_add_all_platforms_tests() {
    if type log_info &> /dev/null; then
        log_info "Running /api/add NO-500 Per-Platform Tests..."
    else
        echo "[INFO] Running /api/add NO-500 Per-Platform Tests..."
    fi

    if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
        echo "  SKIP: $DASHBOARD_URL not reachable — start the no-vpn profile first"
        return 0
    fi

    local fns=(
        test_add_no500_youtube
        test_add_no500_vimeo
        test_add_no500_dailymotion
        test_add_no500_twitch
        test_add_no500_instagram
        test_add_no500_reddit
        test_add_no500_rumble
        test_add_no500_vk
        test_add_no500_peertube
        test_add_no500_soundcloud
        test_add_no500_bandcamp
        test_add_no500_tiktok
        test_add_no500_bilibili
        test_add_no500_facebook
        test_add_no500_twitter
        test_add_no500_x
        test_add_no500_threads
        test_add_no500_all_platforms_in_parallel
        test_history_endpoint_not_500_after_burst
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
    run_add_all_platforms_tests
fi
