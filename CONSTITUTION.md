# MeTube — Constitution

> **Status:** Active. **This document is the supreme authority.**
> All agents, humans, and automated systems must obey these rules.
> When a rule here conflicts with `CLAUDE.md`, `AGENTS.md`, or any
> other guide, the Constitution wins. No task, commit, or deployment
> may violate the Constitution.
>
> *Note on filename:* historically this content lived in two files
> (`Constitution.md` and `CONSTITUTION.md`) on case-sensitive
> filesystems. They have been consolidated. `CONSTITUTION.md`
> (this file) is canonical; `Constitution.md` is now a redirect stub.

## Mission

See `README.md`.

## Mandatory Standards

1. **Reproducibility:** every change is reproducible from a clean
   clone (`git clone <repo> && <project bootstrap>`); no hidden steps.
2. **Tests track behavior, not code:** test what the user-visible
   behavior is, not what the implementation looks like.
3. **No silent skips, no silent mocks above unit tests.**
4. **Conventional Commits** for all commits.
5. **SSH-only for git operations** (`git@…`); HTTPS prohibited.

---

## Article I: The Four Gates (Non-Negotiable)

No code change is complete until it passes **all four gates**:

| Gate | Name | Automation | Enforced In |
|------|------|-----------|-------------|
| 1 | **Contract** | `./scripts/validate-contract.sh` | CI, Pre-commit |
| 2 | **Integration** | `./tests/test-integration-realhttp.sh` | CI |
| 3 | **Smoke** | `./scripts/smoke-test.sh` | CI, Pre-commit |
| 4 | **Manual** | Human verification in running app | Release checklist |

**Law:** An agent that reports a task as "done" without including the
output of `./scripts/smoke-test.sh` has committed malpractice.

---

## Article II: Truth Over Comfort

### 2.1 Integration is the Only Truth
- **Unit tests with mocks across service boundaries are forbidden.**
- If two services talk, test them talking. Real HTTP. Real TCP. No mocks.
- The `scripts/test-audit.sh` score must remain ≥ 60/70. Current: **70/70**.

### 2.2 The Smoke Test is the Source of Truth
- If `./scripts/smoke-test.sh` passes but manual testing fails, the
  smoke test is wrong and must be strengthened.
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
The pre-commit hook runs `./scripts/dev-check.sh`. It is installed by
`scripts/install-hooks.sh` or `make init`.

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
3. Update `AGENTS.md` or `CLAUDE.md` if the bug reveals a missing constraint.
4. Fix the bug.
5. Verify the new test fails before the fix and passes after.

### 6.2 The Regression Wall
The same bug must never be caught twice. If it is, the process failed,
not the code.

---

## Article VII: Hierarchy of Documents

When documents conflict, resolution order is:
1. **User instruction** (direct conversation)
2. **`CONSTITUTION.md`** (this document — also reachable as `Constitution.md`)
3. **`CLAUDE.md`** (agent-specific constraints for Claude Code)
4. **`AGENTS.md`** (directory-specific guidance)
5. **`README.md`** (human documentation)

Deeper directories override parent directories for scope-specific rules.

---

## Numbered Rules

<!-- Rules are numbered CONST-NNN. New rules append. Removed rules
     keep their number with a "**Retired:** …" line. -->

<!-- BEGIN host-power-management addendum (CONST-033) -->

### CONST-033 — Host Power Management is Forbidden

**Status:** Mandatory. Non-negotiable. Applies to every project,
submodule, container entry point, build script, test, challenge, and
systemd unit shipped from this repository.

**Rule:** No code in this repository may invoke a host-level power-
state transition (suspend, hibernate, hybrid-sleep, suspend-then-
hibernate, poweroff, halt, reboot, kexec) on the host machine. This
includes — but is not limited to:

- `systemctl {suspend,hibernate,hybrid-sleep,suspend-then-hibernate,poweroff,halt,reboot,kexec}`
- `loginctl {suspend,hibernate,hybrid-sleep,suspend-then-hibernate,poweroff,halt,reboot}`
- `pm-{suspend,hibernate,suspend-hybrid}`
- `shutdown {-h,-r,-P,-H,now,--halt,--poweroff,--reboot}`
- DBus calls to `org.freedesktop.login1.Manager.{Suspend,Hibernate,HybridSleep,SuspendThenHibernate,PowerOff,Reboot}`
- DBus calls to `org.freedesktop.UPower.{Suspend,Hibernate,HybridSleep}`
- `gsettings set ... sleep-inactive-{ac,battery}-type` to any value other than `'nothing'` or `'blank'`

