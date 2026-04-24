#!/bin/bash
#
# Media Services Compatibility Tests
# Tests yt-dlp extraction across major video platforms
# Can be run standalone or sourced by run-tests.sh
#

# =============================================================================
# Test URLs for supported media services
# =============================================================================
# These are official yt-dlp test URLs or well-known public videos.
# Some platforms may be skipped due to geo-restrictions or upstream bugs.

MEDIA_TEST_YOUTUBE_URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
MEDIA_TEST_VIMEO_URL="https://vimeo.com/108018156"
MEDIA_TEST_DAILYMOTION_URL="http://www.dailymotion.com/video/x5kesuj_office-christmas-party-review-jason-bateman-olivia-munn-t-j-miller_news"
MEDIA_TEST_TWITCH_URL="http://www.twitch.tv/riotgames/v/6528877?t=5m10s"
MEDIA_TEST_INSTAGRAM_URL="https://instagram.com/p/aye83DjauH/?foo=bar#abc"
MEDIA_TEST_REDDIT_URL="https://www.reddit.com/r/videos/comments/6rrwyj/that_small_heart_attack/"
MEDIA_TEST_RUMBLE_URL="https://rumble.com/vdmum1-moose-the-dog-helps-girls-dig-a-snow-fort.html"
MEDIA_TEST_VK_URL="https://vk.com/videos-77521?z=video-77521_162222515%2Fclub77521"
MEDIA_TEST_PEERTUBE_URL="https://framatube.org/videos/watch/9c9de5e8-0a1e-484a-b099-e80766180a6d"
MEDIA_TEST_SOUNDCLOUD_URL="http://soundcloud.com/ethmusic/lostin-powers-she-so-heavy"
MEDIA_TEST_BANDCAMP_URL="http://youtube-dl.bandcamp.com/track/youtube-dl-test-song"

# Platforms with known upstream/platform issues (not failures in this project)
MEDIA_TEST_TIKTOK_URL="https://www.tiktok.com/@leenabhushan/video/6748451240264420610"
MEDIA_TEST_BILIBILI_URL="https://www.bilibili.com/video/BV13x41117TL"
MEDIA_TEST_FACEBOOK_URL="https://www.facebook.com/radiokicksfm/videos/3676516585958356/"
MEDIA_TEST_TWITTER_URL="https://twitter.com/freethenipple/status/643211948184596480"

# =============================================================================
# Helper to run yt-dlp simulate in container
# =============================================================================

_ytdlp_simulate() {
    local url="$1"
    local timeout="${2:-45}"

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

    local container="${CONTAINER_NAME:-yt-dlp-cli}"

    timeout "$timeout" "$CONTAINER_RUNTIME" exec "$container" \
        yt-dlp --no-config \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --simulate "$url" 2>&1
}

_check_simulate_success() {
    local output="$1"
    echo "$output" | grep -qE "(Downloading [0-9]+ format|Finished downloading playlist)"
}

# =============================================================================
# Individual Platform Tests
# =============================================================================

test_youtube() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_YOUTUBE_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "YouTube extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_vimeo() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_VIMEO_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Vimeo extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_dailymotion() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_DAILYMOTION_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Dailymotion extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_twitch() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_TWITCH_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Twitch extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_instagram() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_INSTAGRAM_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Instagram extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_reddit() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_REDDIT_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Reddit extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_rumble() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_RUMBLE_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Rumble extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_vk() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_VK_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "VK extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_peertube() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_PEERTUBE_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "PeerTube extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_soundcloud() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_SOUNDCLOUD_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "SoundCloud extraction failed"
    echo "$output" | tail -n 3
    return 1
}

test_bandcamp() {
    local output
    output=$(_ytdlp_simulate "$MEDIA_TEST_BANDCAMP_URL")
    if _check_simulate_success "$output"; then
        return 0
    fi
    echo "Bandcamp extraction failed"
    echo "$output" | tail -n 3
    return 1
}

# =============================================================================
# MeTube Web UI Tests
# =============================================================================

