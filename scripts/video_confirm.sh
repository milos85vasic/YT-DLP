#!/usr/bin/env bash
# §11.4.153 feature video/visual confirmation via the HelixAgent ensemble.
# Purpose: capture a window-scoped frame of a running feature (§11.4.154), send it
#   to the live HelixAgent multimodal API (/v1/chat/completions), and record the
#   ensemble's PASS/FAIL verdict — no bluff, the real model answer is written out.
# Usage: scripts/video_confirm.sh [scope] [url]   (default: dashboard http://localhost:9090)
# Inputs: a running feature surface (default dashboard :9090); live HelixAgent :7061.
# Outputs: recording ytdlp---<scope>---<ts>.png in /Volumes/T7/Downloads/Recordings;
#   verdict + raw response in docs/qa/video-confirm-<date>/VERDICT.md.
# Side-effects: rotates ONLY this project's own ytdlp---<scope>---* captures (§11.4.154/§11.4.122).
# Dependencies: node/npx + Playwright (tests/e2e), curl, python3, base64. HelixAgent on :7061.
set -uo pipefail
cd /Volumes/T7/Projects/ytdlp || exit 1
SCOPE="${1:-dashboard}"
URL="${2:-http://localhost:9090}"
PREFIX="ytdlp"           # §11.4.155 project-name prefix (HELIX_RELEASE_PREFIX unset -> root dir)
REC="/Volumes/T7/Downloads/Recordings"
HA="${HELIXAGENT_URL:-http://localhost:7061}"
OUT="docs/qa/video-confirm-20260616"
mkdir -p "$OUT" "$REC"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
SHOT="$REC/${PREFIX}---${SCOPE}---${TS}.png"
V="$OUT/VERDICT.md"

echo "# §11.4.153 video-confirmation — $SCOPE @ $TS" > "$V"

# §11.4.154 fresh-corpus rotation: remove ONLY our own prior in-scope captures (never foreign/operator files)
find "$REC" -maxdepth 1 -type f -name "${PREFIX}---${SCOPE}---*" ! -name "$(basename "$SHOT")" -delete 2>/dev/null
echo "- rotation: removed prior ${PREFIX}---${SCOPE}---* (kept foreign helix*-/operator files)" >> "$V"

# 1. window-scoped capture (Playwright viewport screenshot)
capture() { (cd tests/e2e && npx --yes playwright screenshot --viewport-size=1366,900 --wait-for-timeout=3000 "$URL" "$SHOT"); }
if ! capture 2>"$OUT/capture.err"; then
  echo "  (first capture failed; installing chromium then retrying)" >&2
  (cd tests/e2e && npx --yes playwright install chromium) >>"$OUT/capture.err" 2>&1
  capture 2>>"$OUT/capture.err" || true
fi
if [ -s "$SHOT" ]; then
  SZ=$(stat -f%z "$SHOT" 2>/dev/null || stat -c%s "$SHOT")
  echo "- capture: OK -> $SHOT ($SZ bytes, window-scoped viewport §11.4.154)" >> "$V"
else
  echo "- capture: BLOCKED — Playwright could not screenshot $URL (§11.4.21)" >> "$V"
  tail -4 "$OUT/capture.err" >> "$V"; cat "$V"; exit 0
fi

# 2. HelixAgent live?
HH=$(curl -s --max-time 5 "$HA/health" 2>/dev/null)
echo "- HelixAgent $HA/health: ${HH:-UNREACHABLE}" >> "$V"
[ -n "$HH" ] || { echo "- BLOCKED: HelixAgent not reachable (§11.4.21)" >> "$V"; cat "$V"; exit 0; }

# 3. multimodal POST (base64 data-URI image_url) + parse verdict
B64=$(base64 < "$SHOT" | tr -d '\n')
REQ=$(python3 - "$B64" <<'PY'
import json,sys
b64=sys.argv[1]
prompt=("You are verifying a self-hosted yt-dlp DASHBOARD web UI. Examine this screenshot. "
        "Does it show a WORKING dashboard (queue/history/download UI rendering normally, "
        "no crash, blank page, stack trace, or error overlay)? "
        'Reply with ONLY compact JSON: {"verdict":"PASS"|"FAIL","reason":"<short>"}')
print(json.dumps({"messages":[{"role":"user","content":[
  {"type":"text","text":prompt},
  {"type":"image_url","image_url":{"url":"data:image/png;base64,"+b64}}]}],"max_tokens":300}))
PY
)
RESP=$(curl -s --max-time 120 -X POST "$HA/v1/chat/completions" -H 'Content-Type: application/json' \
  ${HELIXAGENT_API_KEY:+-H "Authorization: Bearer $HELIXAGENT_API_KEY"} -d "$REQ")
{
  echo "- HelixAgent /v1/chat/completions raw (first 700 chars):"
  echo '```'; printf '%s' "$RESP" | head -c 700; echo; echo '```'
} >> "$V"
echo "$RESP" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    c=d.get('choices',[{}])[0].get('message',{}).get('content','')
    print('- ENSEMBLE VERDICT (content):', c)
except Exception as e:
    print('- PARSE NOTE:', e, '(see raw above — model/key may be needed for vision)')
" >> "$V"
echo "_finished $(date -u +%Y-%m-%dT%H:%M:%SZ)_" >> "$V"
cat "$V"
