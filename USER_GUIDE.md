# YT-DLP User Guide

Complete guide for using the YT-DLP Container Project with Podman/Docker and VPN support.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Basic Usage](#basic-usage)
5. [Advanced Usage](#advanced-usage)
6. [VPN Setup](#vpn-setup)
7. [Troubleshooting](#troubleshooting)
8. [Testing](#testing)

---

## Quick Start

Get up and running in 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/milos85vasic/YT-DLP.git
cd YT-DLP

# 2. Copy and edit configuration
cp .env.example .env
# Edit .env with your settings (see Configuration section)

# 3. Initialize environment
./init

# 4. Start services
./start

# 5. Access web interface
# Open http://localhost:8086 in your browser
```

---

## Installation

### Prerequisites

**Required:** One of the following:
- [Podman](https://podman.io/getting-started/installation) 4.0+ (recommended)
- [Docker](https://docs.docker.com/get-docker/) 20.10+

**Optional:**
- `podman-compose` or `docker-compose`
- OpenVPN configuration (for VPN support)

### Installing Podman (Recommended)

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install podman podman-compose
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install podman podman-compose
```

**Arch Linux:**
```bash
sudo pacman -S podman podman-compose
```

**macOS:**
```bash
brew install podman
podman machine init
podman machine start
```

### Installing Docker

See [Docker installation guide](https://docs.docker.com/get-docker/) for your platform.

---

## Configuration

### Creating .env File

Copy the example configuration:

```bash
cp .env.example .env
```

### Required Settings

Edit `.env` with your settings:

```bash
# Required
USE_VPN=false                    # Enable/disable VPN (true/false)
DOWNLOAD_DIR=/path/to/downloads  # Where videos will be saved

# Required if USE_VPN=true
VPN_USERNAME=your_vpn_username
VPN_PASSWORD=your_vpn_password
VPN_OVPN_PATH=/path/to/config.ovpn
```

### Optional Settings

```bash
# Container runtime preference
CONTAINER_RUNTIME=auto           # auto, podman, or docker

# Ports
METUBE_PORT=8086                 # Web interface port
YTDLP_VPN_PORT=3130             # VPN proxy port

# Timezone
TZ=Europe/Moscow                # Your timezone

# Service mode
SERVICE_MODE=false              # Auto-process URLs/channels
```

### Example Configurations

**Without VPN:**
```bash
USE_VPN=false
DOWNLOAD_DIR=/home/user/Downloads/Videos
METUBE_PORT=8086
TZ=America/New_York
```

**With VPN:**
```bash
USE_VPN=true
DOWNLOAD_DIR=/home/user/Downloads/Videos
VPN_USERNAME=myvpnuser
VPN_PASSWORD=myvpnpass
VPN_OVPN_PATH=/home/user/vpn/config.ovpn
METUBE_PORT=8086
TZ=America/New_York
```

---

## Basic Usage

### Management Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `./init` | Initialize environment | `./init` |
| `./start` | Start services | `./start` |
| `./start_no_vpn` | Start without VPN | `./start_no_vpn` |
| `./stop` | Stop all services | `./stop` |
| `./restart` | Restart services | `./restart` |
| `./status` | Check status | `./status` |
| `./download` | Download video | `./download 'URL'` |
| `./update-images` | Update containers | `./update-images` |
| `./cleanup` | Remove containers | `./cleanup all` |

### Starting Services

```bash
# Start with VPN (if USE_VPN=true in .env)
./start

# Start without VPN (regardless of .env setting)
./start_no_vpn
```

### Accessing the Web Interface

Once started, open your browser:

```
http://localhost:8086
```

**Features:**
- Paste URLs to download
- View download progress
- Select video quality
- Download playlists
- Download history

### Downloading Videos

**Single video:**
```bash
./download 'https://www.youtube.com/watch?v=VIDEO_ID'
```

**Batch download:**
```bash
# Add URLs to file
echo 'https://youtube.com/watch?v=VIDEO1' >> ./yt-dlp/config/urls.txt
echo 'https://youtube.com/watch?v=VIDEO2' >> ./yt-dlp/config/urls.txt

# Download all
./download --batch
```

**Channel subscriptions:**
```bash
# Add channel URLs
echo 'https://youtube.com/c/ChannelName' >> ./yt-dlp/config/channels.txt

# Download recent videos (last 7 days)
./download --channels
```

### Checking Status

```bash
# View all services status
./status

# Check VPN connection (if enabled)
./check-vpn
```

### Stopping Services

```bash
# Stop all services
./stop

# Clean up containers
./cleanup all
```

---

## Advanced Usage

### Custom yt-dlp Options

Edit `./yt-dlp/config/yt-dlp.conf`:

```bash
# Video quality (720p max)
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

For age-restricted or subscriber-only content:

1. **Export cookies** from your browser using an extension
2. **Place cookies file** at `./yt-dlp/cookies/cookies.txt`
3. **Enable in `.env`:**
   ```bash
   YOUTUBE_COOKIES=true
   ```

### Service Mode

Enable automatic processing:

```bash
# In .env
SERVICE_MODE=true
```

This automatically processes:
- `./yt-dlp/config/urls.txt` (batch downloads)
- `./yt-dlp/config/channels.txt` (channel subscriptions)

### Container Runtime Selection

**Auto-detect (default):**
```bash
# Automatically uses Podman if available, otherwise Docker
CONTAINER_RUNTIME=auto
```

**Force Podman:**
```bash
CONTAINER_RUNTIME=podman
```

**Force Docker:**
```bash
CONTAINER_RUNTIME=docker
```

### Automatic Updates

Container images are automatically updated:

1. **On every start** - Latest images pulled before starting
2. **Every 3 hours** - Background updates via Watchtower (Docker) or cron (Podman)

**Docker users:** Watchtower is included  
**Podman users:** Run `./setup-auto-update` to enable cron updates

**Manual update:**
```bash
./update-images
```

---

## VPN Setup

### Supported Providers

Any OpenVPN-compatible provider:
- Private Internet Access (PIA)
- NordVPN
- Mullvad
- ProtonVPN
- And many more...

### Configuration Steps

1. **Download OpenVPN config** from your VPN provider (`.ovpn` file)

2. **Place config file** in a secure location:
   ```bash
   mkdir -p ~/vpn
   cp downloaded-config.ovpn ~/vpn/config.ovpn
   ```

3. **Update `.env`:**
   ```bash
   USE_VPN=true
   VPN_USERNAME=your_vpn_username
   VPN_PASSWORD=your_vpn_password
   VPN_OVPN_PATH=/home/user/vpn/config.ovpn
   ```

4. **Initialize:**
   ```bash
   ./init
   ```
   This creates `vpn-auth.txt` from your credentials

5. **Start with VPN:**
   ```bash
   ./start
   ```

6. **Verify connection:**
   ```bash
   ./check-vpn
   ```

### VPN Security

- ✅ Credentials stored in `vpn-auth.txt` with 600 permissions
- ✅ File automatically added to `.gitignore`
- ✅ Never commit VPN credentials to git

---

## Troubleshooting

### Container Runtime Not Found

**Problem:**
```
ERROR: No container runtime found!
```

**Solution:**
```bash
# Install Podman (recommended)
sudo dnf install podman podman-compose      # Fedora
sudo apt-get install podman podman-compose  # Ubuntu

# Or install Docker
# See https://docs.docker.com/get-docker/
```

### Permission Denied

**Problem:**
```
permission denied while trying to connect to Docker daemon
```

**Solution:**
```bash
# For Podman (rootless by default)
# No action needed - runs without root

# For Docker
sudo usermod -aG docker $USER
# Log out and back in
```

### Port Already in Use

**Problem:**
```
bind: address already in use
```

**Solution:**
```bash
# Change port in .env
METUBE_PORT=8087  # Use different port

# Or stop conflicting service
sudo lsof -ti:8086 | xargs kill -9
```

### VPN Connection Issues

**Problem:**
```
Cannot retrieve IP information. VPN might not be connected.
```

**Solution:**
```bash
# Check VPN status
./check-vpn

# View VPN logs
podman-compose logs -f openvpn-yt-dlp
# or
docker-compose logs -f openvpn-yt-dlp

# Verify credentials in .env
# Check OpenVPN config path is correct
# Ensure auth-user-pass directive exists in .ovpn file
```

### Download Directory Issues

**Problem:**
```
Download directory does not exist
```

**Solution:**
```bash
# Create directory manually
mkdir -p /path/to/downloads

# Or let init script create it
./init
# When prompted, type 'y' to create directory
```

### Container Won't Start

**Problem:**
Containers fail to start or immediately exit

**Solution:**
```bash
# Check logs
./status

# View detailed logs
podman-compose logs
# or
docker-compose logs

# Full reset
./stop
./cleanup all
./init
./start
```

### Tests Failing

**Problem:**
Tests fail during execution

**Solution:**
```bash
# Run tests with verbose output
./tests/run-tests.sh -v

# Check test logs
cat tests/logs/*.log

# Verify test environment
./tests/run-comprehensive-tests.sh
```

---

## Testing

### Quick Test

Validate your installation:

```bash
# Run all tests
./tests/run-comprehensive-tests.sh
```

### Test Categories

```bash
# Unit tests only
./tests/run-tests.sh -p unit

# Integration tests
./tests/run-tests.sh -p integration

# Scenario tests
./tests/run-tests.sh -p scenario

# Error condition tests
./tests/run-tests.sh -p error
```

### Verbose Testing

```bash
# See detailed output
./tests/run-tests.sh -v

# Run specific test
./tests/run-tests.sh test_init_no_vpn -v
```

### Test Results

All tests should pass:
- **Unit Tests:** 17/17 passing
- **Integration Tests:** 19/19 passing
- **Scenario Tests:** 17/17 passing
- **Error Tests:** 24/24 passing

See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed results.

---

## Directory Structure

```
YT-DLP/
├── docker-compose.yml          # Service definitions
├── .env                        # Your configuration (not in git)
├── .env.example               # Configuration template
├── init                        # Environment setup
├── start                       # Start services
├── stop                        # Stop services
├── download                    # Download helper
├── status                      # Status checker
├── check-vpn                  # VPN verification
├── update-images              # Update containers
├── cleanup                    # Remove containers
├── restart                    # Restart services
├── setup-auto-update          # Auto-update setup
├── lib/
│   └── container-runtime.sh   # Runtime detection
├── yt-dlp/
│   ├── config/
│   │   ├── yt-dlp.conf       # yt-dlp configuration
│   │   ├── urls.txt          # Batch download URLs
│   │   └── channels.txt      # Channel subscriptions
│   ├── cookies/              # Browser cookies
│   └── archive/              # Download history
├── metube/
│   └── config/               # Metube configuration
└── tests/                    # Test suite
    ├── run-tests.sh
    ├── run-comprehensive-tests.sh
    └── README.md
```

---

## Getting Help

### Documentation

- [README.md](README.md) - Overview and quick start
- [USER_GUIDE.md](USER_GUIDE.md) - This guide
- [TEST_RESULTS.md](TEST_RESULTS.md) - Test results
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contributing guidelines
- [AGENTS.md](AGENTS.md) - Development guide

### Support

- **Issues:** [GitHub Issues](https://github.com/milos85vasic/YT-DLP/issues)
- **Discussions:** [GitHub Discussions](https://github.com/milos85vasic/YT-DLP/discussions)

### Resources

- [yt-dlp Documentation](https://github.com/yt-dlp/yt-dlp#usage-and-options)
- [Podman Documentation](https://docs.podman.io/)
- [Docker Documentation](https://docs.docker.com/)

---

## License

This project is licensed under GPL v3. See [LICENSE](LICENSE) for details.

---

**Last Updated:** March 2026  
**Version:** 1.0