The scanner (`scripts/host-power-management/check-no-suspend-calls.sh`)
also rejects user-session terminations (`loginctl terminate-user`,
`systemctl --user exit`, `systemctl stop user@`, login1.Manager
.{TerminateUser,KillUser,TerminateSession,KillSession,TerminateSeat}),
desktop-session quits (`gnome-session-quit`, `xfce4-session-logout`,
`qdbus org.kde.ksmserver`), `systemctl isolate emergency.target` and
similar, and DPMS-force-off (`xset dpms force off`, `setterm --blank
force`, `vbetool dpms off`). `xset s off` and `xset -dpms` are
explicitly NOT forbidden — they DISABLE blanking, which is the
protective behaviour shipped in
`scripts/host-power-management/user_session_no_suspend_bootstrap.sh`.

**Why:** The host runs mission-critical parallel CLI-agent and
container workloads. On 2026-04-26 18:23:43 the host was auto-
suspended by the GDM greeter's idle policy mid-session, killing
HelixAgent and 41 dependent services. Recurring memory-pressure
SIGKILLs of `user@1000.service` (perceived as "logged out") have the
same outcome. Auto-suspend, hibernate, and any power-state transition
are unsafe for this host.

**Defence in depth (mandatory artifacts in every project):**
1. `scripts/host-power-management/install-host-suspend-guard.sh` —
   privileged installer, manual prereq, run once per host with sudo.
   Masks `sleep.target`, `suspend.target`, `hibernate.target`,
   `hybrid-sleep.target`; writes `AllowSuspend=no` drop-in; sets
   logind `IdleAction=ignore` and `HandleLidSwitch=ignore`.
2. `scripts/host-power-management/user_session_no_suspend_bootstrap.sh` —
   per-user, no-sudo defensive layer. Idempotent. Safe to source from
   `start.sh` / `setup.sh` / `bootstrap.sh`.
3. `scripts/host-power-management/check-no-suspend-calls.sh` —
   static scanner. Exits non-zero on any forbidden invocation.
4. `challenges/scripts/host_no_auto_suspend_challenge.sh` — asserts
   the running host's state matches layer-1 masking.
5. `challenges/scripts/no_suspend_calls_challenge.sh` — wraps the
   scanner as a challenge that runs in CI / `run_all_challenges.sh`.
6. `scripts/host-power-management/protect-user-session-from-oom.sh` —
   **Added 2026-04-27 after a second incident.** Privileged
   installer, manual prereq, run once per host with sudo. Sets
   `OOMScoreAdjust=-500` on `user@1000.service` via systemd drop-in
   AND hot-applies it to the running PID's
   `/proc/<pid>/oom_score_adj` so the kernel OOM killer treats the
   user session as the LAST candidate (rather than the first, which
   it picks by default because the user session has the highest
   cumulative RSS in `user.slice`).
7. `challenges/scripts/user_session_oom_protected_challenge.sh` —
   asserts the live `oom_score_adj` on the running unit's PID is
   ≤ -100. Anti-bluff: it reads `/proc/<pid>/oom_score_adj` directly
   rather than trusting the unit file, because a drop-in that's
   never re-applied to the running PID gives a false-positive on a
   `systemctl show` check.

