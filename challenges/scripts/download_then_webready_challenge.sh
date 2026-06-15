#!/bin/bash
#
# Challenge: Download completes AND the web-ready dual-version artifact is produced
#
# Purpose:
#   Anti-bluff Challenge for the dual-version media pipeline. It goes one step
#   FURTHER than download_completes_challenge.sh (constitution §11.4.108 ARTIFACT
#   rule): after the original download reaches 'finished' via the MeTube /add API,
#   it stat-verifies BOTH the original file AND the media_postprocessor outputs:
#     - a video download MUST yield `webready-<base>.mp4` alongside the original,
#       and ffprobe MUST show H.264 video + AAC audio + non-zero duration +
#       faststart (moov atom before mdat — progressive playback);
#     - an audio download MUST yield `<base>.mp3`, and ffprobe MUST show mp3.
#   "Download succeeded" != "/add returned 200": this proves the artifact exists
#   on the host and is genuinely playable. The bluff-test rule applies — "if I
#   deleted the media_postprocessor implementation, would this test still pass?"
#   MUST be NO (the webready/ffprobe assertions FAIL when the artifact is missing).
#
# Usage:
#   bash challenges/scripts/download_then_webready_challenge.sh
#   MODE=audio bash challenges/scripts/download_then_webready_challenge.sh
#
# Inputs (environment):
#   .env          (optional) sourced for DOWNLOAD_DIR + METUBE_DIRECT_PORT.
#   DOWNLOAD_DIR  Host path where MeTube + the postprocessor write files.
#                 Falls back to .env, else /mnt/downloads.
#   API_URL       MeTube Direct base URL (default http://localhost:<port|8088>).
#   MODE          'video' (default) or 'audio' — selects which artifact to assert.
#   TEST_URL      Override the test media URL.
#   TIMEOUT       Seconds to wait for /history status=finished (default 180).
#   WEBREADY_TIMEOUT  Seconds to wait for the postprocessor artifact (default 120).
#
# Outputs:
#   stdout progress log; exit 0 = PASS (every artifact proven), exit 1 = FAIL.
#
# Side-effects:
#   Submits one download to the running MeTube instance and removes it from
#   history on success. Reads files on DOWNLOAD_DIR from the host's POV.
#
# Dependencies:
#   curl, python3 (JSON parsing), ffprobe (codec/duration/faststart probe),
#   stat, a running MeTube + media_postprocessor stack (Phase-7 integration).
#   lib/container-runtime.sh for the runtime-detection idiom (parity with peers).
#
# Cross-references:
#   download_completes_challenge.sh (the ARTIFACT-rule reference template),
#   CLAUDE.md "The bluff test (CONST-034)" + ARTIFACT rule, constitution §11.4.108.
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Locate repo root + source idioms ---------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Container-runtime detection idiom (parity with peer challenges).
if [ -f "$REPO_ROOT/lib/container-runtime.sh" ]; then
    # shellcheck source=/dev/null
    . "$REPO_ROOT/lib/container-runtime.sh"
    RUNTIME="$(detect_container_runtime)"
else
    RUNTIME="unknown"
fi

# Load DOWNLOAD_DIR + ports from .env exactly like the rest of the project.
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$REPO_ROOT/.env"
    set +a
fi

DOWNLOAD_DIR="${DOWNLOAD_DIR:-/mnt/downloads}"
METUBE_DIRECT_PORT="${METUBE_DIRECT_PORT:-8088}"
API_URL="${API_URL:-http://localhost:${METUBE_DIRECT_PORT}}"
MODE="${MODE:-video}"
TIMEOUT="${TIMEOUT:-180}"
WEBREADY_TIMEOUT="${WEBREADY_TIMEOUT:-120}"

if [ "$MODE" = "audio" ]; then
    TEST_URL="${TEST_URL:-https://vimeo.com/108018156}"
    QUALITY="best"
    FORMAT="mp3"
else
    TEST_URL="${TEST_URL:-https://vimeo.com/108018156}"
    QUALITY="best"
    FORMAT="any"
fi

