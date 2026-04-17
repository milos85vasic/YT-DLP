# YT-DLP Container Project Release v1.2.0

## Release Date: April 17, 2026

## Overview

This release fixes critical YouTube download issues and adds improved container configuration for both VPN and non-VPN modes.

## What's New

### 🔧 Critical Fixes

#### 1. YouTube Download Fix - Deno Runtime
- **Issue:** yt-dlp was failing with "No video formats found!" error
- **Root Cause:** YouTube now requires an external JavaScript runtime (Deno) to solve JS challenges for format extraction (mandatory since yt-dlp v2025.11.12+)
- **Solution:** Switched from `thr3a/yt-dlp:latest` to `ghcr.io/jim60105/yt-dlp:pot` which includes Deno runtime

#### 2. Container Configuration Updates
- Added `no-vpn` profile to yt-dlp-cli for direct access without VPN
- Created new `yt-dlp-cli-vpn` service for VPN profile with proper network_mode
- Updated download script with:
  - `--extractor-args "youtube:player_client=web,mweb,android"` for better format detection
  - `--cookies /cookies/cookies.txt` for authentication
  - `--user root` for write permissions
  - `-o /downloads/` explicit output path

### 📝 Documentation Updates
- Updated CHANGES_SUMMARY.md with detailed fix documentation
- Added comprehensive commit history

## Changes Summary

| Component | Change |
|-----------|--------|
| docker-compose.yml | Added yt-dlp-cli-vpn service, updated image to pot variant |
| download script | Added cookie support, player client args, root execution |
| cookies.txt | Created with proper permissions |
| Documentation | Updated CHANGES_SUMMARY.md |

## Requirements

- **yt-dlp image:** ghcr.io/jim60105/yt-dlp:pot (includes Deno)
- **YouTube cookies:** Fresh cookie export required (existing cookies may be expired)

## Installation

1. Pull latest:
   ```bash
   ./update-images
   ```

2. Restart services:
   ```bash
   ./stop
   ./start_no_vpn  # or ./start for VPN
   ```

3. Export fresh YouTube cookies:
   ```bash
   # Use scripts in yt-dlp/cookies/ directory
   ./yt-dlp/cookies/setup-cookies.sh
   ```

## Known Issues

- YouTube cookies may expire frequently - re-export as needed
- Some videos may require PO Token for premium formats

## Upgrading from v1.1.0

```bash
# Pull latest changes
git pull origin main

# Update images
./update-images

# Restart
./stop
./start_no_vpn
```

## Credits

- yt-dlp team for the Deno integration
- jim60105 for maintaining the pot Docker variant
- All contributors

---

**SHA256:** dc7cb20
**GitHub:** https://github.com/milos85vasic/YT-DLP/releases/tag/v1.2.0