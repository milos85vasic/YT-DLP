# AGENTS.md - Agentic Coding Guide for YT-DLP Container Project

## Project Overview

Docker/Podman-based YT-DLP orchestration with VPN support. Manages multiple services including Metube web UI, yt-dlp CLI, and OpenVPN containers. **Prioritizes Podman over Docker** when both are available.

## Build / Deploy Commands

```bash
# Initialize environment (creates dirs, validates .env, detects runtime)
./init

# Start services (auto-detects Podman/Docker)
./start                    # Uses USE_VPN from .env
./start_no_vpn            # Force no VPN

# Stop services
./stop                     # Stops all profiles
./restart                  # Stop + Start

# Update images (run manually or via cron)
./update-images           # Pull latest container images
./setup-auto-update       # Setup cron job for auto-updates (Podman)

# Utility
./status                   # Check service status and runtime info
./check-vpn               # Verify VPN connection
./cleanup [all|ytdlp|jdownloader]  # Remove containers
./download <URL>          # Download video
./download --batch        # Download from urls.txt
./download --channels     # Download from channels.txt
./download --help         # Show help
```

### Container Runtime Detection

All scripts automatically detect the container runtime:
- **Podman** (preferred if available)
- **Docker** (fallback)

Detection function (include in all scripts):
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

### Compose Commands

**With Podman:**
```bash
podman-compose --profile vpn up -d
# or
podman compose --profile vpn up -d
```

**With Docker:**
```bash
docker-compose --profile vpn up -d
# or
docker compose --profile vpn up -d
```

## Image Updates

All container images are automatically updated:

1. **On every start**: `./start` and `./start_no_vpn` run `./update-images` before starting containers
2. **Every 3-4 hours**: Automated background updates

### Docker (Watchtower)

Docker users use Watchtower (configured in docker-compose.yml):
- Checks for image updates every 3 hours
- Automatically restarts containers with new images
- Label: `com.centurylinklabs.watchtower.enable=true`

### Podman (Cron Job)

Podman users (rootless) should use the cron-based alternative:

```bash
# Setup automatic updates every 3 hours
./setup-auto-update

# This adds a cron job that runs:
# 0 */3 * * * cd /path/to/project && ./update-images >> ./logs/update.log 2>&1
```

### Manual Updates

```bash
# Pull latest images manually
./update-images

# Or with specific runtime:
CONTAINER_RUNTIME=docker ./update-images
```

### Images Updated

The following images are checked for updates:
- `ghcr.io/alexta69/metube:latest`
- `th3a/yt-dlp:latest`
- `dperson/openvpn-client:latest`
- `containrrr/watchtower:latest`

## Code Style Guidelines

### Bash Scripts

- **Shebang:** `#!/bin/bash`
- **Strict mode:** `set -e` at start of all scripts
- **Indentation:** 4 spaces (no tabs)
- **Line length:** Max 120 characters
- **Colors:** Use these ANSI codes consistently:
  ```bash
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'    # For runtime info
  NC='\033[0m'         # No Color
  ```

### Script Template

```bash
#!/bin/bash
#
# Brief description
# Supports both Podman and Docker
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Container runtime detection
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

get_compose_cmd() {
    local runtime="$1"
    if [ "$runtime" = "podman" ]; then
        if command -v podman-compose &> /dev/null; then
            echo "podman-compose"
        else
            echo "podman compose"
        fi
    else
        if command -v docker-compose &> /dev/null; then
            echo "docker-compose"
        else
            echo "docker compose"
        fi
    fi
}

CONTAINER_RUNTIME=$(detect_container_runtime)

if [ "$CONTAINER_RUNTIME" = "none" ]; then
    echo -e "${RED}ERROR: No container runtime found!${NC}"
    exit 1
fi

COMPOSE_CMD=$(get_compose_cmd "$CONTAINER_RUNTIME")

# Load .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Main logic...
```

### Environment Variables

- **Load .env pattern:**
  ```bash
  if [ -f .env ]; then
      set -a
      source .env
      set +a
  fi
  ```
- **Naming:** UPPER_CASE with underscores for env vars
- **Required vars:** USE_VPN, DOWNLOAD_DIR
- **VPN vars:** VPN_USERNAME, VPN_PASSWORD, VPN_OVPN_PATH
- **Runtime var:** CONTAINER_RUNTIME (podman/docker/auto)

### Naming Conventions

- **Scripts:** lowercase-with-hyphens.sh
- **Functions:** lowercase_with_underscores
- **Variables:** lowercase for local, UPPER_CASE for env/global
- **Containers:** lowercase-with-hyphens (yt-dlp-cli, openvpn-yt-dlp)
- **Directories:** lowercase (metube, yt-dlp, config)

### Docker Compose

- **Profiles:** `vpn`, `no-vpn`, `vpn-cli`
- **Container names:** Explicit with `container_name`
- **Restart policy:** `unless-stopped`
- **Health checks:** For VPN containers
- **Network mode:** `service:openvpn-yt-dlp` for VPN routing

### Error Handling

```bash
# Always use set -e
set -e

# Check commands succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}Error message${NC}"
    exit 1
fi

# Validate variables
if [ -z "$VAR" ]; then
    echo -e "${RED}ERROR: VAR is not set${NC}"
    exit 1
fi

# Check runtime
if [ "$CONTAINER_RUNTIME" = "none" ]; then
    echo -e "${RED}ERROR: No container runtime found!${NC}"
    exit 1
fi
```

### Output Formatting

