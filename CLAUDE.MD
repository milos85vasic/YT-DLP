# CLAUDE.MD — Constraints & Challenges for Claude Code Agents

> This document is LAW for any Claude Code agent (Opus, Sonnet, etc.) working on this project. Violations are bugs.

---

## Challenge System: Prove It Works

Claude agents are prone to **hallucinating completion**. Every task is a challenge you must demonstrably win.

### The Verification Challenge

For every task, you must produce **evidence**:

```markdown
## Task Completion Report

### What was changed
[1-2 sentences]

### Verification evidence
- [ ] `./scripts/smoke-test.sh` output pasted below
- [ ] `./scripts/test-audit.sh` score: ___/70
- [ ] `./scripts/validate-contract.sh` passed: yes/no
- [ ] Dashboard manually checked at http://localhost:9090: yes/no
- [ ] No new mocks added across boundaries: yes/no

### Smoke test output
```
[Paste full output here]
```
```

**Without this report, the task is not done.**

---

## Claude-Specific Anti-Patterns (STOP Doing These)

### 1. The "Tests Pass" Lie
```
❌ BAD:  "I've written the tests and they pass."
✅ GOOD: "Here is the ./scripts/smoke-test.sh output showing all 22 tests pass."
```

### 2. The Mock Fantasy
```
❌ BAD:  Mocking the Metube API in a dashboard component test
✅ GOOD: Using pollForItem() against the real running service
```

### 3. The Restart Illusion
```
❌ BAD:  "I restarted the container, the fix is deployed."
✅ GOOD: "I rebuilt the image with `podman-compose build --no-cache dashboard`, 
         recreated the container, and verified the new JS chunk contains 
         the fix via `podman exec`."
```

### 4. The Type Escape
```
❌ BAD:  `let data: any = response;`
✅ GOOD: `let data: HistoryResponse = response;` — update interfaces if needed
```

### 5. The Privilege Escalation Trap
```
❌ BAD:  Using `sudo`, `su`, or any privilege escalation command
✅ GOOD: Using `podman unshare`, adjusting container user mappings, or asking 
         the human to handle permission issues that require root
```

### 6. The Silent Error
```
❌ BAD:  `.subscribe({ next: (data) => { ... }, error: (err) => console.error(err) })`
✅ GOOD: `.subscribe({ 
           next: (data) => { this.loading = false; ... },
           error: (err) => { this.error = err.friendlyMessage || 'Failed'; this.loading = false; }
         })`
```

---

## Claude-Specific Mandatory Checks

Before EVERY commit, run:

```bash
# 1. Syntax check all changed files
bash -n <changed-script>
python3 -m py_compile <changed-py>
cd dashboard && npx tsc --noEmit  # Type check

# 2. Verify the build
npm run build

# 3. Run the gates
./scripts/smoke-test.sh
./scripts/validate-contract.sh
./scripts/test-audit.sh

# 4. Or simply:
make dev-check
```

---

## Context Window Management

Claude has limited context. Use it wisely:

1. **Read contracts first** — `contracts/metube-api.openapi.yaml` before writing API code
2. **Read AGENTS.md** — in every directory you touch
3. **Read existing tests** — to understand the testing pattern
4. **Do NOT read** — node_modules, .git, build artifacts

---

## Angular Dashboard: Claude Rules

### Component Template Requirements
Every component MUST have these four states visible in its template:
```html
<!-- 1. Loading -->
<div *ngIf="loading" class="loading">...</div>

<!-- 2. Error -->
<div *ngIf="error" class="error-state">
  <p>{{ error }}</p>
  <button (click)="retry()">Retry</button>
</div>

<!-- 3. Empty -->
<div *ngIf="!loading && !error && items.length === 0" class="empty">...</div>

<!-- 4. Content -->
<div *ngIf="!loading && !error && items.length > 0" class="list">...</div>
```

### RxJS Rules
- Use `take(maxAttempts)` for polling, not manual counters
- Unsubscribe in `ngOnDestroy`
- Use `shareReplay(1)` carefully — it can leak memory
- Prefer `map()` over `switchMap(() => [value])`

### Build Verification
After ANY TypeScript change:
```bash
cd dashboard && npm run build
# THEN rebuild container:
podman-compose --profile no-vpn build --no-cache dashboard
```

---

## Bash Script: Claude Rules

### Mandatory Header
```bash
#!/bin/bash
#
# Brief description of what this script does
# Supports both Podman and Docker
#

set -e
```

### Mandatory Functions
```bash
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}
```

### Color Codes (MUST match exactly)
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

---

## API Changes: Claude Protocol

When changing ANY API behavior:

1. Update `contracts/metube-api.openapi.yaml` FIRST
2. Update TypeScript interfaces in `dashboard/src/app/services/metube.service.ts`
3. Update landing page proxy in `landing/app.py` if affected
4. Run `./scripts/validate-contract.sh`
5. Update tests that assert on the response shape

---

## Challenge Checklist for Complex Tasks

For tasks touching >2 files or >1 service:

- [ ] I read the OpenAPI contract before writing code
- [ ] I wrote integration tests with real HTTP calls
- [ ] I did NOT add mocks across service boundaries
- [ ] I handled loading/empty/error/retry states in the UI
- [ ] I ran `./scripts/smoke-test.sh` and pasted output
- [ ] I ran `./scripts/validate-contract.sh` (if API changed)
- [ ] I rebuilt the dashboard container and verified the fix is inside
- [ ] I tested the error case (stopped containers, invalid input)
- [ ] I tested refresh/restart survival

---

## Universal Mandatory Constraints

