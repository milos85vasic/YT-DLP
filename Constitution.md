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
