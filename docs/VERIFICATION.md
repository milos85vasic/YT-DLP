# Verification System — Gate 4

This document explains how we ensure code actually works before it reaches production.

## The Problem

> "Tests pass, but the product is broken."

This happens when:
- Tests mock everything and test implementation details, not behavior
- Agents optimize for "tests green" instead of "product works"
- No one manually verifies features in the running application
- API contracts are implicit and diverge between services

## The Solution: 4 Gates

No task is complete until it passes all 4 gates:

```
Gate 1: Contract Test
  → Does the API response match contracts/metube-api.openapi.yaml?

Gate 2: Integration Test  
  → Do real services talk to each other with real HTTP calls?
  → File: tests/test-integration-realhttp.sh

Gate 3: E2E Smoke Test
  → Does ./scripts/smoke-test.sh pass against running containers?
  → Tests: service availability, API contracts, user journeys, container health

Gate 4: Manual Acceptance
  → Human opens the dashboard at http://localhost:9090
  → Clicks through the feature, tests error cases, refreshes the page
```

## Quick Commands

```bash
# Full pre-push validation
make dev-check

# Or step by step:
./scripts/smoke-test.sh       # Gate 3
./scripts/test-audit.sh        # Quality gate
./tests/test-integration-realhttp.sh  # Gate 2
```

## CI Integration

The GitHub Actions `integration.yml` workflow runs Gates 2 and 3 automatically on every PR and push to `main`.

If smoke tests fail, the build is blocked.

## Agent Rules (for LLM agents)

When assigning work to an agent, always include:

1. **Context** — which service, who consumes it, contract file path
2. **Constraints** — no mocks across boundaries, must match OpenAPI spec
3. **Verification Steps** — run smoke-test.sh, include output in completion report

See `AGENTS.md` for the full template.

## Test Audit Score

Run `./scripts/test-audit.sh` to get a quality score (0-70).

| Score | Meaning |
|-------|---------|
| 70/70 | Strong — tests reflect reality |
| 50-69 | Moderate — add more integration/smoke tests |
| < 50 | Weak — high risk of green-tests-broken-product |

## When Manual Testing Finds a Bug

1. **Stop.** Don't just fix it.
2. Add a test to `scripts/smoke-test.sh` or `tests/test-integration-realhttp.sh` that would have caught it.
3. Update `AGENTS.md` if the bug reveals a missing constraint.
4. Fix the bug.
5. Verify the new test fails before the fix and passes after.

## Dashboard Error States

Every dashboard component must handle:

1. **Loading** — spinner while fetching
2. **Empty** — friendly message when no data
3. **Error** — visible message when API is unreachable
4. **Retry** — button to reload data

Components updated:
- `history.component.ts` — loading + error + retry
- `queue.component.ts` — loading + error + retry
- `app.component.ts` — connection status indicator (Online/Offline dot)
- `error-boundary.component.ts` — global error catch + reload/go-home