echo "=== download_then_webready_challenge ==="
echo "mode:             $MODE"
echo "test url:         $TEST_URL"
echo "api url:          $API_URL"
echo "download dir:     $DOWNLOAD_DIR"
echo "container runtime:$RUNTIME"
echo "timeout:          ${TIMEOUT}s (download), ${WEBREADY_TIMEOUT}s (webready)"
echo ""

# --- Pre-flight: dependencies + DOWNLOAD_DIR reachable -----------------------
for dep in curl python3 ffprobe stat; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "${RED}FAIL: required dependency '$dep' not found on host${NC}"
        exit 1
    fi
done

if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo -e "${RED}FAIL: DOWNLOAD_DIR does not exist on host: $DOWNLOAD_DIR${NC}"
    echo "      (stack not initialized? run 'make init' / './start_no_vpn')"
    exit 1
fi

# --- Helper: ffprobe a single stream property --------------------------------
ffprobe_value() {
    # $1 = file, $2 = stream selector (v:0/a:0), $3 = entry
    ffprobe -v error -select_streams "$2" \
        -show_entries "stream=$3" -of default=nw=1:nk=1 "$1" 2>/dev/null | head -n1
}

# --- Helper: assert moov before mdat (faststart) -----------------------------
assert_faststart() {
    # Reads the top-level atom order; faststart => moov appears before mdat.
    local file="$1"
    python3 - "$file" <<'PY'
import sys, struct
path = sys.argv[1]
moov = mdat = None
pos = 0
with open(path, 'rb') as f:
    while True:
        header = f.read(8)
        if len(header) < 8:
            break
        size = struct.unpack('>I', header[:4])[0]
        atype = header[4:8].decode('latin-1')
        if atype == 'moov' and moov is None:
            moov = pos
        if atype == 'mdat' and mdat is None:
            mdat = pos
        if size == 1:  # 64-bit extended size
            ext = f.read(8)
            if len(ext) < 8:
                break
            size = struct.unpack('>Q', ext)[0]
        if size == 0:  # extends to EOF
            break
        pos += size
        f.seek(pos)
        if moov is not None and mdat is not None:
            break
if moov is None or mdat is None:
    print("missing")
    sys.exit(2)
print("faststart" if moov < mdat else "slow")
sys.exit(0 if moov < mdat else 1)
PY
}

# --- Take before snapshot ----------------------------------------------------
BEFORE="$(mktemp)"
find "$DOWNLOAD_DIR" -type f -printf '%s %p\n' 2>/dev/null | sort > "$BEFORE" || true

cleanup() { rm -f "$BEFORE" "${AFTER:-}" 2>/dev/null || true; }
trap cleanup EXIT

# --- [1/5] Submit the test URL via /add --------------------------------------
echo "[1/5] Submitting test URL ($MODE)…"
RESPONSE="$(curl -s -X POST "$API_URL/add" \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"$TEST_URL\",\"quality\":\"$QUALITY\",\"format\":\"$FORMAT\",\"folder\":\"\"}" 2>/dev/null)"
echo "      /add returned $RESPONSE"

if ! echo "$RESPONSE" | grep -q '"status".*:.*"ok"'; then
    echo -e "${RED}FAIL: /add did not return status:ok${NC}"
    exit 1
fi

# --- [2/5] Wait for status=finished ------------------------------------------
echo "[2/5] Waiting up to ${TIMEOUT}s for status='finished'…"
FINISHED=false
START_TIME="$(date +%s)"
while true; do
    HISTORY="$(curl -s "$API_URL/history" 2>/dev/null)"

    URL_STATUS="$(echo "$HISTORY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print('parse_error'); sys.exit(0)
for section in ['queue', 'pending', 'done']:
    for item in data.get(section, []):
        if item.get('url') == '$TEST_URL':
            print(item.get('status', 'unknown')); sys.exit(0)
print('not_found')
" 2>/dev/null || echo "parse_error")"

    if [ "$URL_STATUS" = "finished" ]; then
        FINISHED=true
        break
    fi
    if [ "$URL_STATUS" = "error" ]; then
        ERROR_MSG="$(echo "$HISTORY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print('unknown'); sys.exit(0)