test_metube_api_vk() {
    local url="https://vkvideo.ru/video/playlist/-220068665_92"
    local response
    local exit_code=0

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

    # Ensure metube-direct container is running
    if ! $CONTAINER_RUNTIME ps --format "{{.Names}}" | grep -q "^metube-direct$"; then
        echo "metube-direct container is not running"
        return 1
    fi

    response=$(curl -s -X POST "http://127.0.0.1:8088/add" \
        -H "Content-Type: application/json" \
        -d "{\"url\":\"$url\",\"quality\":\"720\"}" \
        --max-time 60 2>&1) || exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        echo "MeTube API request failed (curl exit $exit_code): $response"
        return 1
    fi

    if echo "$response" | grep -q '"status" *: *"ok"'; then
        return 0
    fi

    echo "MeTube API returned error: $response"
    return 1
}

test_metube_api_youtube() {
    local url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    local response
    local exit_code=0

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

    if ! $CONTAINER_RUNTIME ps --format "{{.Names}}" | grep -q "^metube-direct$"; then
        echo "metube-direct container is not running"
        return 1
    fi

    response=$(curl -s -X POST "http://127.0.0.1:8088/add" \
        -H "Content-Type: application/json" \
        -d "{\"url\":\"$url\",\"quality\":\"720\"}" \
        --max-time 120 2>&1) || exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        echo "MeTube API request failed (curl exit $exit_code): $response"
        return 1
    fi

    if echo "$response" | grep -q '"status" *: *"ok"'; then
        return 0
    fi

    echo "MeTube API returned error: $response"
    return 1
}

# =============================================================================
# Known-issue platforms (skipped with explanation)
# =============================================================================

test_tiktok() {
    echo "TikTok is IP-blocked for most non-residential IPs — platform restriction"
    return 0
}

test_bilibili() {
    echo "Bilibili requires a Chinese network connection (HTTP 412) — geo-restriction"
    return 0
}

test_facebook() {
    echo "Facebook extractor is broken in yt-dlp 2026.03.17 — upstream issue"
    return 0
}

test_twitter() {
    echo "Twitter/X test tweet no longer contains video media — test data stale"
    return 0
}

# =============================================================================
# Test Suite Runner
# =============================================================================

run_media_services_tests() {
    if type log_info &> /dev/null; then
        log_info "Running Media Services Tests..."
    else
        echo "[INFO] Running Media Services Tests..."
    fi

    run_test "test_youtube" test_youtube
    run_test "test_vimeo" test_vimeo
    run_test "test_dailymotion" test_dailymotion
    run_test "test_twitch" test_twitch
    run_test "test_instagram" test_instagram
    run_test "test_reddit" test_reddit
    run_test "test_rumble" test_rumble
    run_test "test_vk" test_vk
    run_test "test_peertube" test_peertube
    run_test "test_soundcloud" test_soundcloud
    run_test "test_bandcamp" test_bandcamp
    run_test "test_metube_api_vk" test_metube_api_vk
    run_test "test_metube_api_youtube" test_metube_api_youtube
    run_test "test_tiktok" test_tiktok
    run_test "test_bilibili" test_bilibili
    run_test "test_facebook" test_facebook
    run_test "test_twitter" test_twitter
}

# =============================================================================
# Standalone execution support
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Running directly — provide standalone execution
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

    CONTAINER_NAME="yt-dlp-cli"
    TEST_TIMEOUT="45"
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
            if echo "$output" | grep -qE "(platform restriction|geo-restriction|upstream issue|test data stale)"; then
                echo -e "${CYAN}SKIP${NC} ($output)"
                SKIPPED=$((SKIPPED + 1))
            else
                echo -e "${GREEN}PASS${NC}"
                PASSED=$((PASSED + 1))
            fi
        else
            echo -e "${RED}FAIL${NC}"
            echo "$output" | sed 's/^/       /'
            FAILED=$((FAILED + 1))
        fi
    }

    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Media Services Compatibility Test${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo -e "${BLUE}[INFO]${NC} Container Runtime: $CONTAINER_RUNTIME"

    if ! $CONTAINER_RUNTIME ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}WARNING: Container '$CONTAINER_NAME' is not running.${NC}"
        echo "Attempting to start services..."
        if [ -f ./start_no_vpn ]; then
            ./start_no_vpn
        else
            echo -e "${RED}ERROR: Cannot start services. Please run ./start first.${NC}"
            exit 1
        fi
    fi

    ytdlp_version=$($CONTAINER_RUNTIME exec "$CONTAINER_NAME" yt-dlp --version 2>/dev/null)
    echo -e "${BLUE}[INFO]${NC} yt-dlp version: $ytdlp_version"
    echo ""

    run_media_services_tests

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
        echo -e "${GREEN}All tests passed or were skipped (known issues).${NC}"
        exit 0
    fi
fi
