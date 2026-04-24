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