for section in ['queue', 'pending', 'done']:
    for item in data.get(section, []):
        if item.get('url') == '$TEST_URL':
            print(item.get('msg', 'unknown error')); sys.exit(0)
print('unknown')
" 2>/dev/null || echo "unknown")"
        echo -e "${RED}FAIL: download moved to status=error${NC}"
        echo "      msg: $ERROR_MSG"
        exit 1
    fi

    NOW="$(date +%s)"
    if [ "$((NOW - START_TIME))" -ge "$TIMEOUT" ]; then
        break
    fi
    sleep 2
done

if [ "$FINISHED" != "true" ]; then
    echo -e "${RED}FAIL: download did not finish within ${TIMEOUT}s${NC}"
    exit 1
fi

# --- [3/5] Verify the ORIGINAL file landed on disk (>1KB) --------------------
echo "[3/5] Download finished. Verifying original file on disk…"
AFTER="$(mktemp)"
find "$DOWNLOAD_DIR" -type f -printf '%s %p\n' 2>/dev/null | sort > "$AFTER" || true
NEW_FILES="$(comm -13 "$BEFORE" "$AFTER" | awk '{$1=$1; sub(/^[0-9]+ /,""); print}')"

if [ -z "$NEW_FILES" ]; then
    echo -e "${RED}FAIL: no new file appeared in $DOWNLOAD_DIR${NC}"
    exit 1
fi

# Find the original (non-webready) media file; derive its <base>.
ORIGINAL=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    bn="$(basename "$f")"
    case "$bn" in
        webready-*) ;;                 # skip the postprocessor output
        *.part|*.ytdl|*.tmp) ;;        # skip transient files
        *) ORIGINAL="$f" ;;
    esac
done <<EOF
$(comm -13 "$BEFORE" "$AFTER" | sed 's/^[0-9]* //')
EOF

if [ -z "$ORIGINAL" ] || [ ! -f "$ORIGINAL" ]; then
    echo -e "${RED}FAIL: could not identify the original downloaded file${NC}"
    echo "      new files were:"
    echo "$NEW_FILES" | sed 's/^/        /'
    exit 1
fi

ORIG_SIZE="$(stat -f '%z' "$ORIGINAL" 2>/dev/null || stat -c '%s' "$ORIGINAL" 2>/dev/null || echo 0)"
echo "      original: $ORIGINAL ($ORIG_SIZE bytes)"
if [ "$ORIG_SIZE" -lt 1024 ]; then
    echo -e "${RED}FAIL: original file is < 1KB — likely incomplete${NC}"
    exit 1
fi

ORIG_DIR="$(dirname "$ORIGINAL")"
ORIG_BASE="$(basename "$ORIGINAL")"
BASE_NOEXT="${ORIG_BASE%.*}"

# --- [4/5] Wait for the postprocessor artifact -------------------------------
if [ "$MODE" = "audio" ]; then
    ARTIFACT="$ORIG_DIR/${BASE_NOEXT}.mp3"
    ARTIFACT_DESC="audio mp3 (${BASE_NOEXT}.mp3)"
else
    ARTIFACT="$ORIG_DIR/webready-${BASE_NOEXT}.mp4"
    ARTIFACT_DESC="webready mp4 (webready-${BASE_NOEXT}.mp4)"
fi

echo "[4/5] Waiting up to ${WEBREADY_TIMEOUT}s for postprocessor artifact…"
echo "      expecting: $ARTIFACT"
WAITED=0
while [ ! -f "$ARTIFACT" ] && [ "$WAITED" -lt "$WEBREADY_TIMEOUT" ]; do
    sleep 2
    WAITED="$((WAITED + 2))"
done

if [ ! -f "$ARTIFACT" ]; then
    echo -e "${RED}FAIL: postprocessor artifact never appeared: $ARTIFACT${NC}"
    echo "      the media_postprocessor did not produce the $ARTIFACT_DESC."
    echo "      (this FAIL is the anti-bluff signal — the artifact is absent)"
    exit 1
