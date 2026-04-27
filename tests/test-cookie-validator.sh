#!/bin/bash
#
# Unit tests for landing/app.py:_validate_cookie_file
#
# Exercises the validator's recognised-domain whitelist directly against
# the live Python source (no mocks). Each fixture is a minimal valid
# Netscape cookie file scoped to one platform; the validator must accept
# every supported platform and reject files with no recognised domain.
#
# NOTE: do NOT use `set -u` / `set -e` here — when run-tests.sh sources
# this file, those flags would leak into the orchestrator and silently
# break later phases that rely on optional environment vars.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LANDING_DIR="$PROJECT_DIR/landing"

# shellcheck disable=SC1091
if [ -f "$PROJECT_DIR/tests/test-helpers.sh" ]; then
    source "$PROJECT_DIR/tests/test-helpers.sh"
fi

_validator_verdict() {
    # $1 = path to a Netscape-format cookie fixture
    # echoes "ACCEPT" or "REJECT: <message>"
    python3 - "$1" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "landing")) if False else None
# Resolve landing/ relative to PROJECT_DIR passed via env.
project_dir = os.environ.get("PROJECT_DIR") or os.getcwd()
sys.path.insert(0, os.path.join(project_dir, "landing"))
from app import _validate_cookie_file
with open(sys.argv[1], "r", encoding="utf-8") as f:
    content = f.read()
ok, msg = _validate_cookie_file(content)
print("ACCEPT" if ok else f"REJECT: {msg}")
PY
}

_make_fixture() {
    # $1 = domain (e.g. tiktok.com)
    # $2 = output path
    cat > "$2" <<EOF
# Netscape HTTP Cookie File
# https://curl.se/docs/http-cookies.html
.${1}	TRUE	/	TRUE	2000000000	sessionid	abc123fake
.${1}	TRUE	/	FALSE	2000000000	csrftoken	xyz789fake
EOF
}

_assert_accept() {
    local domain="$1"
    local fixture
    fixture=$(mktemp)
    _make_fixture "$domain" "$fixture"
    local verdict
    verdict=$(PROJECT_DIR="$PROJECT_DIR" _validator_verdict "$fixture")
    rm -f "$fixture"
    if [[ "$verdict" == "ACCEPT" ]]; then
        echo "  PASS: $domain accepted"
        return 0
    fi
    echo "  FAIL: $domain rejected — $verdict"
    return 1
}

_assert_reject() {
    local domain="$1"
    local fixture
    fixture=$(mktemp)
    _make_fixture "$domain" "$fixture"
    local verdict
    verdict=$(PROJECT_DIR="$PROJECT_DIR" _validator_verdict "$fixture")
    rm -f "$fixture"
    if [[ "$verdict" == REJECT* ]]; then
        echo "  PASS: $domain rejected — $verdict"
        return 0
    fi
    echo "  FAIL: $domain unexpectedly accepted"
    return 1
}

test_validator_accepts_extended_video_platforms() {
    local fail=0
    # Pre-existing recognised platforms (regression check)
    _assert_accept "youtube.com"   || fail=1
    _assert_accept "vimeo.com"     || fail=1
    _assert_accept "soundcloud.com" || fail=1
    # Newly recognised platforms (the feature under test)
    _assert_accept "tiktok.com"    || fail=1
    _assert_accept "bilibili.com"  || fail=1
    _assert_accept "facebook.com"  || fail=1
    _assert_accept "fb.watch"      || fail=1
    _assert_accept "twitter.com"   || fail=1
    _assert_accept "x.com"         || fail=1
    _assert_accept "threads.net"   || fail=1
    return "$fail"
}

test_validator_still_rejects_unknown_domain() {
    _assert_reject "example.invalid"
}

test_summarize_cookies_by_platform_groups_correctly() {
    # Build a cookies file with 3 youtube + 2 tiktok + 1 facebook
    # entries, varying expiries, then assert the helper buckets them
    # correctly per platform.
    local fixture
    fixture=$(mktemp)
    cat > "$fixture" <<'EOF'
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	TRUE	2000000000	SID	abc
.youtube.com	TRUE	/	TRUE	2000000100	HSID	def
.google.com	TRUE	/	TRUE	1900000000	NID	ghi
.tiktok.com	TRUE	/	TRUE	2100000000	sessionid	tik1
.tiktok.com	TRUE	/	FALSE	2100000050	csrftoken	tik2
.facebook.com	TRUE	/	TRUE	2200000000	c_user	fb1
EOF

    local out
    out=$(PROJECT_DIR="$PROJECT_DIR" python3 - "$fixture" <<'PY'
import json, os, sys
sys.path.insert(0, os.path.join(os.environ["PROJECT_DIR"], "landing"))
from app import _summarize_cookies_by_platform
with open(sys.argv[1], "r", encoding="utf-8") as f:
    content = f.read()
print(json.dumps(_summarize_cookies_by_platform(content), sort_keys=True))
PY
)
    rm -f "$fixture"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  FAIL: helper raised — $out"
        return 1
    fi

    # Assertions: youtube bucket sees 3 cookies (youtube.com twice + google.com once),
    # tiktok 2, facebook 1, no other platforms.
    if ! echo "$out" | grep -q '"youtube"'; then
        echo "  FAIL: youtube bucket missing in $out"; return 1
    fi
    if ! echo "$out" | grep -q '"tiktok"'; then
        echo "  FAIL: tiktok bucket missing in $out"; return 1
    fi
    if ! echo "$out" | grep -q '"facebook"'; then
        echo "  FAIL: facebook bucket missing in $out"; return 1
    fi
    # Counts via grep on the JSON shape — youtube should have count=3
    yt_count=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["youtube"]["session_count"])')
    if [ "$yt_count" != "3" ]; then
        echo "  FAIL: youtube session_count expected 3, got $yt_count"; return 1
    fi
    tk_count=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["tiktok"]["session_count"])')
    if [ "$tk_count" != "2" ]; then
        echo "  FAIL: tiktok session_count expected 2, got $tk_count"; return 1
    fi
    echo "  PASS: per-platform breakdown groups cookies correctly"
}

run_cookie_validator_tests() {
    if type log_info &> /dev/null; then
        log_info "Running Cookie Validator Tests..."
    else
        echo "[INFO] Running Cookie Validator Tests..."
    fi

    if [ ! -f "$LANDING_DIR/app.py" ]; then
        echo "  SKIP: $LANDING_DIR/app.py not found"
        return 0
    fi

    if ! python3 -c "import flask, requests" 2>/dev/null; then
        echo "  SKIP: flask/requests not importable from host python3"
        return 0
    fi

    if type run_test &> /dev/null; then
        run_test "test_validator_accepts_extended_video_platforms" test_validator_accepts_extended_video_platforms
        run_test "test_validator_still_rejects_unknown_domain" test_validator_still_rejects_unknown_domain
        run_test "test_summarize_cookies_by_platform_groups_correctly" test_summarize_cookies_by_platform_groups_correctly
    else
        # Standalone mode
        local pass=0 fail=0
        if test_validator_accepts_extended_video_platforms; then ((pass++)); else ((fail++)); fi
        if test_validator_still_rejects_unknown_domain; then ((pass++)); else ((fail++)); fi
        if test_summarize_cookies_by_platform_groups_correctly; then ((pass++)); else ((fail++)); fi
        echo "Pass: $pass  Fail: $fail"
        [ "$fail" -eq 0 ]
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_cookie_validator_tests
fi
