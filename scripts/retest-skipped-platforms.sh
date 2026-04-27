#!/bin/bash
#
# retest-skipped-platforms.sh
#
# tests/test-media-services.sh skips TikTok / Bilibili / Facebook /
# Twitter / Instagram / Reddit / Rumble because of platform / geo /
# IP / login restrictions that aren't bugs in this project. Those
# skips are honest — but they're also blind spots: when network
# conditions change (residential VPN, CN egress, fresh cookies,
# upstream extractor fix) any of them might start working without us
# noticing.
#
# This script runs `yt-dlp --simulate` against each skipped platform's
# canonical test URL and reports which (if any) succeed today. Output
# is advisory: it suggests dashboard badge flips you might consider
# (e.g. "TikTok looks reachable now — flip status: 'restricted' →
# status: 'ok' in download-form.component.ts:platforms[]").
#
# It does NOT modify any code. Run it manually, periodically, or
# whenever your egress conditions change.
#
# Exit:
#   0 = always (this is a report, not a gate)

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CLI_CONTAINER="${CLI_CONTAINER:-yt-dlp-cli}"
TIMEOUT="${TIMEOUT:-45}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

if command -v podman >/dev/null 2>&1; then
    RT=podman
elif command -v docker >/dev/null 2>&1; then
    RT=docker
else
    echo "ERROR: no container runtime found" >&2
    exit 0
fi

if ! "$RT" ps --format "{{.Names}}" | grep -q "^${CLI_CONTAINER}\$"; then
    echo "ERROR: container '$CLI_CONTAINER' is not running. Start the no-vpn profile first:"
    echo "    ./start_no_vpn"
    exit 0
fi

declare -A URLS=(
    [tiktok]="https://www.tiktok.com/@leenabhushan/video/6748451240264420610"
    [bilibili]="https://www.bilibili.com/video/BV13x41117TL"
    [facebook]="https://www.facebook.com/watch/?v=10153231379946729"
    [facebook-legacy]="https://www.facebook.com/radiokicksfm/videos/3676516585958356/"
    [twitter]="https://twitter.com/freethenipple/status/643211948184596480"
    [x]="https://x.com/freethenipple/status/643211948184596480"
    [instagram]="https://instagram.com/p/aye83DjauH/?foo=bar#abc"
    [reddit]="https://www.reddit.com/r/videos/comments/6rrwyj/that_small_heart_attack/"
    [rumble]="https://rumble.com/vdmum1-moose-the-dog-helps-girls-dig-a-snow-fort.html"
)

# Stable iteration order (associative arrays in bash don't preserve
# insertion order across versions).
ORDER=(tiktok bilibili facebook facebook-legacy twitter x instagram reddit rumble)

declare -A RESULT
declare -A FIRST_ERR

probe_one() {
    local key="$1"
    local url="${URLS[$key]}"
    local out rc

    out=$(timeout "$TIMEOUT" "$RT" exec "$CLI_CONTAINER" \
        yt-dlp --no-config --user-agent "$UA" --simulate --no-warnings "$url" 2>&1)
    rc=$?

    if [ "$rc" -eq 0 ] && echo "$out" | grep -qE "(Downloading [0-9]+ format|Finished downloading playlist)"; then
        RESULT[$key]="OK"
        FIRST_ERR[$key]=""
    else
        RESULT[$key]="FAIL"
        FIRST_ERR[$key]=$(echo "$out" | grep -E "^ERROR:|Unable to download|HTTP Error|IP address is blocked|Sign in to confirm|Cannot parse" | head -n 1)
        [ -z "${FIRST_ERR[$key]}" ] && FIRST_ERR[$key]=$(echo "$out" | tail -n 1)
    fi
}

echo "=== retest-skipped-platforms ==="
echo "container: $CLI_CONTAINER  (runtime: $RT, timeout: ${TIMEOUT}s)"
echo "yt-dlp version: $("$RT" exec "$CLI_CONTAINER" yt-dlp --version 2>/dev/null || echo unknown)"
echo

for key in "${ORDER[@]}"; do
    printf "%-18s ... " "$key"
    probe_one "$key"
    if [ "${RESULT[$key]}" = "OK" ]; then
        echo "OK"
    else
        echo "FAIL — ${FIRST_ERR[$key]}"
    fi
done

echo
echo "=== summary ==="
ok_count=0
fail_count=0
for key in "${ORDER[@]}"; do
    if [ "${RESULT[$key]}" = "OK" ]; then
        ok_count=$((ok_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
done
echo "$ok_count platform(s) reachable, $fail_count still blocked"

# Suggest badge flips for any "OK" platform the dashboard currently
# shows as 'restricted' or 'partial'. We don't try to be clever about
# parsing the dashboard source — point the operator at the file.
if [ "$ok_count" -gt 0 ]; then
    echo
    echo "If any of the OK results above are platforms currently shown as"
    echo "'restricted' / 'partial' / 'cookies' in the dashboard, consider"
    echo "updating the badge in:"
    echo "    dashboard/src/app/components/download-form/download-form.component.ts"
    echo "(the 'platforms' array; rebuild dashboard image after editing)."
fi
