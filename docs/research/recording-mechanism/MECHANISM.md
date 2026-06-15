# Window-Scoped Recording Mechanism — ytdlp feature/QA recordings

**Revision:** 1
**Last modified:** 2026-06-15T00:00:00Z
**Authority:** Constitution §11.4.154 (window-scoped capture + fresh-corpus rotation),
§11.4.155 (project-name-prefixed recording filenames), §11.4.107 (AV liveness /
honest gap), §11.4.81 (cross-platform honest gap), §11.4.99/§11.4.150 (latest-source
cited research), §11.4.44 (this header).
**Scope:** macOS (darwin 24.5.0). Project prefix resolves to **`ytdlp`**
(no `HELIX_RELEASE_PREFIX` in `.env` → lowercased snake_case root dir name, per §11.4.155/§11.4.29).
**Recording root:** `/Volumes/T7/Downloads/Recordings`.

---

## 0. Constitutional constraints this satisfies

- **§11.4.154(A)** — capture ONLY the app's own window/pane/viewport, NEVER the whole desktop.
- **§11.4.154(B)** — before a new run for a scope, delete the project's OWN prior in-scope recordings first.
- **§11.4.155** — every recording filename starts with the project prefix; canonical form
  `ytdlp---<feature-or-scope>---<run-id>.<ext>`; rotation removes only `ytdlp---<scope>---*`.

Tooling present on this host (verified `which`): `ffmpeg` (`/opt/homebrew/bin/ffmpeg`),
`screencapture` (`/usr/sbin/screencapture`), `asciinema` + `agg` (`/opt/homebrew/bin`).
Playwright is a devDependency of `tests/e2e/` (`@playwright/test ^1.59.0`), run via `npx`.

---

## 1. Browser/web surfaces — Playwright `recordVideo` (RECOMMENDED, window-scoped by construction)

