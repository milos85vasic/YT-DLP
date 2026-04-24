# AGENTS.md — Dashboard Subdirectory

> **Authority chain:** `Constitution.md` > `CLAUDE.MD` > `AGENTS.md` (this file)

## Scope

This directory contains the Angular 19 dashboard application. All rules here apply to `dashboard/` and its subdirectories.

## Additional Constraints (Beyond Constitution + CLAUDE.MD)

### Angular Build Discipline
1. After ANY TypeScript change, run `npm run build` before declaring done.
2. After the build succeeds, rebuild the container image:
   ```bash
   podman-compose --profile no-vpn build --no-cache dashboard
   ```
3. Verify the fix is in the container:
   ```bash
   podman exec yt-dlp-dashboard grep -o 'your-change' /usr/share/nginx/html/chunk-*.js
   ```

### Component Requirements
Every new component MUST implement the Four Visible States:
```
1. Loading   — spinner or skeleton
2. Empty     — friendly message
3. Error     — clear message + retry button  
4. Content   — actual data display
```

### TypeScript Rules
- NO `any` types for API responses — use `DownloadInfo`, `HistoryResponse`, etc.
- Update `metube.service.ts` interfaces when the API contract changes.
- All nullable API fields must be typed as `Type | null | undefined`.

### RxJS Rules
- Unsubscribe in `ngOnDestroy`.
- Use `take(maxAttempts)` for polling, not manual counters.
- Prefer `map()` over `switchMap(() => [value])` — the latter emits array elements separately.

### Testing
- Dashboard tests go in `../tests/test-dashboard.sh` (shell-based HTTP tests).
- Do NOT write Jest/Karma tests that mock the MetubeService.
- Test the real proxy at `http://localhost:9090/api/*`.
