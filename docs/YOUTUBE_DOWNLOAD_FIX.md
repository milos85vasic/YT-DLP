# YouTube Downloads Issue - Resolution Document

## Problem Summary

YouTube video downloads were failing when added through the MeTube web portal with the error:
```
WARNING: Sign in to confirm you're not a bot. Use --cookies-from-browser or --cookies
ERROR: No video formats found!
```

## Root Cause

YouTube implements bot detection and rate limiting. Without proper cookies from a browser session, YouTube blocks automated downloads and returns no available video formats.

## Solution Applied

### 1. Cookie Configuration

Added cookie file support to MeTube containers in `docker-compose.yml`:

```yaml
# Added to metube and metube-direct services
YTDL_OPTIONS={"...":"...", "cookiefile":"/config/youtube_cookies.txt"}
volumes:
  - ./yt-dlp/cookies/youtube_cookies.txt:/config/youtube_cookies.txt:ro
```

### 2. Cookie Export

Created helper scripts to export cookies from browsers:
- `export-cookies.sh` - Firefox cookies
- `export-cookies-chromium.sh` - Chromium cookies
- `export-cookies-playwright.py` - Playwright automation
- `export-cookies-final.py` - Direct SQLite + decryption

### 3. Current Status

**Download confirmed working!** 

Tested with: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

Result: Successfully downloaded 33MB `.webm` file.

## Cookie File Location

```
./yt-dlp/cookies/youtube_cookies.txt
```

## How to Update Cookies

Cookies may expire periodically. To refresh:

### Option 1: Browser Extension (Recommended)

1. Install [Get cookies.txt LOCALLY](https://addons.mozilla.org/en-US/firefox/addon/get-cookies-txt-locally/) for Firefox/Chrome
2. Go to youtube.com (logged in)
3. Click extension → Export
4. Save as `yt-dlp/cookies/youtube_cookies.txt`
5. Restart: `./stop && ./start_no_vpn`

### Option 2: Use Helper Scripts

```bash
# Interactive setup
./yt-dlp/cookies/setup-cookies.sh

# Or try automatic export
./yt-dlp/cookies/export-cookies-chromium.sh
./yt-dlp/cookies/export-cookies-playwright.py
```

## Testing the Fix

### Via Landing Page (Recommended)
1. Open http://localhost:8086
2. Upload cookies via drag-and-drop or follow the guide
3. Auto-redirect to MeTube when authenticated
4. Add a YouTube URL

### Via MeTube Direct (port 8088)
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best","download_type":"video","format":"any"}' \
  http://localhost:8088/add
```

### Check Status
```bash
./status
podman logs metube-direct
```

## Cookie Expiry

Cookies typically expire after 2-6 months. Signs of expiry:
- Download fails with bot detection error
- No video formats available

## Files Modified

1. `docker-compose.yml` - Added cookie configuration
2. `yt-dlp/cookies/README.md` - Cookie setup guide
3. `yt-dlp/cookies/export-cookies.sh` - Firefox export
4. `yt-dlp/cookies/export-cookies-chromium.sh` - Chromium export
5. `yt-dlp/cookies/export-cookies-playwright.py` - Playwright export
6. `yt-dlp/cookies/export-cookies-final.py` - Decryption export
7. `yt-dlp/cookies/export-cookies-playwright2.py` - Profile export
8. `yt-dlp/cookies/setup-cookies.sh` - Interactive setup

## Troubleshooting

### "No video formats found"
→ Cookies missing or expired. Update cookies.

### "Read-only file system" warning
→ Cookie mount issue. File should be mounted correctly. May be safe to ignore.

### Cookie file format error
→ Re-export cookies with proper Netscape format.

### Cookie expires=-1 warning
→ Invalid expiry timestamp. Cookies may still work.
