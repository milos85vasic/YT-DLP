#!/bin/bash
#
# Challenge: Download completes and file lands on disk
# Anti-bluff: Submit URL, wait for finished, stat-verify file >1KB on host.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="http://localhost:8088"
# Resolve the download dir the running stack ACTUALLY mounts, from the project's
# .env (single source of truth — compose mounts ${DOWNLOAD_DIR}). Hardcoding it is a
# §11.4 bluff: it produces a false FAIL when the download lands in the configured dir
# (fixed 2026-06-16 — nezha used DOWNLOAD_DIR=$HOME/ytdlp-data/downloads, but this
# script checked an unrelated hardcoded path). Legacy path kept only as last resort.
_DCC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOWNLOAD_DIR="$(grep -E '^DOWNLOAD_DIR=' "$_DCC_ROOT/.env" 2>/dev/null | tail -1 | cut -d= -f2-)"
DOWNLOAD_DIR="${DOWNLOAD_DIR%\"}"; DOWNLOAD_DIR="${DOWNLOAD_DIR#\"}"
DOWNLOAD_DIR="${DOWNLOAD_DIR%\'}"; DOWNLOAD_DIR="${DOWNLOAD_DIR#\'}"
DOWNLOAD_DIR="${DOWNLOAD_DIR/#\$HOME/$HOME}"
DOWNLOAD_DIR="${DOWNLOAD_DIR/#\~/$HOME}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/run/media/milosvasic/DATA4TB/Projects/MeTube/downloads}"
# Use a reliable Vimeo URL that has completed successfully before
TEST_URL="https://vimeo.com/108018156"
QUALITY="best"
TIMEOUT=180

echo "=== download_completes_challenge ==="
echo "test url:       $TEST_URL"
echo "quality:        $QUALITY"
echo "download dir:   $DOWNLOAD_DIR ($(df -T "$DOWNLOAD_DIR" | awk 'NR==2 {print $2}'))"
echo "timeout:        ${TIMEOUT}s"
echo ""

# Take before snapshot
BEFORE=$(mktemp)
find "$DOWNLOAD_DIR" -type f -printf '%s %p\n' 2>/dev/null | sort > "$BEFORE" || true

echo "[1/4] Submitting test URL…"
RESPONSE=$(curl -s -X POST "$API_URL/add" \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"$TEST_URL\",\"quality\":\"$QUALITY\",\"format\":\"any\",\"folder\":\"\"}" 2>/dev/null)
echo "      /api/add returned $RESPONSE"

if ! echo "$RESPONSE" | grep -q '"status".*:.*"ok"'; then
    echo -e "${RED}FAIL: /add did not return status:ok${NC}"
    rm -f "$BEFORE"
    exit 1
fi

echo "[2/4] Waiting up to ${TIMEOUT}s for status='finished'…"
FINISHED=false
START_TIME=$(date +%s)
while true; do
    HISTORY=$(curl -s "$API_URL/history" 2>/dev/null)
    
    # Extract status of OUR specific URL using Python for accurate JSON parsing
    URL_STATUS=$(echo "$HISTORY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for section in ['queue', 'pending', 'done']:
    for item in data.get(section, []):
        if item.get('url') == '$TEST_URL':
            print(item.get('status', 'unknown'))
            sys.exit(0)
print('not_found')
" 2>/dev/null || echo "parse_error")
    
    if [ "$URL_STATUS" = "finished" ]; then
        FINISHED=true
        break
    fi
    if [ "$URL_STATUS" = "error" ]; then
        ERROR_MSG=$(echo "$HISTORY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for section in ['queue', 'pending', 'done']:
    for item in data.get(section, []):
        if item.get('url') == '$TEST_URL':
            print(item.get('msg', 'unknown error'))
            sys.exit(0)
" 2>/dev/null || echo "unknown")
        echo "FAIL: download moved to status=error"
        echo "      msg: $ERROR_MSG"
        rm -f "$BEFORE"
        exit 1
    fi
    
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        break
    fi
    sleep 2
done

if [ "$FINISHED" != "true" ]; then
    echo -e "${RED}FAIL: download did not finish within ${TIMEOUT}s${NC}"
    rm -f "$BEFORE"
    exit 1
fi

echo "[3/4] Download finished. Checking for new file on disk…"
AFTER=$(mktemp)
find "$DOWNLOAD_DIR" -type f -printf '%s %p\n' 2>/dev/null | sort > "$AFTER" || true
NEW_FILES=$(comm -13 "$BEFORE" "$AFTER" | awk '{print $1, $2}')
rm -f "$BEFORE" "$AFTER"

if [ -z "$NEW_FILES" ]; then
    echo -e "${RED}FAIL: no new file appeared in $DOWNLOAD_DIR${NC}"
    exit 1
fi

echo "      New file(s):"
echo "$NEW_FILES" | while read -r size name; do
    echo "        $name ($size bytes)"
    if [ "$size" -lt 1024 ]; then
        echo -e "${RED}FAIL: file is < 1KB — likely incomplete${NC}"
        exit 1
    fi
done

echo "[4/4] Cleanup: removing test download from history…"
curl -s -X POST "$API_URL/delete" \
    -H "Content-Type: application/json" \
    -d "{\"ids\":[\"$TEST_URL\"],\"where\":\"done\"}" >/dev/null 2>&1 || true

echo -e "${GREEN}PASS: download completed and file >1KB verified on disk${NC}"