> Cascaded from the HelixAgent root `CLAUDE.md` via `/tmp/UNIVERSAL_MANDATORY_RULES.md`.
> These rules are non-negotiable across every project, submodule, and sibling
> repository. Project-specific addenda are welcome but cannot weaken or
> override these.

### Hard Stops (permanent, non-negotiable)

1. **NO CI/CD pipelines.** No `.github/workflows/`, `.gitlab-ci.yml`,
   `Jenkinsfile`, `.travis.yml`, `.circleci/`, or any automated pipeline.
   No Git hooks either. All builds and tests run manually or via
   Makefile/script targets.
2. **NO HTTPS for Git.** SSH URLs only (`git@github.com:…`,
   `git@gitlab.com:…`, etc.) for clones, fetches, pushes, and submodule
   updates. Including for public repos. SSH keys are configured on every
   service.
3. **NO manual container commands.** Container orchestration is owned by
   the project's binary/orchestrator (e.g. `make build` → `./bin/<app>`).
   Direct `docker`/`podman start|stop|rm` and `docker-compose up|down`
   are prohibited as workflows. The orchestrator reads its configured
   `.env` and brings up everything.

### Mandatory Development Standards

1. **100% Test Coverage.** Every component MUST have unit, integration,
   E2E, automation, security/penetration, and benchmark tests. No false
   positives. Mocks/stubs ONLY in unit tests; all other test types use
   real data and live services.
2. **Challenge Coverage.** Every component MUST have Challenge scripts
   (`./challenges/scripts/`) validating real-life use cases. No false
   success — validate actual behavior, not return codes.
3. **Real Data.** Beyond unit tests, all components MUST use actual API
   calls, real databases, live services. No simulated success. Fallback
   chains tested with actual failures.
4. **Health & Observability.** Every service MUST expose health
   endpoints. Circuit breakers for all external dependencies.
   Prometheus / OpenTelemetry integration where applicable.
5. **Documentation & Quality.** Update `CLAUDE.md`, `AGENTS.md`, and
   relevant docs alongside code changes. Pass language-appropriate
   format/lint/security gates. Conventional Commits:
   `<type>(<scope>): <description>`.
6. **Validation Before Release.** Pass the project's full validation
   suite (`make ci-validate-all`-equivalent) plus all challenges
   (`./challenges/scripts/run_all_challenges.sh`).
7. **No Mocks or Stubs in Production.** Mocks, stubs, fakes,
   placeholder classes, TODO implementations are STRICTLY FORBIDDEN in
   production code. All production code is fully functional with real
   integrations. Only unit tests may use mocks/stubs.
8. **Comprehensive Verification.** Every fix MUST be verified from all
   angles: runtime testing (actual HTTP requests / real CLI
   invocations), compile verification, code structure checks,
   dependency existence checks, backward compatibility, and no false
   positives in tests or challenges. Grep-only validation is NEVER
   sufficient.
9. **Resource Limits for Tests & Challenges (CRITICAL).** ALL test and
   challenge execution MUST be strictly limited to 30-40% of host
   system resources. Use `GOMAXPROCS=2`, `nice -n 19`, `ionice -c 3`,
   `-p 1` for `go test`. Container limits required. The host runs
   mission-critical processes — exceeding limits causes system crashes.
10. **Bugfix Documentation.** All bug fixes MUST be documented in
    `docs/issues/fixed/BUGFIXES.md` (or the project's equivalent) with
    root cause analysis, affected files, fix description, and a link to
    the verification test/challenge.
11. **Real Infrastructure for All Non-Unit Tests.** Mocks/fakes/stubs/
    placeholders MAY be used ONLY in unit tests (files ending
    `_test.go` run under `go test -short`, equivalent for other
    languages). ALL other test types — integration, E2E, functional,
    security, stress, chaos, challenge, benchmark, runtime
    verification — MUST execute against the REAL running system with
    REAL containers, REAL databases, REAL services, and REAL HTTP
    calls. Non-unit tests that cannot connect to real services MUST
    skip (not fail).
12. **Reproduction-Before-Fix (CONST-032 — MANDATORY).** Every reported
    error, defect, or unexpected behavior MUST be reproduced by a
    Challenge script BEFORE any fix is attempted. Sequence:
    (1) Write the Challenge first. (2) Run it; confirm fail (it
    reproduces the bug). (3) Then write the fix. (4) Re-run; confirm
    pass. (5) Commit Challenge + fix together. The Challenge becomes
    the regression guard for that bug forever.
13. **Concurrent-Safe Containers (Go-specific, where applicable).** Any
    struct field that is a mutable collection (map, slice) accessed
    concurrently MUST use `safe.Store[K,V]` / `safe.Slice[T]` from
    `digital.vasic.concurrency/pkg/safe` (or the project's equivalent
    primitives). Bare `sync.Mutex + map/slice` combinations are
    prohibited for new code.

### Definition of Done (universal)

A change is NOT done because code compiles and tests pass. "Done"
requires pasted terminal output from a real run, produced in the same
session as the change.

- **No self-certification.** Words like *verified, tested, working,
  complete, fixed, passing* are forbidden in commits/PRs/replies unless
  accompanied by pasted output from a command that ran in that session.
- **Demo before code.** Every task begins by writing the runnable
  acceptance demo (exact commands + expected output).
- **Real system, every time.** Demos run against real artifacts.
- **Skips are loud.** `t.Skip` / `@Ignore` / `xit` / `describe.skip`
  without a trailing `SKIP-OK: #<ticket>` comment break validation.
- **Evidence in the PR.** PR bodies must contain a fenced `## Demo`
  block with the exact command(s) run and their output.