fi

ART_SIZE="$(stat -f '%z' "$ARTIFACT" 2>/dev/null || stat -c '%s' "$ARTIFACT" 2>/dev/null || echo 0)"
echo "      artifact present: $ARTIFACT ($ART_SIZE bytes)"
if [ "$ART_SIZE" -lt 1024 ]; then
    echo -e "${RED}FAIL: artifact is < 1KB — postprocessor output is degenerate${NC}"
    exit 1
fi

# --- [5/5] ffprobe-assert the artifact is genuinely playable -----------------
echo "[5/5] ffprobe-verifying the artifact…"
ERRORS=0

if [ "$MODE" = "audio" ]; then
    A_CODEC="$(ffprobe_value "$ARTIFACT" "a:0" "codec_name")"
    A_DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$ARTIFACT" 2>/dev/null | head -n1)"
    echo "      audio codec:    $A_CODEC"
    echo "      duration:       $A_DUR"
    if [ "$A_CODEC" != "mp3" ]; then
        echo -e "${RED}      FAIL: audio codec is '$A_CODEC', expected 'mp3'${NC}"
        ERRORS=$((ERRORS+1))
    fi
    case "$A_DUR" in
        ""|"N/A"|0|0.*0) echo -e "${RED}      FAIL: non-positive duration${NC}"; ERRORS=$((ERRORS+1));;
    esac
    # Reject a zero/near-zero duration robustly.
    if ! python3 -c "import sys; sys.exit(0 if float('${A_DUR:-0}' or 0) > 0.5 else 1)" 2>/dev/null; then
        echo -e "${RED}      FAIL: duration <= 0.5s — not a real audio file${NC}"
        ERRORS=$((ERRORS+1))
    fi
else
    V_CODEC="$(ffprobe_value "$ARTIFACT" "v:0" "codec_name")"
    A_CODEC="$(ffprobe_value "$ARTIFACT" "a:0" "codec_name")"
    DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$ARTIFACT" 2>/dev/null | head -n1)"
    FASTSTART="$(assert_faststart "$ARTIFACT" || true)"
    echo "      video codec:    $V_CODEC (expect h264)"
    echo "      audio codec:    $A_CODEC (expect aac)"
    echo "      duration:       $DUR"
    echo "      moov ordering:  $FASTSTART (expect faststart)"

    if [ "$V_CODEC" != "h264" ]; then
        echo -e "${RED}      FAIL: video codec is '$V_CODEC', expected 'h264'${NC}"
        ERRORS=$((ERRORS+1))
    fi
    if [ "$A_CODEC" != "aac" ]; then
        echo -e "${RED}      FAIL: audio codec is '$A_CODEC', expected 'aac'${NC}"
        ERRORS=$((ERRORS+1))
    fi
    if ! python3 -c "import sys; sys.exit(0 if float('${DUR:-0}' or 0) > 0.5 else 1)" 2>/dev/null; then
        echo -e "${RED}      FAIL: duration <= 0.5s — not a real video file${NC}"
        ERRORS=$((ERRORS+1))
    fi
    if [ "$FASTSTART" != "faststart" ]; then
        echo -e "${RED}      FAIL: moov atom is not before mdat — not faststart (got '$FASTSTART')${NC}"
        ERRORS=$((ERRORS+1))
    fi
fi

if [ "$ERRORS" -ne 0 ]; then
    echo -e "${RED}FAIL: artifact failed $ERRORS ffprobe assertion(s) — feature not usable${NC}"
    exit 1
fi

# --- Cleanup: remove the test download from history --------------------------
echo "      Cleanup: removing test download from history…"
curl -s -X POST "$API_URL/delete" \
    -H "Content-Type: application/json" \
    -d "{\"ids\":[\"$TEST_URL\"],\"where\":\"done\"}" >/dev/null 2>&1 || true

echo -e "${GREEN}PASS: download finished AND $ARTIFACT_DESC verified playable via ffprobe${NC}"
