#!/bin/bash
#
# challenges/scripts/download_completes_challenge.sh
#
# CONST-034 anti-bluff challenge for the FULL download lifecycle.
#
# What we assert from the END USER's perspective:
#
#   1. POST /api/add with a real YouTube URL returns status:ok.
#   2. The download moves through queue → done with status='finished'
#      within a generous timeout.
#   3. **A FILE LANDS IN /downloads ON DISK**, with non-zero size.
#      This is the assertion that catches the broken-volume-mount
#      regression that hid for weeks behind /add-returns-200 tests.
#   4. The file is removed at the end so the challenge is idempotent
#      and doesn't leave artifacts in the user's downloads folder.
#
# Anti-bluff (CONST-034): a download that "passes" without a file
# on disk is a regression. The /add response is necessary but not
# sufficient — the user's experience is the file appearing in their
# downloads folder.
#
# Test URL: "Me at the zoo" (jNQXAC9IVRw) — the very first YouTube
# video, public-domain-ish, 19 seconds, ~500KB at 360p. Stable for
# years, no auth needed, no geo-block, no rate limit.
#
# Exit:
#   0 = file appeared with non-zero size, lifecycle held end-to-end
#   1 = at least one assertion failed (printed)
#   2 = invocation error / dashboard not reachable

set -uo pipefail

DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
TEST_URL="${TEST_URL:-https://www.youtube.com/watch?v=jNQXAC9IVRw}"
QUALITY="${QUALITY:-360}"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-90}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Resolve DOWNLOAD_DIR from .env so the file-on-disk check looks at
# the same directory the running containers wrote to.
DOWNLOAD_DIR=""
if [ -f "$PROJECT_DIR/.env" ]; then
    DOWNLOAD_DIR=$(grep -E "^DOWNLOAD_DIR=" "$PROJECT_DIR/.env" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
fi
if [ -z "$DOWNLOAD_DIR" ]; then
    echo "FAIL: DOWNLOAD_DIR not set in $PROJECT_DIR/.env"
    exit 2
fi

if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
    echo "FAIL: $DASHBOARD_URL not reachable — boot the no-vpn profile first"
    exit 2
fi

# Refuse to run if DOWNLOAD_DIR resolves to a tmpfs — that's the
# exact failure mode this challenge was created to catch (writes
# from inside the container appear to succeed but inodes are dropped
# by the systemd PrivateTmp namespace boundary). Bail loudly with
# a fix instead of producing a confusing FAIL later.
DOWNLOAD_DIR_FSTYPE=$(df -T "$DOWNLOAD_DIR" 2>/dev/null | awk 'NR==2 {print $2}')
if [ "$DOWNLOAD_DIR_FSTYPE" = "tmpfs" ]; then
    echo "FAIL: DOWNLOAD_DIR ($DOWNLOAD_DIR) is on a tmpfs filesystem."
    echo "      Bind-mounting tmpfs paths into containers fails silently with"
    echo "      podman + systemd PrivateTmp on this host — files appear in /proc"
    echo "      but writes don't land on the host. Move DOWNLOAD_DIR off /tmp."
    exit 1
fi

echo "=== download_completes_challenge ==="
echo "test url:       $TEST_URL"
echo "quality:        $QUALITY"
echo "download dir:   $DOWNLOAD_DIR ($DOWNLOAD_DIR_FSTYPE)"
echo "timeout:        ${DOWNLOAD_TIMEOUT}s"
echo

# Pre-test cleanup. If a previous run left a file in $DOWNLOAD_DIR,
# yt-dlp will short-circuit with "already downloaded" and the
# before/after diff would be empty — making us falsely fail. Remove
# any pre-existing artifact for this URL via the container so the
# userns-mapped uid can actually unlink it. Also clear the matching
# /history record so MeTube doesn't immediately mark the new submit
# as "already exists".
RT=podman
if ! command -v podman >/dev/null 2>&1; then RT=docker; fi
"$RT" exec metube-direct sh -c 'rm -f "/downloads/Me at the zoo".* 2>/dev/null' >/dev/null 2>&1 || true
curl -s --max-time 10 \
    -X POST "$DASHBOARD_URL/api/delete" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"ids":["%s"],"where":"done"}' "$TEST_URL")" >/dev/null
curl -s --max-time 10 \
    -X POST "$DASHBOARD_URL/api/delete" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"ids":["%s"],"where":"queue"}' "$TEST_URL")" >/dev/null

# Snapshot files so we can identify the new one(s).
BEFORE_LIST=$(mktemp)
ls -1 "$DOWNLOAD_DIR" 2>/dev/null > "$BEFORE_LIST" || true

# 1. SUBMIT
echo "[1/4] Submitting test URL…"
ADD_BODY=$(curl -s --max-time 30 \
    -X POST "$DASHBOARD_URL/api/add" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"url":"%s","quality":"%s","format":"any","folder":""}' "$TEST_URL" "$QUALITY")")