```bash
# Success
echo -e "${GREEN}✓ Success message${NC}"

# Error
echo -e "${RED}✗ ERROR: Message${NC}"

# Warning
echo -e "${YELLOW}⚠ WARNING: Message${NC}"

# Info
echo -e "${BLUE}=== Section ===${NC}"

# Runtime info
echo -e "${CYAN}Container Runtime:${NC} $CONTAINER_RUNTIME"
```

## Project Structure

```
.
├── docker-compose.yml      # Service definitions
├── .env.example           # Configuration template
├── .gitignore            # Comprehensive git ignore
├── init                   # Environment setup with runtime detection
├── start                  # Start services (auto-detects runtime)
├── start_no_vpn          # Start without VPN
├── stop                   # Stop all services
├── restart                # Restart services
├── update-images          # Pull latest container images
├── setup-auto-update      # Setup cron job for auto-updates
├── download               # Download helper with --help
├── cleanup                # Container cleanup
├── status                 # Status checker with runtime info
├── check-vpn             # VPN verification
├── lib/                  # Shared libraries
│   └── container-runtime.sh   # Runtime detection functions
├── tests/                # Automated test suite
│   ├── run-tests.sh      # Test runner
│   ├── run-full-suite.sh # Full suite with container lifecycle
│   ├── test-unit.sh      # Unit tests
│   ├── test-integration.sh   # Integration tests
│   ├── test-scenarios.sh     # Scenario tests
│   ├── test-errors.sh    # Error tests
│   └── README.md         # Test documentation
├── Upstreams/            # Git upstream config
│   └── GitHub.sh
├── README.md             # Comprehensive documentation
├── CONTRIBUTING.md       # Contribution guidelines
├── AGENTS.md            # This file
└── .env                 # Configuration (not in git)
```

## Service Ports

- 8086: Landing Page (No VPN) - Cookie authentication
- 8087: Landing Page (VPN) - Cookie authentication
- 8088: Metube Web UI (No VPN)
- 8081: Metube API (internal)
- 3130: yt-dlp VPN proxy
- 3129: JDownloader VPN (if used)

## Testing

### Automated Test Suite

A comprehensive automated test suite is available in the `tests/` directory:

```bash
# Run all tests
./tests/run-tests.sh

# Run with verbose output
./tests/run-tests.sh -v

# Run specific test categories
./tests/run-tests.sh -p unit          # Unit tests only
./tests/run-tests.sh -p integration   # Integration tests only
./tests/run-tests.sh -p scenario      # Scenario tests only
./tests/run-tests.sh -p error         # Error tests only

# Run with specific runtime
./tests/run-tests.sh -r podman        # Test with Podman only
./tests/run-tests.sh -r docker        # Test with Docker only

# Dry run (show what would be tested)
./tests/run-tests.sh -d

# List all available tests
./tests/run-tests.sh -l

# Run specific test
./tests/run-tests.sh test_init_no_vpn

# Cleanup test environment
./tests/run-tests.sh -c

# Full test suite with container lifecycle (recommended)
./tests/run-full-suite.sh              # Runs all tests with containers
./tests/run-full-suite.sh -p unit      # Unit tests only
./tests/run-full-suite.sh -v           # Verbose output with containers
```

### Container Lifecycle Management

The test suite automatically manages container lifecycle:

1. **Container Detection**: Checks if containers are already running
2. **Auto-Start**: Starts containers before integration/scenario tests if needed
3. **Auto-Stop**: Stops containers after tests complete (if test suite started them)
4. **Existing Containers**: Uses existing containers if already running

When running `run-full-suite.sh`:
- Creates test environment
- Starts containers automatically
- Runs all tests
- Shuts down containers after completion

### Test Categories

1. **Unit Tests**: Individual function testing (runtime detection, compose commands, etc.)
2. **Integration Tests**: Script workflow testing (init, start, stop, download, etc.)
3. **Scenario Tests**: Combination testing:
   - Podman + No VPN
   - Podman + VPN
   - Docker + No VPN
   - Docker + VPN
   - Batch/Channel downloads
   - Complete workflows
4. **Error Tests**: Edge cases and error conditions

### Manual Testing

If you need to test manually:

```bash
# 1. Validate scripts syntax
bash -n ./scriptname

# 2. Test with Podman
./init
./start
./status
./download --help
./stop

# 3. Test with Docker (if available)
CONTAINER_RUNTIME=docker ./start
./status
./stop

# 4. Check VPN connection (if enabled)
./check-vpn

# 5. Verify containers
./status
```

## Common Tasks

### Add a new service to docker-compose.yml

1. Use existing services as template
2. Add to appropriate profile(s)
3. Set explicit container_name
4. Add restart: unless-stopped
5. Update ./status script

### Add a new script

1. Create with `#!/bin/bash` and `set -e`
2. Include runtime detection functions
3. Add to README.md Scripts Overview section
4. Make executable: `chmod +x scriptname`
5. Follow color output conventions
6. Add --help support

### Update documentation

- Keep README.md current with new features
- Update CONTRIBUTING.md for process changes
- Update this AGENTS.md for coding standards
- Update .env.example for new variables

## Security Notes

- Never commit `.env` or `vpn-auth.txt`
- Mask credentials in output
- Use 600 permissions for sensitive files
- VPN credentials stored in `vpn-auth.txt`
- Cookies and auth files in `.gitignore`

## Container Runtime Notes

### Podman (Preferred)
- Rootless by default
- No daemon required
- Drop-in Docker replacement
- Use `podman-compose` or `podman compose`

### Docker (Fallback)
- Traditional container runtime
- Requires daemon
- Use `docker-compose` or `docker compose`

### Runtime Selection
Scripts automatically prefer Podman. To force a runtime:
```bash
# In .env
CONTAINER_RUNTIME=podman   # or docker
```