**The OOM-cascade vector (2026-04-27 incident):**
On 2026-04-27 22:22:14 the journal showed:
```
user@1000.service: Main process exited, code=killed, status=9/KILL
user-1000.slice: A process of this unit has been killed by the OOM killer.
user.slice: A process of this unit has been killed by the OOM killer.
```
Forensic showed the OOM cascade originated in a NON-MeTube pod
(`pod_41847d97…` running `python3` + `V8 DefaultWorke` + `mux0:webm`
— a neighbour project's video-processing workload) that had no
`mem_limit` configured on its containers. Once that pod's cgroup
hit its memory ceiling, the kernel walked up the cgroup tree
looking for the highest-RSS victim and picked `user@1000.service`,
killing every container — MeTube, HelixAgent, all parallel CLI
agents — at once. The blast radius is identical to a suspend; the
user perceives it as "logged out" even though no logout was issued.

**Mitigations split between project-local and host-level:**
- **Project-local (already enforced for MeTube):** every compose
  service MUST have an explicit `mem_limit`. Uncapped containers
  are how OOM cascades start. The mem-limit invariant is asserted
  by `tests/test-vpn-compose.sh::test_every_service_has_mem_limit`.
- **Host-level (manual prereq, sudo, run once):**
  `scripts/host-power-management/protect-user-session-from-oom.sh`
  ensures the user session is the LAST OOM victim.

**Note on Docker / Podman daemon-level concerns:**
Podman's rootless mode (the default on this host) runs containers
under the user's session — meaning their cgroup is a child of
`user@<uid>.service` and any OOM in those containers can escalate
upward in the cgroup tree to the user session. Docker with the
system daemon does NOT have this property (containers live under
`docker.service`, separate from `user.slice`) but introduces other
attack surface. Either runtime needs the layer-7 protection above.
Docker / Podman themselves do NOT call suspend / logout primitives
— the failure mode is purely memory pressure.

**Enforcement:** Every project's CI / `run_all_challenges.sh`
equivalent MUST run both challenges (host state + source tree). A
violation in either channel blocks merge. Adding files to the
scanner's `EXCLUDE_PATHS` requires an explicit justification comment
identifying the non-host context.

**See also:** `docs/HOST_POWER_MANAGEMENT.md` for full background and
runbook, and `scripts/capture-freeze-diagnostics.sh` for a one-shot
diagnostics snapshot to run after any unresponsive-host episode.

<!-- END host-power-management addendum (CONST-033) -->

### CONST-034 — Anti-Bluff Verification (tests must prove user-visible reality)

**Status:** Mandatory. Non-negotiable. Applies to every test, challenge,
smoke probe, CI gate, and verification command in this repository and
in every project / submodule that vendors content from this one.

**Background:** This project has shipped — more than once — code where
every test passed, every challenge passed, the audit was 70/70, the
contract validated, the dashboard built, and yet the actual feature
the user wanted to use *did not work*. Examples observed in the field:
- A "200 OK" status assertion that masked an HTML 502 body.
- A nginx-config-syntax check that passed while the proxy returned
  the wrong upstream.
- A "build succeeded" gate that never executed the binary.
- Component tests that ran in isolation while the integration was
  broken at the wire.
- Tests that returned 0 because a service was unreachable
  ("upstream issue") without any explicit SKIP marker — silent green.

This rule exists so a green test board means **the user can use the
feature**, not just that the test process did not throw.

**Rule:** Every automated check in this repository MUST verify the
behavior it claims to cover **from the END USER's perspective**. A
test that "passes" without proving the feature is reachable, usable,
and visibly correct from the user's surface is a bug, not a green
light.

**The zero-skip rule (added 2026-04-27 after a SKIP audit found three
stale "platform restriction" labels masking platforms that actually
worked):** SKIPs are not a default option. A test that exits 0 with
a "platform restriction" / "upstream issue" message is a bluff
unless it has been *converted into an assertion that proves the
documented restriction is real right now*. Concretely:

- A SKIP for "TikTok IP-blocked" must run yt-dlp against TikTok
  and assert that the response contains "IP address is blocked" or
  equivalent. If extraction unexpectedly succeeds, the test FAILS
  — telling us the restriction has lifted and the dashboard's
  status badge needs flipping.
- A SKIP for "upstream extractor bug" must run the extractor and
  assert it produces the documented error. If extraction works, the
  bug is fixed and the test FAILS — telling us to update the badge.
- A SKIP for "test data stale" must be removed entirely (use a
  fresh test target instead — stale test data is a bug in the
  test, not a property of the world).

The goal: ZERO silent SKIPs. Every test either (a) PASSes because
the feature works, or (b) PASSes because the documented
limitation is provably real, or (c) FAILS — telling someone to
either fix the feature or update the documented limitation.

If a check genuinely cannot run because of an external dependency
the test environment can't satisfy (e.g. a CN-egress test on a
non-CN host), the test still must not silently SKIP — it should
PASS by asserting the documented failure mode (HTTP 412 from
Bilibili) and FAIL when the dependency is satisfied. That way the
suite tells the operator "this used to be blocked here, now
isn't" — a celebration, not a bug.

**Bluff patterns explicitly forbidden:**
1. Asserting on `http_code` only without checking the response body.
   curl's `%{http_code}` reports `000` on early-close even when the
   body is `{"status":"ok"}` — body content is the source of truth.
2. Asserting on syntactic / structural success (parse OK, build OK,
   container exists) without runtime evidence that the feature works.
3. `return 0` from an unreachable / network-flake path without a
   trailing `SKIP-OK: <reason>` line that the runner recognises.
   Silent green is forbidden.
