# YT-DLP Container Project

[![Podman](https://img.shields.io/badge/Podman-Supported-892CA0?logo=podman)](https://podman.io)
[![Docker](https://img.shields.io/badge/Docker-Supported-2496ED?logo=docker)](https://docker.com)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)

Run [yt-dlp](https://github.com/yt-dlp/yt-dlp) inside a container with optional VPN support. This project provides a complete Docker/Podman-based solution for downloading videos from YouTube and other supported sites, featuring:

- **Dual Runtime Support**: Works with both Podman (preferred) and Docker
- **VPN Integration**: Route downloads through OpenVPN for privacy
- **Landing Page**: Seamless cookie authentication flow for YouTube
- **Web Interface**: Metube provides a clean, modern web UI
- **Cookie Authentication**: Built-in support for YouTube browser cookies
- **CLI Access**: Direct yt-dlp command-line access
- **Batch Processing**: Download from URL lists and channel subscriptions
- **Multi-Service**: Designed to work alongside JDownloader

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Container Runtime](#container-runtime)
- [VPN Setup](#vpn-setup)
- [Advanced Usage](#advanced-usage)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Documentation](#documentation)
- [License](#license)

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/milos85vasic/YT-DLP.git
cd YT-DLP

# 2. Copy and edit configuration
cp .env.example .env
# Edit .env with your settings

# 3. Initialize and start
./init
./start

# 4. Access the web interface
# Open http://localhost:8086 in your browser
```

## Installation

### Prerequisites

**Required:** One of the following container runtimes:
- [Podman](https://podman.io/getting-started/installation) (recommended, rootless by default)
- [Docker](https://docs.docker.com/get-docker/)

**Optional:**
- `podman-compose` or `docker-compose` for compose operations
- OpenVPN configuration file (for VPN support)

### Setup Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/milos85vasic/YT-DLP.git
   cd YT-DLP
   ```

2. **Create configuration:**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` with your settings:**
   ```bash
   # Required settings
   USE_VPN=false                    # Set to true to enable VPN
   DOWNLOAD_DIR=/path/to/downloads  # Where videos will be saved
   
   # VPN settings (if USE_VPN=true)
   VPN_USERNAME=your_username
   VPN_PASSWORD=your_password
   VPN_OVPN_PATH=/path/to/config.ovpn
   ```

4. **Initialize the environment:**
   ```bash
   ./init
   ```
   This creates necessary directories and validates your configuration.

5. **Start the services:**
   ```bash
   ./start
   ```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `USE_VPN` | Yes | `false` | Enable VPN routing (`true`/`false`) |
| `DOWNLOAD_DIR` | Yes | - | Absolute path to download directory |
| `VPN_USERNAME` | If VPN | - | VPN account username |
| `VPN_PASSWORD` | If VPN | - | VPN account password |
| `VPN_OVPN_PATH` | If VPN | - | Path to OpenVPN config file |
| `CONTAINER_RUNTIME` | No | `auto` | Force runtime: `podman`, `docker`, or `auto` |
| `METUBE_PORT` | No | `8086` | Web interface port |
| `YTDLP_VPN_PORT` | No | `3130` | VPN proxy port |
| `TZ` | No | `Europe/Moscow` | Timezone for containers |
| `SERVICE_MODE` | No | `false` | Enable automatic processing |

### Example `.env` (No VPN)

```bash
USE_VPN=false
DOWNLOAD_DIR=/home/user/Downloads/Videos
METUBE_PORT=8086
TZ=America/New_York
```

### Example `.env` (With VPN)

```bash
USE_VPN=true
DOWNLOAD_DIR=/home/user/Downloads/Videos
VPN_USERNAME=myvpnuser
VPN_PASSWORD=myvpnpass
VPN_OVPN_PATH=/home/user/vpn/config.ovpn
METUBE_PORT=8086
TZ=America/New_York
```

## Usage

### Management Scripts

| Script | Description |
|--------|-------------|
| `./init` | Initialize environment, validate config |
| `./start` | Start services (uses VPN setting from `.env`) |
| `./start_no_vpn` | Start services without VPN |
| `./stop` | Stop all services |
| `./restart` | Stop and restart services |
| `./update-images` | Pull latest container images |
| `./setup-auto-update` | Setup automatic updates (Podman cron) |
| `./status` | Show service status and container info |
| `./check-vpn` | Verify VPN connection status |
| `./cleanup [all\|ytdlp\|jdownloader]` | Remove containers |
| `./download <URL>` | Download a video |
| `./download --batch` | Download from `urls.txt` |
| `./download --channels` | Download from `channels.txt` |

### Web Interface (Metube)

Once running, access the Landing Page at:
```
http://localhost:8086
```

The Landing Page handles cookie authentication and redirects to MeTube when ready.

**Landing Page Features:**
- Automatic YouTube cookie status check
- Step-by-step guide for cookie export
- Drag-and-drop cookie upload
- Auto-redirect to MeTube when authenticated

**MeTube UI (at http://localhost:8088):**
- Paste URLs to download
- View download queue and progress
- Select format/quality
- Playlist and channel support
- Download history

### Command Line Usage

**Download a single video:**
```bash
./download 'https://www.youtube.com/watch?v=VIDEO_ID'
```

**Download with options:**
```bash
# With Podman (auto-detected)
./download 'URL' -f 'bestvideo[height<=720]+bestaudio'

# Or directly with container runtime
podman exec yt-dlp-cli yt-dlp 'URL'
docker exec yt-dlp-cli yt-dlp 'URL'
```

**Batch downloads:**
```bash
# Add URLs to ./yt-dlp/config/urls.txt
echo 'https://youtube.com/watch?v=VIDEO1' >> ./yt-dlp/config/urls.txt
echo 'https://youtube.com/watch?v=VIDEO2' >> ./yt-dlp/config/urls.txt

# Download all
./download --batch
```

**Channel subscriptions:**
```bash
# Add channel URLs to ./yt-dlp/config/channels.txt
echo 'https://youtube.com/c/ChannelName' >> ./yt-dlp/config/channels.txt

# Download recent videos (last 7 days)
./download --channels
```

### Viewing Logs

```bash
# All services
podman-compose logs -f
# or
docker-compose logs -f

# Specific service
podman-compose logs -f yt-dlp-cli
```

## Container Runtime

This project automatically detects and uses the available container runtime:

### Podman (Recommended)

```bash
# Check installation
podman --version

# The scripts will automatically use Podman if available
./start  # Uses Podman by default
```

Benefits of Podman:
- **Rootless by default**: Runs without root privileges
- **Daemonless**: No background service required
- **Docker-compatible**: Drop-in replacement
- **Systemd integration**: Native systemd support

### Docker

```bash
# Check installation
docker --version

# If Podman is not installed, scripts will use Docker
./start  # Uses Docker if Podman unavailable
```

### Forcing a Runtime

To force a specific runtime, edit `.env`:

```bash
CONTAINER_RUNTIME=podman   # Force Podman
# or
CONTAINER_RUNTIME=docker   # Force Docker
```

### Compose Commands

**With Podman:**
```bash
# Using podman-compose (standalone)
podman-compose --profile vpn up -d
podman-compose --profile no-vpn up -d

# Using podman compose (built-in)
podman compose --profile vpn up -d
```

**With Docker:**
```bash
# Using docker-compose (standalone)
docker-compose --profile vpn up -d

# Using docker compose (plugin)
docker compose --profile vpn up -d
```

## VPN Setup

### Supported VPN Providers

Any OpenVPN-compatible provider should work. Tested with:
- Private Internet Access (PIA)
- NordVPN
- Mullvad
- ProtonVPN

### Configuration Steps

1. **Download OpenVPN config** from your VPN provider

2. **Place config file** in a secure location (e.g., `~/vpn/config.ovpn`)

3. **Update `.env`:**
   ```bash
   USE_VPN=true
   VPN_USERNAME=your_username
   VPN_PASSWORD=your_password
   VPN_OVPN_PATH=/home/user/vpn/config.ovpn
   ```

4. **Initialize:**
   ```bash
   ./init
   # This creates vpn-auth.txt from your credentials
   ```

5. **Start with VPN:**
   ```bash
   ./start
   ```

6. **Verify connection:**
   ```bash
   ./check-vpn
   ```

### VPN Authentication

The `init` script will:
- Create `vpn-auth.txt` with your credentials
- Set permissions to `600` (readable only by owner)
- Add `auth-user-pass` directive to OpenVPN config if missing

**Important:** Never commit `vpn-auth.txt` to git. It's already in `.gitignore`.

## Automatic Updates

All container images are automatically kept up-to-date through two mechanisms:

### 1. On Every Start

Whenever you start the services, the latest images are pulled automatically:

```bash
./start         # Pulls latest images before starting
./start_no_vpn  # Also pulls latest images
```

### 2. Periodic Background Updates (Every 3-4 Hours)

**Docker Users:**
Watchtower is included and configured to check for updates every 3 hours. It will automatically pull new images and restart containers when updates are available.

**Podman Users:**
Since Watchtower requires Docker socket access, Podman users should set up a cron job:

```bash
# Setup automatic updates
./setup-auto-update

# This creates a cron job that runs every 3 hours
# Logs are saved to ./logs/update.log
```

### Manual Updates

To manually check for and pull updates:

```bash
./update-images
```

Or specify the runtime:

```bash
CONTAINER_RUNTIME=docker ./update-images
```

### Updated Images

The following images are automatically updated:
- **Metube**: `ghcr.io/alexta69/metube:latest`
- **yt-dlp CLI**: `th3a/yt-dlp:latest`
- **OpenVPN**: `dperson/openvpn-client:latest`
- **Watchtower**: `containrrr/watchtower:latest`

## Advanced Usage

### Custom yt-dlp Options

Edit `./yt-dlp/config/yt-dlp.conf`:

```bash
# Video quality
-f "bestvideo[height<=720]+bestaudio/best"

# Output template
-o "/downloads/%(uploader)s/%(title)s.%(ext)s"

# Subtitles
--write-sub
--sub-langs en,es
--embed-subs

# Metadata
--add-metadata
--embed-thumbnail
```

### Using Cookies

YouTube requires browser cookies to download videos. The easiest method is using the Landing Page:

1. **Open http://localhost:8086** - The Landing Page will guide you
2. **Export cookies** from your browser using "Get cookies.txt LOCALLY" extension
3. **Upload cookies** via drag-and-drop on the Landing Page
4. **Auto-redirect** to MeTube when authenticated

Alternatively, to access age-restricted or subscriber-only content:

1. **Export cookies** from your browser using an extension
2. **Place cookies file** at `./yt-dlp/cookies/youtube_cookies.txt`
3. Restart: `./stop && ./start`

**Cookie Helper Scripts:**
```bash
# Interactive cookie setup
./yt-dlp/cookies/setup-cookies.sh
```

### Service Mode

Enable automatic processing of URLs and channels:

```bash
# In .env
SERVICE_MODE=true
```

When enabled, containers will automatically process:
- `./yt-dlp/config/urls.txt` (batch downloads)
- `./yt-dlp/config/channels.txt` (channel subscriptions)

### Integration with JDownloader

This project is designed to work alongside [JDownloader](https://github.com/milos85vasic/jDownloader):

- Separate VPN containers for each service
- Different external IP addresses (if VPN enabled)
- Non-conflicting ports

To use together:
```bash
# Start both services
./start                    # Starts YT-DLP
# (Start JDownloader separately in its directory)
```

## Testing

This project includes a comprehensive automated test suite with **81 tests** covering all scenarios:

```bash
# Run all tests
./tests/run-comprehensive-tests.sh

# Run specific test categories
./tests/run-tests.sh -p unit          # Unit tests
./tests/run-tests.sh -p integration   # Integration tests
./tests/run-tests.sh -p scenario      # Scenario tests
./tests/run-tests.sh -p error         # Error tests
```

**Test Results:**
- **77 tests passing** (100% pass rate)
- 4 tests skipped (Docker not installed on test system)
- All Podman tests passing
- All VPN scenarios tested
- All error conditions validated

See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed results.

## Troubleshooting

### Container Runtime Not Found

```bash
# Check if Podman is installed
which podman
podman --version

# Or Docker
which docker
docker --version

# Install Podman (recommended)
# Fedora/RHEL: sudo dnf install podman podman-compose
# Ubuntu/Debian: sudo apt-get install podman podman-compose
# Arch: sudo pacman -S podman podman-compose
```

### VPN Connection Issues

```bash
# Check VPN status
./check-vpn

# View VPN logs
podman-compose logs -f openvpn-yt-dlp

# Common fixes:
# 1. Verify VPN credentials in .env
# 2. Check OpenVPN config path
# 3. Ensure auth-user-pass directive in .ovpn file
```

### Permission Denied Errors

```bash
# Fix directory permissions
chmod -R 755 ./yt-dlp ./metube

# For rootless Podman, ensure your user owns the download directory
sudo chown -R $USER:$USER /path/to/downloads
```

### Download Directory Not Found

The `init` script will prompt to create the directory. To create manually:
```bash
mkdir -p /path/to/downloads
```

### Port Already in Use

Change the port in `.env`:
```bash
METUBE_PORT=8087  # Use different port
```

### YouTube Downloads Failing - "No video formats found" or Bot Detection

This is caused by YouTube's bot detection. YouTube requires cookies from a browser session to download videos.

**Quick Fix:**
```bash
# Run the cookie setup helper
./yt-dlp/cookies/setup-cookies.sh

# Or manually:
# 1. Install "Get cookies.txt LOCALLY" extension for Firefox/Chrome
# 2. Go to youtube.com (logged in)
# 3. Export cookies as youtube_cookies.txt in ./yt-dlp/cookies/
# 4. Restart: ./stop && ./start_no_vpn
```

**Detailed instructions:** See [docs/YOUTUBE_DOWNLOAD_FIX.md](docs/YOUTUBE_DOWNLOAD_FIX.md)

**Troubleshooting:**
- Ensure cookies file exists: `cat ./yt-dlp/cookies/youtube_cookies.txt`
- Check container logs: `podman logs metube-direct | grep -i error`
- Cookies may expire - re-export periodically

## Port Reference

| Port | Service | Description |
|------|---------|-------------|
| 8086 | Landing Page | Cookie authentication & redirect (No VPN) |
| 8087 | Landing Page | Cookie authentication & redirect (VPN) |
| 8088 | Metube | Web interface for yt-dlp (No VPN) |
| 8081 | Metube API | Internal API (container) |
| 3130 | yt-dlp VPN | VPN proxy port |
| 3129 | JDownloader VPN | VPN proxy (if using JDownloader) |
| 5800 | JDownloader | Web UI (if using JDownloader) |
| 5900 | JDownloader | VNC (if using JDownloader) |

## Documentation

- **[USER_GUIDE.md](USER_GUIDE.md)** - Complete user manual with examples
- **[TEST_RESULTS.md](TEST_RESULTS.md)** - Comprehensive test results report
- **[AGENTS.md](AGENTS.md)** - Development guide and coding standards
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines
- **[docs/YOUTUBE_DOWNLOAD_FIX.md](docs/YOUTUBE_DOWNLOAD_FIX.md)** - YouTube cookie authentication guide
- **[tests/README.md](tests/README.md)** - Testing documentation

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - The video downloader
- [Metube](https://github.com/alexta69/metube) - Web UI for yt-dlp
- [Podman](https://podman.io/) - Container engine
- [OpenVPN](https://openvpn.net/) - VPN solution

## Support

- **Issues:** [GitHub Issues](https://github.com/milos85vasic/YT-DLP/issues)
- **Discussions:** [GitHub Discussions](https://github.com/milos85vasic/YT-DLP/discussions)

---

**Disclaimer:** This tool is for personal use only. Respect copyright laws and terms of service of content providers.
