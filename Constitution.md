# Project Constitution — YT-DLP Container Project

> **This document is the supreme authority.** All agents, humans, and automated systems must obey these rules. No task, commit, or deployment may violate the Constitution.

---

## Article I: The Four Gates (Non-Negotiable)

No code change is complete until it passes **all four gates**:

| Gate | Name | Automation | Enforced In |
|------|------|-----------|-------------|
| 1 | **Contract** | `./scripts/validate-contract.sh` | CI, Pre-commit |
| 2 | **Integration** | `./tests/test-integration-realhttp.sh` | CI |
| 3 | **Smoke** | `./scripts/smoke-test.sh` | CI, Pre-commit |
| 4 | **Manual** | Human verification in running app | Release checklist |

**Law:** An agent that reports a task as "done" without including the output of `./scripts/smoke-test.sh` has committed malpractice.

---

## Article II: Truth Over Comfort

### 2.1 Integration is the Only Truth
- **Unit tests with mocks across service boundaries are forbidden.**
- If two services talk, test them talking. Real HTTP. Real TCP. No mocks.
- The `scripts/test-audit.sh` score must remain ≥ 60/70. Current: **70/70**.

### 2.2 The Smoke Test is the Source of Truth
- If `./scripts/smoke-test.sh` passes but manual testing fails, the smoke test is wrong and must be strengthened.
- If `./scripts/smoke-test.sh` fails, nothing deploys. Ever.

### 2.3 Contracts Are Law
- `contracts/metube-api.openapi.yaml` defines the API.
- Dashboard TypeScript interfaces must match the contract exactly.
- Landing page proxy must preserve request/response shapes exactly.
- Violations are bugs, not style issues.

---

## Article III: Agent Conduct

### 3.1 Task Completion Requirements
Every agent task MUST include:
1. **Context** — Service, consumer, contract path
2. **Constraints** — No mocks across boundaries, match OpenAPI spec
3. **Verification output** — Copy-paste the output of `./scripts/smoke-test.sh`

### 3.2 Forbidden Patterns
Agents must NEVER:
- Add mocks across HTTP/service boundaries
- "Fix" a test to match broken code
- Skip error handling (loading, empty, error, retry states)
- Use `any` type when a specific type is knowable
- Leave `console.log` in production code
- Change cache headers to `immutable` for non-hash-busted assets
- **Use `sudo`, `su`, or any privilege escalation command** — agents run as the current user only

### 3.3 Required Patterns
Agents must ALWAYS:
- Handle the four UI states: loading, empty, error, retry
- Update the OpenAPI contract BEFORE changing an endpoint
- Run `./scripts/dev-check.sh` before declaring done
- Include human-readable error messages, not just status codes

---

## Article IV: Error Handling Doctrine

### 4.1 The Four Visible States
Every user-facing feature must visibly handle:
1. **Loading** — Spinner or skeleton
2. **Empty** — Friendly "nothing here" message
3. **Error** — Clear explanation + retry button
4. **Success** — Confirmation that action completed

### 4.2 The Offline State
The dashboard must show when the API is unreachable:
- Navbar connection indicator (green dot / red dot)
- Components show retry buttons, not infinite spinners
- Global error boundary catches catastrophic JS errors

---

## Article V: Build & Deploy Discipline

### 5.1 Pre-Commit Hook
The pre-commit hook runs `./scripts/dev-check.sh`. It is installed by `scripts/install-hooks.sh` or `make init`.

### 5.2 Container Image Rebuild
After any dashboard code change:
```bash
podman-compose build dashboard
podman-compose up -d dashboard
```
Restarting the container is NOT sufficient — the old image has stale JS.

### 5.3 Cache Control
- `index.html` → `no-cache`
- JS/CSS chunks → `max-age=86400, must-revalidate`
- NEVER `immutable` for JS unless filename hashes are content-based

---

## Article VI: When Bugs Are Found

### 6.1 The Bug→Test Rule
When manual testing finds a bug:
1. Stop. Do not just fix it.
2. Add a test to `scripts/smoke-test.sh` or `tests/test-integration-realhttp.sh`.
3. Update `AGENTS.md` or `CLAUDE.MD` if the bug reveals a missing constraint.
4. Fix the bug.
5. Verify the new test fails before the fix and passes after.

### 6.2 The Regression Wall
The same bug must never be caught twice. If it is, the process failed, not the code.

---

## Article VII: Hierarchy of Documents

When documents conflict, resolution order is:
1. **User instruction** (direct conversation)
2. **Constitution.md** (this document)
3. **CLAUDE.MD** (agent-specific constraints)
4. **AGENTS.md** (directory-specific guidance)
5. **README.md** (human documentation)

Deeper directories override parent directories for scope-specific rules.

---

## Amendment Process

This Constitution changes only by:
1. A human explicitly requesting an amendment
2. The amendment passing all Four Gates
3. The amendment being documented in `CHANGES_SUMMARY.md`

**No agent may amend the Constitution without explicit human approval.**

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
