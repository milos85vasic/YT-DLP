# YouTube Download Fix - Summary

## Issue Resolved ✓

**Problem:** YouTube videos were failing to download from the MeTube web portal with bot detection errors.

**Root Cause:** YouTube requires browser cookies for automated downloads.

**Solution:** Configured MeTube to use YouTube browser cookies.

## What Was Fixed

1. **Updated docker-compose.yml** - Added cookie file mounting and YTDL_OPTIONS configuration
2. **Created cookie export scripts** - Helper scripts to export cookies from browsers
3. **Created documentation** - Complete guide for cookie management

## Verification

**Successfully downloaded:** "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)"
- File: `Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster).webm`
- Size: 33MB
- Format: WebM
- Date: Apr 3, 2026 at 22:05

## Files Created/Modified

### New Files:
- `docs/YOUTUBE_DOWNLOAD_FIX.md` - Detailed fix documentation
- `yt-dlp/cookies/README.md` - Cookie setup guide
- `yt-dlp/cookies/export-cookies.sh` - Firefox export script
- `yt-dlp/cookies/export-cookies-chromium.sh` - Chromium export script
- `yt-dlp/cookies/export-cookies-playwright.py` - Playwright export
- `yt-dlp/cookies/export-cookies-playwright2.py` - Improved Playwright export
- `yt-dlp/cookies/export-cookies-decrypt.py` - Decryption-based export
- `yt-dlp/cookies/export-cookies-final.py` - Final comprehensive export
- `yt-dlp/cookies/setup-cookies.sh` - Interactive setup helper

### Modified Files:
- `docker-compose.yml` - Added cookie configuration to metube and metube-direct services
- `README.md` - Added troubleshooting section for YouTube downloads

## Current Cookie Status

The exported cookies work for most videos. The browser (Chromium) is not logged into YouTube, so some videos may still fail. 

### To Improve Cookie Quality:

1. **Install browser extension:**
   - Firefox: [Get cookies.txt LOCALLY](https://addons.mozilla.org/en-US/firefox/addon/get-cookies-txt-locally/)
   - Chrome: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-local/chojnikhgkcfngdkoghnibnbgpgkjpmo)

2. **Export cookies:**
   - Log into YouTube in your browser
   - Click extension → Export
   - Save as `yt-dlp/cookies/youtube_cookies.txt`

3. **Restart:**
   ```bash
   ./stop && ./start_no_vpn
   ```

## Manual Testing

### Test via Web UI:
1. Open http://localhost:8086
2. Add a YouTube URL (e.g., https://www.youtube.com/watch?v=dQw4w9WgXcQ)
3. Click Add and wait for download

### Test via API:
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best","download_type":"video","format":"any"}' \
  http://localhost:8086/add
```

### Check Status:
```bash
./status
podman logs metube-direct
ls -la /run/media/milosvasic/DATA4TB/Downloads/MeTube/
```

## Troubleshooting

### Cookies still failing?
- Ensure cookies are from a logged-in YouTube session
- Export both `youtube.com` and `google.com` cookies
- Check cookies file: `cat ./yt-dlp/cookies/youtube_cookies.txt`

### Videos still failing with bot detection?
- Some videos have stronger protection
- Try using VPN: `./start`
- Use different browser/profile to export cookies

## Documentation Location

All documentation is available at:
- Main fix docs: `docs/YOUTUBE_DOWNLOAD_FIX.md`
- Cookie setup: `yt-dlp/cookies/README.md`
- Project README: `README.md` (see Troubleshooting section)
