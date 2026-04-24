# AGENTS.md — Tests Subdirectory

> **Authority chain:** `Constitution.md` > `CLAUDE.MD` > `AGENTS.md` (this file)

## Scope

This directory contains all test suites. All rules here apply to `tests/` and its subdirectories.

## The Prime Directive

**Tests are a means, not an end.** Passing tests do not prove the product works. They prove the tests pass.

The only tests that matter:
1. `./scripts/smoke-test.sh` — E2E against real services
2. `./tests/test-integration-realhttp.sh` — Real HTTP, no mocks
3. `./scripts/validate-contract.sh` — API matches spec

## Test Writing Rules

### Forbidden
- Mocking HTTP calls (use real curl/wget against running containers)
- Mocking container runtime behavior
- Mocking the database (use testcontainers or real instances)
- Testing implementation details instead of observable behavior

### Required
- Every new feature gets a smoke test in `../scripts/smoke-test.sh`
- Every new API endpoint gets a contract check in `../scripts/validate-contract.sh`
- Every bug fix gets a regression test that would have caught it

### Test Structure
```bash
#!/bin/bash
set -e

# Use these exact colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
```

## Running Tests

```bash
# Full suite
./tests/run-tests.sh

# With containers
./tests/run-comprehensive-tests.sh
./tests/run-full-suite.sh

# Specific categories
./tests/run-tests.sh -p unit
./tests/run-tests.sh -p integration
./tests/run-tests.sh -p scenario
./tests/run-tests.sh -p error

# Real HTTP integration (no mocks)
./tests/test-integration-realhttp.sh

# Quality audit
./scripts/test-audit.sh
```

## Adding New Tests

1. Write the test in the appropriate `test-*.sh` file
2. Register it in `run-tests.sh` if it should be part of the suite
3. Run `./scripts/test-audit.sh` to verify score stays ≥ 60/70
4. Run `./scripts/smoke-test.sh` to verify nothing is broken
