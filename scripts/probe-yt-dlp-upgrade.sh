#!/bin/bash
#
# probe-yt-dlp-upgrade.sh
#
# Side-by-side probe: compare a candidate yt-dlp image against the
# current pinned image (ghcr.io/jim60105/yt-dlp:pot, which carries the
# YouTube PoT-challenge plugin) without changing production state.
#
# Usage:
#   bash scripts/probe-yt-dlp-upgrade.sh [candidate_image]
#
# Defaults to ghcr.io/jim60105/yt-dlp:latest. The candidate image is
# pulled into a transient ad-hoc container (probe-yt-dlp-cli) which
# is removed at the end. Nothing else is touched.
#
# Each platform's canonical test URL is run through `yt-dlp --simulate`
# in BOTH images. Output is a table:
#
#   platform       :pot (current)         candidate
#   YouTube        OK                     OK
#   Facebook (legacy) FAIL: parser bug    OK
#   ...
#
# Use this when:
#   - Upstream yt-dlp release notes mention a fix you want
#   - A platform-test retest (./scripts/retest-skipped-platforms.sh)
#     suggests one platform unblocked
#   - Quarterly: just to know whether the pin is stale
#
# This script does NOT change docker-compose.yml, the pinned tag, the
# running yt-dlp-cli container, or any state on disk beyond the image
# pull (which podman caches locally).
#
# Exit:
#   0 = report produced (regardless of pass/fail counts)
#   2 = invocation error (no runtime, can't pull, etc.)

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CURRENT_IMAGE="${CURRENT_IMAGE:-ghcr.io/jim60105/yt-dlp:pot}"
CANDIDATE_IMAGE="${1:-ghcr.io/jim60105/yt-dlp:latest}"
PROBE_NAME="probe-yt-dlp-cli-$$"
TIMEOUT="${TIMEOUT:-45}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

if command -v podman >/dev/null 2>&1; then
    RT=podman
elif command -v docker >/dev/null 2>&1; then
    RT=docker
else
    echo "ERROR: no container runtime found" >&2
    exit 2
fi

cleanup() {
    "$RT" rm -f "$PROBE_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== probe-yt-dlp-upgrade ==="
echo "current pinned: $CURRENT_IMAGE"
echo "candidate:      $CANDIDATE_IMAGE"
echo "runtime:        $RT"
echo

# Pull candidate (current is assumed already present from a recent boot).
echo "Pulling candidate image (this may take a few minutes)..."
if ! "$RT" pull "$CANDIDATE_IMAGE" >/tmp/probe-pull.log 2>&1; then
    tail -n 5 /tmp/probe-pull.log >&2
    echo "ERROR: pull of $CANDIDATE_IMAGE failed" >&2
    exit 2
fi
echo "Pulled. Spinning up transient container..."

# Spin candidate up as a sleep container (mirrors yt-dlp-cli's pattern).
if ! "$RT" run -d --name "$PROBE_NAME" \
        --entrypoint /bin/sh \
        "$CANDIDATE_IMAGE" \
        -c 'while true; do sleep 3600; done' >/dev/null; then
    echo "ERROR: failed to start probe container" >&2
    exit 2
fi
sleep 1

run_in() {
    # $1 = "current" | "candidate" ; $2 = url
    local which="$1"; shift
    local url="$1"
    if [ "$which" = "current" ]; then
        timeout "$TIMEOUT" "$RT" exec yt-dlp-cli \
            yt-dlp --no-config --user-agent "$UA" --simulate --no-warnings "$url" 2>&1
    else
        timeout "$TIMEOUT" "$RT" exec "$PROBE_NAME" \
            yt-dlp --no-config --user-agent "$UA" --simulate --no-warnings "$url" 2>&1
    fi
}

probe() {
    # $1 = label  $2 = url
    local label="$1" url="$2"
    local cur_out cand_out cur_state cand_state cur_err cand_err

    cur_out=$(run_in current  "$url")
    if echo "$cur_out" | grep -qE "(Downloading [0-9]+ format|Finished downloading playlist)"; then
        cur_state="OK"; cur_err=""
    else
        cur_state="FAIL"
        cur_err=$(echo "$cur_out" | grep -E "^ERROR:|HTTP Error|Cannot parse|IP address is blocked|Sign in to confirm" | head -n 1)
    fi

    cand_out=$(run_in candidate "$url")
    if echo "$cand_out" | grep -qE "(Downloading [0-9]+ format|Finished downloading playlist)"; then
        cand_state="OK"; cand_err=""
    else
        cand_state="FAIL"
        cand_err=$(echo "$cand_out" | grep -E "^ERROR:|HTTP Error|Cannot parse|IP address is blocked|Sign in to confirm" | head -n 1)
    fi

    printf "%-22s  %-30s  %-30s\n" "$label" "$cur_state" "$cand_state"
    if [ -n "$cur_err" ] || [ -n "$cand_err" ]; then
        [ -n "$cur_err" ]  && printf "%-22s    current : %s\n" "" "$(echo "$cur_err"  | cut -c1-70)"
        [ -n "$cand_err" ] && printf "%-22s    candidate: %s\n" "" "$(echo "$cand_err" | cut -c1-70)"
    fi
}

# Sanity: yt-dlp-cli must be running for the "current" side.
if ! "$RT" ps --format "{{.Names}}" | grep -q "^yt-dlp-cli\$"; then
    echo "ERROR: container 'yt-dlp-cli' is not running. Start the no-vpn profile first:" >&2
    echo "       ./start_no_vpn" >&2
    exit 2
fi

# Versions
CUR_V=$("$RT" exec yt-dlp-cli yt-dlp --version 2>/dev/null || echo unknown)
CAND_V=$("$RT" exec "$PROBE_NAME" yt-dlp --version 2>/dev/null || echo unknown)
printf "yt-dlp version  %-30s  %-30s\n" "$CUR_V" "$CAND_V"
echo
printf "%-22s  %-30s  %-30s\n" "platform" "$(echo "$CURRENT_IMAGE" | cut -c1-30)" "$(echo "$CANDIDATE_IMAGE" | cut -c1-30)"
echo "------------------------------------------------------------------------------------"

probe "YouTube"            "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
probe "Vimeo"              "https://vimeo.com/108018156"
probe "SoundCloud"         "http://soundcloud.com/ethmusic/lostin-powers-she-so-heavy"
probe "Facebook (/watch)"  "https://www.facebook.com/watch/?v=10153231379946729"
probe "Facebook (legacy)"  "https://www.facebook.com/radiokicksfm/videos/3676516585958356/"
probe "X / Twitter"        "https://twitter.com/freethenipple/status/643211948184596480"
probe "TikTok"             "https://www.tiktok.com/@leenabhushan/video/6748451240264420610"
probe "Bilibili"           "https://www.bilibili.com/video/BV13x41117TL"

echo
echo "Note: TikTok / Bilibili / Rumble blocks are network-egress, not"
echo "extractor-version, problems — both columns will FAIL on this host"
echo "until you switch to a residential / region-appropriate VPN."
echo
echo "Decide whether to bump the pin in docker-compose.yml only if the"
echo "candidate column shows a strict improvement on platforms you care"
echo "about AND the YouTube row is still OK (the :pot pin exists for"
echo "YouTube's PoT-challenge handling — losing it costs us YouTube)."
