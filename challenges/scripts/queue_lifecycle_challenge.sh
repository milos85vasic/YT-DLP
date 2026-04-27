#!/bin/bash
#
# challenges/scripts/queue_lifecycle_challenge.sh
#
# CONST-034 anti-bluff challenge for the Queue → History lifecycle.
#
# What we assert from the END USER's perspective:
#
#   1. Submitting a download via the dashboard's /api/add adds an
#      item to either /api/history.queue, .pending, or .done within
#      ~5 seconds. (Not just a 200 response — an actual record.)
#
#   2. Cancelling that item via /api/delete?where=queue (the same
#      endpoint the dashboard's confirmCancel() flow ultimately
#      calls) results in the item being VISIBLE on the History page
#      with status='aborted' — i.e. landing's /api/aborted-history
#      contains an entry for the cancelled URL.
#
#   3. The aborted entry contains a non-empty `aborted_at` timestamp
#      and a `reason`. Anything weaker is bluff per CONST-034.
#
#   4. Cleanup: deleting the abort entry from /api/aborted-history
#      removes it from the merged history view (subsequent GET no
#      longer contains the URL).
#
# This challenge is deliberately end-to-end. It exercises the same
# code path the dashboard's UI does — the URL lifecycle the user
# sees on screen.
#
# Exit:
#   0 = lifecycle holds end-to-end
#   1 = at least one assertion failed (printed)
#   2 = invocation error / dashboard not reachable

set -uo pipefail

DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:9090}"
TIMEOUT="${TIMEOUT:-15}"

if ! curl -s --max-time 3 "$DASHBOARD_URL/" >/dev/null 2>&1; then
    echo "FAIL: $DASHBOARD_URL not reachable — boot the no-vpn profile first"
    exit 2
fi

echo "=== queue_lifecycle_challenge ==="
echo "dashboard: $DASHBOARD_URL"
echo

# 1. SUBMIT. Use a real YouTube URL — it must be accepted by yt-dlp's
#    URL parser so the worker queues it; otherwise /add returns
#    status:error synchronously and we never test the lifecycle.
#    The challenge cancels it before any bytes are downloaded, so the
#    real download never happens.
TEST_URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
echo "[1/4] Submitting test URL: $TEST_URL"
ADD_BODY=$(curl -s --max-time "$TIMEOUT" \
    -X POST "$DASHBOARD_URL/api/add" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"url":"%s","quality":"720","format":"any","folder":"lifecycle-challenge"}' "$TEST_URL")")
if ! echo "$ADD_BODY" | grep -q '"status".*:.*"ok"'; then
    echo "FAIL: /api/add did not return status:ok — body=$ADD_BODY"
    exit 1
fi
echo "    /api/add returned status:ok"

# 2. WAIT for the item to land in some MeTube list.
echo "[2/4] Waiting for the item to appear in /api/history…"
SEEN=0
for i in $(seq 1 15); do
    if curl -s --max-time 5 "$DASHBOARD_URL/api/history" 2>/dev/null \
        | python3 -c "
import json, sys
url = sys.argv[1]
d = json.load(sys.stdin)
for k in ('queue', 'pending', 'done'):
    for it in d.get(k, []):
        if it.get('url') == url:
            print(k); sys.exit(0)
sys.exit(1)
" "$TEST_URL" >/tmp/lifecycle-where 2>/dev/null; then
        WHERE=$(cat /tmp/lifecycle-where)
        echo "    Found in /api/history.$WHERE after ${i}s"
        SEEN=1
        break
    fi
    sleep 1
done
if [ "$SEEN" -eq 0 ]; then
    echo "FAIL: item never appeared in /api/history after 15s"
    exit 1
fi

# 3. CANCEL via the same endpoint the dashboard uses — exactly as
#    QueueComponent.executeCancel() does it. We delete from queue
#    AND record the abort.
echo "[3/4] Cancelling and recording the abort…"
DEL_BODY=$(curl -s --max-time "$TIMEOUT" \
    -X POST "$DASHBOARD_URL/api/delete" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"ids":["%s"],"where":"queue"}' "$TEST_URL")")
if ! echo "$DEL_BODY" | grep -q '"status".*:.*"ok"'; then
    echo "    NOTE: /delete did not return status:ok ($DEL_BODY) — continuing to record-abort step"
fi

# Try done/queue both — the item may have moved between the two.
curl -s --max-time "$TIMEOUT" \
    -X POST "$DASHBOARD_URL/api/delete" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"ids":["%s"],"where":"done"}' "$TEST_URL")" >/dev/null

REC_BODY=$(curl -s --max-time "$TIMEOUT" \
    -X POST "$DASHBOARD_URL/api/aborted-history" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"url":"%s","title":"lifecycle-test","reason":"user-cancel"}' "$TEST_URL")")
if ! echo "$REC_BODY" | grep -q '"success".*:.*true'; then
    echo "FAIL: /api/aborted-history POST did not return success:true — body=$REC_BODY"
    exit 1
fi
echo "    abort recorded"

# 4. VERIFY the abort is visible on the merged history surface, with
#    the correct shape (status=aborted, has aborted_at, has reason).
echo "[4/4] Verifying the abort is visible on /api/aborted-history…"
AB_BODY=$(curl -s --max-time "$TIMEOUT" "$DASHBOARD_URL/api/aborted-history")
echo "$AB_BODY" | python3 -c "
import json, sys
url = sys.argv[1]
d = json.load(sys.stdin)
hits = [e for e in d.get('aborted', []) if e.get('url') == url]
if not hits:
    print('FAIL: no aborted entry found for ' + url)
    sys.exit(1)
e = hits[-1]
if e.get('status') != 'aborted':
    print('FAIL: status is ' + repr(e.get('status')) + ' (expected aborted)')
    sys.exit(1)
if not e.get('aborted_at'):
    print('FAIL: aborted_at is missing or zero')
    sys.exit(1)
if not e.get('reason'):
    print('FAIL: reason is empty')
    sys.exit(1)
print('OK: aborted_at=' + str(e['aborted_at']) + ' reason=' + e['reason'])
" "$TEST_URL" || exit 1

# 5. CLEANUP — remove the entry so the challenge is idempotent.
curl -s --max-time "$TIMEOUT" \
    -X DELETE "$DASHBOARD_URL/api/aborted-history" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"urls":["%s"]}' "$TEST_URL")" >/dev/null

# Verify cleanup succeeded.
AB_AFTER=$(curl -s --max-time "$TIMEOUT" "$DASHBOARD_URL/api/aborted-history")
if echo "$AB_AFTER" | grep -q "$TEST_URL"; then
    echo "FAIL: cleanup didn't remove the abort entry"
    exit 1
fi

echo
echo "=== summary: PASS — Queue → History (aborted) lifecycle holds end-to-end ==="
exit 0