Playwright records **the page/viewport only — not the whole screen** ([Playwright video docs](https://playwright.dev/docs/videos)).
The repo already has `tests/e2e/` (config `tests/e2e/playwright.config.ts`, chromium project,
tests `dashboard.spec.ts`, `landing.spec.ts`, `cross-service.spec.ts`). This is window-scoped
BY CONSTRUCTION and is the correct mechanism for the dashboard (`:9090`), landing 'Боба'
(`:8086`), and MeTube (`:8088`).

Config (per-context `recordVideo` gives exact dir/size/path control — output is **`.webm`**):

```typescript
// tests/e2e/playwright.config.ts  — use block
use: {
  video: { mode: 'on', size: { width: 1280, height: 720 } },
},
```

Drive a real user journey + name/save per §11.4.155 (path via `page.video().path()`,
available only after context close):

```typescript
import { test } from '@playwright/test';
import path from 'node:path';
const REC = '/Volumes/T7/Downloads/Recordings';
const RUN = new Date().toISOString().replace(/[:.]/g, '').slice(0, 15); // 20260615T0000
test('dashboard add-download journey', async ({ page }) => {
  await page.goto('http://localhost:9090');
  await page.fill('input[type="url"], #url', 'https://www.youtube.com/watch?v=...');
  await page.getByRole('button', { name: /add/i }).click();
  await page.getByText(/finished|completed/i).waitFor({ timeout: 120000 }); // watch states (§11.4.107 liveness)
});
```

```typescript
// global teardown / afterEach — rename webm to the constitutional filename:
const src = await page.video()!.path();             // after context closes
await fs.rename(src, path.join(REC, `ytdlp---web-dashboard---${RUN}.webm`));
```

Runnable command (from repo root):

```bash
cd tests/e2e && npx playwright install chromium && npx playwright test dashboard.spec.ts
```

Optional `.webm → .mp4` (existing corpus is `.mp4`): `ffmpeg -i in.webm -c:v libx264 -pix_fmt yuv420p out.mp4`.
**Honest gap:** Playwright video records the page surface, not native browser chrome; that is
acceptable and in fact a stronger §11.4.154 fit (no desktop leakage).

## 2. macOS native window capture (non-browser GUI alternative)

### 2a. `screencapture -l <windowid>` — single-window scoping
`screencapture -l <windowid>` captures the window with that id; `-o` omits the shadow; `-D <n>`
selects a display; `-R x,y,w,h` a rectangle ([screencapture man, ss64](https://ss64.com/mac/screencapture.html)).
Resolve the window id with the `GetWindowID` utility (`brew install smokris/getwindowid/getwindowid`)
([smokris/GetWindowID](https://github.com/smokris/GetWindowID)) or `osascript -l JavaScript`
+ `$.CGWindowListCopyWindowInfo` ([MacScripter](https://www.macscripter.net/t/get-window-id/72891)):

```bash
WID=$(GetWindowID "Google Chrome" --list | awk -F'id=' '/dashboard/{print $2}')
screencapture -o -l "$WID" /Volumes/T7/Downloads/Recordings/ytdlp---web-dashboard---20260615.png
```

### 2b. `screencapture` video flags + honest gap
The man page lists `-v` ("Capture video recording of the screen") and `-V <seconds>`
("...for the specified seconds") as **screen** recording ([ss64](https://ss64.com/mac/screencapture.html)).

**UNCONFIRMED (§11.4.6 / §11.4.107 honest gap):** No authoritative source confirms that
`-V`/`-v` combined with `-l <windowid>` produces *window-scoped video*. The man page describes
`-l` for window capture and `-v`/`-V` for *screen* video separately; their combination is not
documented as window-scoped. Additionally, screencapture **video was reported broken on macOS
14.4** (screenshots fine, video non-functional) — verify on this host before relying on it
([WebSearch 2026-06-15](https://developer.apple.com/forums/thread/746994)). Until confirmed,
treat `screencapture` window VIDEO as PENDING_FORENSICS; window SCREENSHOT (`-l`) is confirmed.

### 2c. `ffmpeg -f avfoundation` — region only, NOT window (honest gap per §11.4.81/§11.4.107)
List devices: `ffmpeg -f avfoundation -list_devices true -i ""`. Capture a screen device:
`ffmpeg -f avfoundation -capture_cursor 1 -framerate 30 -i "<screen-idx>:none" out.mp4`
([ffmpeg avfoundation docs](https://ffmpeg.org/ffmpeg-devices.html)). **AVFoundation captures
whole display devices/screens only — there is NO window-specific capture option** (confirmed
absent from the ffmpeg device docs). To stay §11.4.154-compliant you MUST crop to the window's
known rectangle, which means resolving its bounds first (CGWindowList) and the window must not move:

```bash
# bounds via osascript -l JavaScript $.CGWindowListCopyWindowInfo → X Y W H, then:
ffmpeg -f avfoundation -framerate 30 -i "<screen-idx>:none" \
  -vf "crop=${W}:${H}:${X}:${Y}" -c:v libx264 -pix_fmt yuv420p -t 30 \
  /Volumes/T7/Downloads/Recordings/ytdlp---gui-scope---20260615.mp4
```

**Honest gap:** crop ≠ true window scoping — if the window moves/resizes or another window
overlaps, the crop leaks neighbouring desktop. Prefer Playwright (web) or asciinema (TUI) where
scoping is structural; use avfoundation-crop only for a non-browser GUI with no better path,
and pin window position first.

## 3. CLI/TUI capture — asciinema (terminal-native, RECOMMENDED for ./download ./status ./start)

asciinema records the **terminal session (pty text output), not screen pixels** — inherently
pane-scoped, no desktop leakage ([asciinema](https://github.com/asciinema/asciinema)). `-c` records
a single command then exits; `--overwrite` replaces an existing file
([asciinema usage / Ubuntu manpage](https://manpages.ubuntu.com/manpages/jammy/man1/asciinema.1.html)).

```bash
REC=/Volumes/T7/Downloads/Recordings
asciinema rec --overwrite -c "./download 'https://www.youtube.com/watch?v=...'" \
  "$REC/ytdlp---cli-download---20260615.cast"
# render to video/gif (agg present): .cast → .gif
agg "$REC/ytdlp---cli-download---20260615.cast" "$REC/ytdlp---cli-download---20260615.gif"
```

For a true window-scoped MP4 of a fixed-size Terminal pane, pair asciinema's `.cast`/`.gif`
with the §2a `screencapture -l <terminal-windowid>` screenshot, or `ffmpeg -i ...gif ...mp4`.
The existing corpus already follows this pattern (`*.cast` + `*.mp4`/`*.gif`).

## 4. Naming + fresh-corpus rotation (§11.4.155 + §11.4.154(B))

Filename form: **`ytdlp---<feature-or-scope>---<run-id>.<ext>`** in `/Volumes/T7/Downloads/Recordings`.
Prefix `ytdlp` is fixed (resolution per §11.4.155). Rotate ONLY the project's own in-scope files
— NEVER foreign/operator/other-project files (§11.4.122 / §9.2). Safe rotation:

```bash
#!/usr/bin/env bash
set -euo pipefail
REC="/Volumes/T7/Downloads/Recordings"
PREFIX="ytdlp"                 # §11.4.155: HELIX_RELEASE_PREFIX from .env else snake_case dir name
SCOPE="${1:?usage: rotate <scope>}"   # e.g. web-dashboard, cli-download
# Delete ONLY this project's prior in-scope recordings (exact prefix---scope--- glob).
# -maxdepth 1 + literal prefix guard => never touches helixcode-*, helixtranslate-*, operator files.
find "$REC" -maxdepth 1 -type f -name "${PREFIX}---${SCOPE}---*" -print -delete
```

Invoke `rotate web-dashboard` immediately BEFORE each new run for that scope.

---

## Recommended per-surface mechanism (summary)

| Surface | Mechanism | Window-scoped because | One runnable command |
|---|---|---|---|
| Web: dashboard/landing/MeTube | **Playwright `recordVideo`** | records page viewport only (by construction) | `cd tests/e2e && npx playwright test dashboard.spec.ts` |
| CLI/TUI: ./download ./status ./start | **asciinema** (+ `agg`) | records pty text, not pixels | `asciinema rec --overwrite -c "./download URL" "$REC/ytdlp---cli-download---<run>.cast"` |
| Non-browser GUI (fallback) | `screencapture -l` (screenshot, confirmed) / `ffmpeg avfoundation` **crop** (video) | window-id screenshot is scoped; avfoundation needs crop-to-bounds | `screencapture -o -l "$WID" "$REC/ytdlp---gui---<run>.png"` |

**Honest gaps:** (1) `screencapture -V/-v -l <windowid>` window-scoped VIDEO is **UNCONFIRMED**;
screencapture video was broken on macOS 14.4 — verify on host before use. (2) `ffmpeg
avfoundation` has **NO window capture** — only display/screen + manual crop, which leaks if the
window moves. Web (Playwright) and TUI (asciinema) are the structurally-scoped, preferred paths.

---

## Sources verified 2026-06-15:

- Playwright video recording — https://playwright.dev/docs/videos
- ffmpeg avfoundation input device (no window capture) — https://ffmpeg.org/ffmpeg-devices.html
- macOS `screencapture` man (`-l`, `-v`, `-V`, `-R`, `-D`, `-o`) — https://ss64.com/mac/screencapture.html
- screencapture video broken on macOS 14.4 — https://developer.apple.com/forums/thread/746994
- GetWindowID (CGWindowID for `screencapture -l`) — https://github.com/smokris/GetWindowID
- Window id via JSObjC `$.CGWindowListCopyWindowInfo` — https://www.macscripter.net/t/get-window-id/72891
- macOS screen capture via CLI (GetWindowID + `screencapture -l`) — https://maeda.pm/2024/11/16/macos-screen-capture-via-cli/
- asciinema (records pty text, not pixels; .cast format) — https://github.com/asciinema/asciinema
- asciinema `rec` `-c`/`--overwrite` (manpage) — https://manpages.ubuntu.com/manpages/jammy/man1/asciinema.1.html
