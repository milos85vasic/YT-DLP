#!/bin/bash
#
# check-recognised-domains-sync.sh
#
# Asserts that the recognised-cookie-platform set in landing/app.py
# (`_validate_cookie_file` → `recognised = {...}`) matches the set
# documented in contracts/metube-api.openapi.yaml under the description
# of /upload-cookies. The two are independent sources of truth; drift
# between them silently breaks either the validator (rejecting a
# documented platform) or the contract (claiming support that doesn't
# exist).
#
# Exit:
#   0 = both sets match
#   1 = drift detected (printed)
#   2 = invocation error / files not found
#
# Wired into ./scripts/dev-check.sh as a pre-commit gate.

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APP_PY="$PROJECT_DIR/landing/app.py"
OPENAPI="$PROJECT_DIR/contracts/metube-api.openapi.yaml"

if [ ! -f "$APP_PY" ]; then
    echo "ERROR: $APP_PY not found" >&2
    exit 2
fi
if [ ! -f "$OPENAPI" ]; then
    echo "ERROR: $OPENAPI not found" >&2
    exit 2
fi

# Extract domains from landing/app.py — the validator's `recognised = {...}`
# block. We use Python's AST so we don't depend on regex hygiene.
APP_DOMAINS=$(python3 - "$APP_PY" <<'PY'
import ast, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    tree = ast.parse(f.read())

for node in ast.walk(tree):
    if not isinstance(node, ast.FunctionDef):
        continue
    if node.name != "_validate_cookie_file":
        continue
    for stmt in ast.walk(node):
        if isinstance(stmt, ast.Assign):
            for target in stmt.targets:
                if isinstance(target, ast.Name) and target.id == "recognised":
                    if isinstance(stmt.value, ast.Set):
                        for elt in stmt.value.elts:
                            if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                print(elt.value)
                        sys.exit(0)
print("ERROR: could not find `recognised = {...}` set in _validate_cookie_file", file=sys.stderr)
sys.exit(2)
PY
)
APP_RC=$?
if [ "$APP_RC" -ne 0 ]; then
    echo "$APP_DOMAINS" >&2
    exit "$APP_RC"
fi

# Extract domains from OpenAPI — they live inside the /upload-cookies
# description as a comma-separated list following the literal phrase
# "current recognised set covers" (substring match against the
# dot-stripped cookie domain). Anchor on that phrase to avoid picking
# up unrelated mentions.
OPENAPI_DOMAINS=$(python3 - "$OPENAPI" <<'PY'
import re, sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()

# Find the /upload-cookies description block.
m = re.search(
    r"/upload-cookies:.*?recognised\s+set\s+covers[^:]*:(.+?)(?:A single file|\.\s*$|\Z)",
    text,
    flags=re.DOTALL | re.IGNORECASE,
)
if not m:
    print("ERROR: could not locate the recognised-set list in OpenAPI /upload-cookies description", file=sys.stderr)
    sys.exit(2)

block = m.group(1)
# Domains: a-z 0-9 dot hyphen, ending in a TLD letter run. The middle
# class uses `*` (not `+`) so single-letter domains like x.com match.
# We anchor on a leading word boundary and a 2+ letter TLD.
candidates = re.findall(r"\b[a-z0-9][a-z0-9\-.]*\.[a-z]{2,}\b", block, flags=re.IGNORECASE)
for c in candidates:
    print(c.lower())
PY
)
OPENAPI_RC=$?
if [ "$OPENAPI_RC" -ne 0 ]; then
    echo "$OPENAPI_DOMAINS" >&2
    exit "$OPENAPI_RC"
fi

# Sort + uniq both sets, compare.
APP_SORTED=$(echo "$APP_DOMAINS"     | sort -u)
OAS_SORTED=$(echo "$OPENAPI_DOMAINS" | sort -u)

if [ "$APP_SORTED" = "$OAS_SORTED" ]; then
    count=$(echo "$APP_SORTED" | wc -l | tr -d ' ')
    echo "OK: $count recognised domains in sync between landing/app.py and contracts/metube-api.openapi.yaml"
    exit 0
fi

echo "FAIL: recognised-domain set drifted between landing/app.py and OpenAPI"
echo
echo "In app.py but missing from OpenAPI description:"
comm -23 <(echo "$APP_SORTED") <(echo "$OAS_SORTED") | sed 's/^/  - /'
echo
echo "In OpenAPI description but missing from app.py:"
comm -13 <(echo "$APP_SORTED") <(echo "$OAS_SORTED") | sed 's/^/  - /'
echo
echo "Fix one of the two so they match. The validator code is the"
echo "behavioural source of truth; the OpenAPI text exists to document"
echo "what the validator accepts."
exit 1