4. Mocks that cross a real component boundary — replacing the
   service the user actually talks to with a fake. See also
   Article II §2.1 and Universal Constraint #1.
5. Counting "the test process exited 0" as success when the test
   never reached its meaningful assertion (e.g. early-return on
   container-not-running without skipping the test loudly).
6. Component-instance assertions that don't exercise the rendered
   DOM / HTTP wire / disk side-effects the user actually sees.
7. Coverage-by-line-count claims without coverage-by-user-capability.
   "100% line coverage" with zero end-to-end flow tests is a bluff.

**Required for every feature shipped:**
- At least one **end-to-end test** that traverses the full user path:
  UI gesture → backend call → side-effect verification (DB / disk /
  /history record / file on disk).
- Every UI surface MUST handle and visibly render four states —
  loading, empty, error (with retry), success (Article IV §4.1) — and
  tests MUST assert each state is reachable and visibly correct.
- Every API endpoint MUST be exercised by a real-HTTP test that
  asserts response **body shape**, not just status code.
- Every long-running pipeline / job MUST verify its own preconditions
  before claiming success. Silence on stdout for 60 minutes is not
  success; an end-of-run summary line is.
- Manual smoke testing (Article I, Gate 4) is mandatory before any
  release. "All automated tests passed" is necessary, not sufficient.

**ARTIFACT RULE (added 2026-04-27 after a download-volume regression
that hid behind /add-returns-200 tests for weeks):**
For any feature that produces an artifact — a file on disk, a
database row, a queue message, a sent email, an outbound HTTP
request — the test or challenge that covers it MUST verify the
artifact exists with the right shape, not just that the API
endpoint promising it returned 200. Examples of the rule applied:

- **"Download succeeded"** ⇒ a file >1KB exists in `$DOWNLOAD_DIR`
  with a recognisable extension, NOT just `{"status":"ok"}` from /add.
  The host-side stat must succeed; an inode visible only inside the
  container's namespace doesn't count.
- **"Cookie uploaded"** ⇒ `/config/cookies.txt` exists with non-zero
  size and the validator's recognised-domain check passes against
  its content.
- **"Cancelled queue item moved to History"** ⇒ a GET against
  `/api/aborted-history` returns the canonical URL with
  `status:'aborted'` and a non-zero `aborted_at`.
- **"Email sent"** ⇒ the SMTP send call returned a delivery confirm
  AND the receiver's inbox / mail-trap was checked.

If the test cannot reasonably verify the artifact (e.g. the artifact
is on a system the test can't reach), the test MUST mark itself
SKIP-OK with a documented external-dependency reason. Bluff-passing
is forbidden.

**Code-review heuristic:** "If I deleted the implementation, would
this test still pass?" If yes, the test is bluff — rewrite it to
assert on something the implementation actually produces.

**Enforcement:** A finding that a check is bluff blocks merge until
the check is rewritten or removed. Adding a test for the sake of
coverage numbers, with no assertion that the user-visible behavior is
correct, is forbidden — coverage numbers without behavioral assertions
are noise, not signal.

**See also:**
- Article I (Four Gates) — Contract / Integration / Smoke / Manual
- Article II §2.1 (Integration is the only truth)
- Article VI (Bug → Test rule — bugs catch themselves once)
- Universal Constraint #11 (Real Infrastructure for All Non-Unit Tests)

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

---

## Definition of Done (project-specific)

A change is done when:

1. The code change is committed.
2. All project-level tests pass on a clean clone.
3. All challenges in `challenges/scripts/` pass on the running host.
4. Governance docs (`CONSTITUTION.md`, `AGENTS.md`, `CLAUDE.md`) are
   coherent with the change.
5. Verification evidence is pasted into the PR / commit body per
   `CLAUDE.md`'s verification report template.

---

## Amendment Process

This Constitution changes only by:
1. A human explicitly requesting an amendment
2. The amendment passing all Four Gates (Article I)
3. The amendment being documented in `CHANGES_SUMMARY.md`

**No agent may amend the Constitution without explicit human approval.**

---

## See also

- `README.md` — project overview, quickstart.
- `AGENTS.md` — guidance for AI coding agents (Codex, Cursor, etc.).
- `CLAUDE.md` — guidance specifically for Claude Code.
- `docs/HOST_POWER_MANAGEMENT.md` — CONST-033 background and runbook.
- `scripts/capture-freeze-diagnostics.sh` — post-freeze diagnostics snapshot.
