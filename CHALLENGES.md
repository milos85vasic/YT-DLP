# Agent Challenges — Prove You Can Build Working Software

> This document contains specific challenges that agents must complete to demonstrate they understand the Gate 4 system. Each challenge has a **verification command** that must pass.

---

## Challenge 1: The Restart Survivor

**Goal:** Verify the dashboard still works after all containers are restarted.

**Steps:**
1. Run `./scripts/smoke-test.sh` — note it passes
2. Restart all containers: `./stop && ./start_no_vpn`
3. Wait 10 seconds
4. Run `./scripts/smoke-test.sh` again

**Pass criteria:** Both smoke test runs pass with 0 failures.

**Why this matters:** Agents often write code that works on first start but breaks after restart due to state assumptions.

---

## Challenge 2: The Offline Dashboard

**Goal:** Verify the dashboard shows clear errors when MeTube is down.

**Steps:**
1. Start all containers: `./start_no_vpn`
2. Stop ONLY the metube-direct container: `podman stop metube-direct`
3. Open http://localhost:9090 in a browser (or curl the HTML)
4. Check that the navbar shows "Offline"
5. Check that History and Queue pages show retry buttons

**Pass criteria:**
- Navbar shows red "Offline" indicator
- History page shows: "Failed to load history. Is the MeTube service running?"
- Queue page shows: "Failed to load queue. Is the MeTube service running?"
- Both pages have working "Retry" buttons

**Verification:**
```bash
./scripts/smoke-test.sh  # Should still pass (services available check)
```

**Why this matters:** Most agents test the happy path only. Real users encounter downtime.

---

## Challenge 3: The Contract Detective

**Goal:** Find and fix a field name mismatch between the API and the dashboard.

**Scenario:** You just discovered the MeTube `/version` endpoint returns `yt-dlp` but the dashboard interface expects `yt_dlp_version`.

**Steps:**
1. Run `./scripts/validate-contract.sh` — it fails
2. Fix the mismatch in BOTH:
   - `contracts/metube-api.openapi.yaml`
   - `dashboard/src/app/services/metube.service.ts`
3. Run `./scripts/validate-contract.sh` again

**Pass criteria:** Contract validation passes.

**Why this matters:** Agents often write TypeScript interfaces from memory rather than observing the actual API. This causes runtime failures that unit tests with mocks cannot catch.

---

## Challenge 4: The Memory Leak Hunter

**Goal:** Ensure all RxJS subscriptions are cleaned up.

**Steps:**
1. Open `dashboard/src/app/components/history/history.component.ts`
2. Verify `ngOnDestroy()` unsubscribes from `this.sub`
3. Open `dashboard/src/app/components/queue/queue.component.ts`
4. Verify the same
5. Open `dashboard/src/app/app.component.ts`
6. Verify the same

**Pass criteria:** Every component with `subscribe()` has corresponding `unsubscribe()` in `ngOnDestroy()`.

**Verification:**
```bash
grep -n "subscribe" dashboard/src/app/components/*/*.ts
grep -n "unsubscribe" dashboard/src/app/components/*/*.ts
```

**Why this matters:** Memory leaks in SPAs cause the browser to slow down over time. Agents often forget cleanup.

---

## Challenge 5: The Build Trap

**Goal:** Prove you know that restarting a container does NOT deploy new code.

**Steps:**
1. Make any visible change to `dashboard/src/app/components/history/history.component.ts`
2. Run `podman restart yt-dlp-dashboard`
3. Check if the change is in the container:
   ```bash
   podman exec yt-dlp-dashboard grep -o 'your-change' /usr/share/nginx/html/chunk-*.js
   ```

**Expected result:** The change is NOT in the container.

**Correct fix:**
```bash
podman-compose --profile no-vpn build --no-cache dashboard
podman-compose --profile no-vpn up -d dashboard
```

**Pass criteria:** Agent demonstrates understanding that image rebuild is required.

**Why this matters:** This is the #1 reason agents think they've "fixed" something when they haven't.

---

## Challenge 6: The Mock Fantasy Escape

**Goal:** Write an integration test that would catch a real API behavior change.

**Scenario:** The MeTube API changes `/delete` to require `where: "completed"` instead of `where: "done"`.

**Steps:**
1. Look at `tests/test-integration-realhttp.sh`
2. Verify it tests the `/delete` endpoint with `where: "done"`
3. Imagine the API change — the existing test would catch it

**Pass criteria:** The test makes a real HTTP call and asserts on the response.

**Why this matters:** Mock-based tests would pass even if the real API changed. Only real HTTP tests catch this.

---

## Challenge 7: The Pre-Commit Gauntlet

**Goal:** Make a change that passes all pre-commit checks.

**Steps:**
1. Make any change to any file
2. Stage it: `git add <file>`
3. Try to commit: `git commit -m "test"`
4. The pre-commit hook runs `./scripts/dev-check.sh`

**Pass criteria:** All 34 checks pass.

**If it fails:** Fix the issue, do NOT use `--no-verify`.

**Why this matters:** The pre-commit hook is the first line of defense against broken commits.

---

## Challenge 8: The Audit Gatekeeper

**Goal:** Maintain a test audit score of ≥ 60/70.

**Steps:**
1. Run `./scripts/test-audit.sh`
2. Note the score
3. If score < 60, add more integration/smoke tests until it rises

**Current score:** 70/70

**Pass criteria:** Score ≥ 60/70.

**Why this matters:** The audit detects mock-heavy test suites that create fantasy-land coverage.

---

## How to Submit Challenge Completion

Create a commit with this message format:

```
challenge(complete): <Challenge Name>

Verification:
- Smoke test: 22/22 passed
- Integration test: 22/22 passed
- Contract validation: 18/18 passed
- Test audit: 70/70
- Manual check: [describe what you verified]
```
