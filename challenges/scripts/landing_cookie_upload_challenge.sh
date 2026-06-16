#!/bin/bash
#
# Challenge: Cookie upload lands on disk
# Anti-bluff: POST cookies.txt, verify file exists with expected content.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# §11.4.14 test cleanup: this challenge's upload OVERWRITES ./metube/config/cookies.txt
# (the landing cookie-sync propagates it), clobbering the operator's real cookies. Back
# them up before and RESTORE on every exit path, so the test leaves the target quiescent.
# The live file is written by the container's user-namespaced uid (rootless podman), so
# `podman unshare` is the sanctioned way to read/write it from the host.
_CUC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_CUC_COOKIES="$_CUC_ROOT/metube/config/cookies.txt"
_CUC_BACKUP="/tmp/cuc_real_cookies_$$.txt"
_CUC_RT="$(command -v podman || command -v docker || echo podman)"
_cuc_unshare_cp() { "$_CUC_RT" unshare cp "$1" "$2" 2>/dev/null || cp "$1" "$2" 2>/dev/null || true; }
_cuc_restore() { [ -f "$_CUC_BACKUP" ] && { _cuc_unshare_cp "$_CUC_BACKUP" "$_CUC_COOKIES"; rm -f "$_CUC_BACKUP"; }; }
trap _cuc_restore EXIT
[ -f "$_CUC_COOKIES" ] && _cuc_unshare_cp "$_CUC_COOKIES" "$_CUC_BACKUP"

echo "[1/3] Preparing test cookies file..."
COOKIES_FILE="/tmp/test_cookies_$$.txt"
cat > "$COOKIES_FILE" << 'COOKIE'
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	FALSE	1809370960	VISITOR_INFO1_LIVE	test123
COOKIE

echo "[2/3] Uploading cookies to landing page..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -F "cookies=@$COOKIES_FILE" \
    http://localhost:8086/api/upload-cookies 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
rm -f "$COOKIES_FILE"

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}FAIL: Upload returned HTTP $HTTP_CODE${NC}"
    exit 1
fi
echo "    Upload accepted (HTTP 200)"

echo "[3/3] Verifying cookies landed on disk..."
if [ -f "./metube/config/cookies.txt" ] && [ -s "./metube/config/cookies.txt" ]; then
    if grep -q "youtube.com" ./metube/config/cookies.txt; then
        echo -e "${GREEN}PASS: cookies.txt exists on disk with youtube.com domain${NC}"
    else
        echo -e "${RED}FAIL: cookies.txt exists but missing expected domain${NC}"
        exit 1
    fi
else
    echo -e "${RED}FAIL: cookies.txt not found or empty on disk${NC}"
    exit 1
fi
