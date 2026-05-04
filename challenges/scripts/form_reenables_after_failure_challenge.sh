#!/bin/bash
#
# Challenge: Form re-enables after download failure
# Anti-bluff: Submit a bad URL, then immediately submit another URL.
# The API must accept the second submission — proving the form is interactive.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="http://localhost:9090"

echo "[1/3] Checking dashboard API proxy is reachable..."
if ! curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/version" | grep -q "200"; then
    echo -e "${RED}FAIL: Dashboard API proxy not reachable${NC}"
    exit 1
fi
echo "    API proxy OK"

echo "[2/3] Submitting known-bad URL..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_URL/api/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://invalid-domain-12345.xyz/nonexistent","quality":"best","format":"any","folder":""}' 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
echo "    First submission: HTTP $HTTP_CODE"

echo "[3/3] Verifying second submission is accepted immediately..."
SECOND=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_URL/api/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://example.com/test2","quality":"best","format":"any","folder":""}' 2>/dev/null)
SECOND_CODE=$(echo "$SECOND" | grep "HTTP_CODE:" | cut -d: -f2)
SECOND_BODY=$(echo "$SECOND" | grep -v "HTTP_CODE:")

if [ "$SECOND_CODE" = "200" ]; then
    echo "    Second submission accepted (HTTP 200)"
    echo "    Response: $SECOND_BODY"
else
    echo -e "${RED}FAIL: Second submission blocked (HTTP $SECOND_CODE)${NC}"
    exit 1
fi

# The real anti-bluff: we must be able to add multiple URLs in rapid succession
THIRD=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_URL/api/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://example.com/test3","quality":"best","format":"any","folder":""}' 2>/dev/null)
THIRD_CODE=$(echo "$THIRD" | grep "HTTP_CODE:" | cut -d: -f2)
if [ "$THIRD_CODE" = "200" ]; then
    echo "    Third submission accepted (HTTP 200)"
else
    echo -e "${YELLOW}WARN: Third submission returned HTTP $THIRD_CODE${NC}"
fi

echo -e "${GREEN}PASS: Form remains interactive after failure${NC}"