if ! echo "$ADD_BODY" | grep -q '"status".*:.*"ok"'; then
    echo "FAIL: /api/add did not return status:ok — body=$ADD_BODY"
    rm -f "$BEFORE_LIST"
    exit 1
fi
echo "      /api/add returned status:ok"

# 2. WAIT FOR finished
echo "[2/4] Waiting up to ${DOWNLOAD_TIMEOUT}s for status='finished'…"
FINAL_STATUS=""
FINAL_TITLE=""
ELAPSED=0
for i in $(seq 1 "$DOWNLOAD_TIMEOUT"); do
    SNAPSHOT=$(curl -s --max-time 5 "$DASHBOARD_URL/api/history" 2>/dev/null \
        | python3 -c "
import json, sys
url = sys.argv[1]
d = json.load(sys.stdin)
for k in ('queue', 'pending', 'done'):
    for it in d.get(k, []):
        if it.get('url') == url:
            print(k + '|' + (it.get('status') or '') + '|' + (it.get('title') or '') + '|' + (it.get('msg') or '')[:200])
            sys.exit(0)
print('not-found||')
" "$TEST_URL" 2>/dev/null)
    WHERE=$(echo "$SNAPSHOT" | cut -d'|' -f1)
    STATUS=$(echo "$SNAPSHOT" | cut -d'|' -f2)
    FINAL_TITLE=$(echo "$SNAPSHOT" | cut -d'|' -f3)
    MSG=$(echo "$SNAPSHOT" | cut -d'|' -f4)
    ELAPSED=$i
    if [ "$STATUS" = "finished" ]; then
        FINAL_STATUS=finished
        echo "      finished after ${i}s in /api/history.${WHERE}"
        break
    fi
    if [ "$STATUS" = "error" ]; then
        FINAL_STATUS=error
        echo "FAIL: download moved to status=error after ${i}s"
        echo "      msg: $MSG"
        rm -f "$BEFORE_LIST"
        exit 1
    fi
    sleep 1
done

if [ "$FINAL_STATUS" != "finished" ]; then
    echo "FAIL: download did not reach status=finished within ${DOWNLOAD_TIMEOUT}s"
    rm -f "$BEFORE_LIST"
    exit 1
fi

# 3. ASSERT FILE ON DISK
echo "[3/4] Asserting file appeared in $DOWNLOAD_DIR…"
AFTER_LIST=$(mktemp)
ls -1 "$DOWNLOAD_DIR" 2>/dev/null > "$AFTER_LIST" || true
NEW_FILES=$(comm -13 <(sort "$BEFORE_LIST") <(sort "$AFTER_LIST"))
rm -f "$BEFORE_LIST" "$AFTER_LIST"

if [ -z "$NEW_FILES" ]; then
    echo "FAIL: status=finished but NO new file appeared in $DOWNLOAD_DIR"
    echo "      This is the exact bluff CONST-034 was created to catch:"
    echo "      MeTube reported success but the user has no file."
    exit 1
fi

# Pick the largest new file as the result (some downloads emit thumbs/json too).
RESULT_FILE=""
RESULT_SIZE=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    sz=$(stat -c '%s' "$DOWNLOAD_DIR/$f" 2>/dev/null || echo 0)
    if [ "$sz" -gt "$RESULT_SIZE" ]; then
        RESULT_SIZE=$sz
        RESULT_FILE=$f
    fi
done <<< "$NEW_FILES"

if [ -z "$RESULT_FILE" ] || [ "$RESULT_SIZE" -lt 1024 ]; then
    echo "FAIL: no file >1KB appeared (largest=${RESULT_FILE} ${RESULT_SIZE}B)"
    exit 1
fi
echo "      file:  $RESULT_FILE"
echo "      size:  $RESULT_SIZE bytes"

# 4. CLEANUP
echo "[4/4] Cleaning up the test artifact and history record…"
# Try to remove via container so we get the right uid namespace.
RT=podman
if ! command -v podman >/dev/null 2>&1; then RT=docker; fi
"$RT" exec metube-direct sh -c "rm -f /downloads/* /downloads/.metube* 2>/dev/null" >/dev/null 2>&1 || true
# Belt-and-braces: sweep up any new files using printf+xargs from the host
# under userns root so file removal doesn't fail with EACCES.
while IFS= read -r f; do
    [ -z "$f" ] && continue
    "$RT" exec metube-direct sh -c "rm -f '/downloads/$f'" >/dev/null 2>&1 || true
done <<< "$NEW_FILES"

curl -s --max-time 10 \
    -X POST "$DASHBOARD_URL/api/delete" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"ids":["%s"],"where":"done"}' "$TEST_URL")" >/dev/null

echo
echo "=== summary: PASS — real download produced a $RESULT_SIZE-byte file in ${ELAPSED}s ==="
exit 0
