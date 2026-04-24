#!/bin/bash
#
# Test Suite Audit — Detect fantasy-land tests
# Flags tests that mock across boundaries instead of testing real behavior.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[AUDIT]${NC} $1"; }
log_good()  { echo -e "${GREEN}✓${NC} $1"; }
log_bad()   { echo -e "${RED}✗${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $1"; }

SCORE=0
MAX=0

score() {
    local name="$1" val="$2" threshold="$3"
    MAX=$((MAX + 10))
    if [ "$val" -ge "$threshold" ]; then
        log_good "$name: $val (≥ $threshold)"
        SCORE=$((SCORE + 10))
    else
        log_bad "$name: $val (need ≥ $threshold)"
        SCORE=$((SCORE + 5))
    fi
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Test Suite Quality Audit${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ── 1. Integration vs Mock ratio ─────────────────────────────────────
log_info "Checking test types in tests/..."

MOCK_COUNT=$(grep -rI "mock\|Mock\|stub\|Stub\|fake\|Fake" tests/ 2>/dev/null | wc -l)
HTTP_COUNT=$(grep -rI "curl\|http_get\|wget\|requests\.get\|requests\.post" tests/ 2>/dev/null | wc -l)
CONTAINER_COUNT=$(grep -rI "podman\|docker" tests/ 2>/dev/null | wc -l)
REAL_INTEGRATION=$((HTTP_COUNT + CONTAINER_COUNT))

echo "  Mock/stub references: $MOCK_COUNT"
echo "  Real HTTP calls:      $HTTP_COUNT"
echo "  Container runtime refs: $CONTAINER_COUNT"

if [ "$MOCK_COUNT" -gt "$REAL_INTEGRATION" ]; then
    log_bad "Mock count ($MOCK_COUNT) exceeds real integration ($REAL_INTEGRATION)"
    log_warn "  → Your tests live in fantasy-land. Add real HTTP/container tests."
else
    log_good "Real integration ($REAL_INTEGRATION) exceeds mocks ($MOCK_COUNT)"
fi

# ── 2. E2E / Smoke tests exist? ──────────────────────────────────────
log_info "Checking for E2E / smoke tests..."
SMOKE_COUNT=$(find scripts/ -name "*smoke*" -o -name "*e2e*" 2>/dev/null | wc -l)
score "E2E/Smoke scripts" "$SMOKE_COUNT" 1

# ── 3. Contract / API specs exist? ───────────────────────────────────
log_info "Checking for API contracts..."
CONTRACT_COUNT=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "openapi\|swagger" 2>/dev/null | wc -l)
score "API contract specs" "$CONTRACT_COUNT" 1

# ── 4. Health check endpoint tests ───────────────────────────────────
log_info "Checking for health check validation..."
HEALTH_COUNT=$(grep -rI "health\|/health" tests/ 2>/dev/null | wc -l)
score "Health check tests" "$HEALTH_COUNT" 1

# ── 5. Error state tests ─────────────────────────────────────────────
log_info "Checking for error-state tests..."
ERROR_COUNT=$(grep -rI "error\|Error\|fail\|Fail\|500\|404\|timeout" tests/ 2>/dev/null | wc -l)
score "Error-state coverage" "$ERROR_COUNT" 5

# ── 6. Dashboard component tests ─────────────────────────────────────
log_info "Checking dashboard test coverage..."
DASH_TEST_COUNT=$(find tests/ -name "*dashboard*" -o -name "*angular*" -o -name "*ui*" 2>/dev/null | wc -l)
score "Dashboard-specific tests" "$DASH_TEST_COUNT" 1

# ── 7. CI pipeline runs smoke tests? ─────────────────────────────────
log_info "Checking CI for smoke test execution..."
CI_SMOKE=$(grep -rI "smoke\|e2e\|integration" .github/workflows/ 2>/dev/null | wc -l)
score "CI smoke/E2E integration" "$CI_SMOKE" 1

# ── 8. AGENTS.md has verification gates? ─────────────────────────────
log_info "Checking AGENTS.md for verification discipline..."
AGENT_GATES=0
if [ -f AGENTS.md ]; then
    if grep -qi "definition of done\|verification\|gate\|manual test\|smoke test" AGENTS.md; then
        AGENT_GATES=1
    fi
fi
score "AGENTS.md verification gates" "$AGENT_GATES" 1

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Audit Score: ${SCORE}/${MAX}${NC}"
echo -e "${CYAN}============================================${NC}"

PCT=$((SCORE * 100 / MAX))
if [ "$PCT" -ge 80 ]; then
    echo -e "${GREEN}STRONG test suite — likely reflects reality${NC}"
elif [ "$PCT" -ge 50 ]; then
    echo -e "${YELLOW}MODERATE — add more integration/smoke tests${NC}"
else
    echo -e "${RED}WEAK — high risk of 'green tests, broken product'${NC}"
fi

echo ""
echo "Remediations:"
if [ "$SMOKE_COUNT" -lt 1 ]; then
    echo "  1. Create scripts/smoke-test.sh that hits real endpoints"
fi
if [ "$CONTRACT_COUNT" -lt 1 ]; then
    echo "  2. Write OpenAPI specs in contracts/ and generate clients"
fi
if [ "$AGENT_GATES" -lt 1 ]; then
    echo "  3. Update AGENTS.md with Gate 4 Definition of Done"
fi
if [ "$MOCK_COUNT" -gt "$REAL_INTEGRATION" ]; then
    echo "  4. Replace mock-heavy tests with real HTTP/container tests"
fi
