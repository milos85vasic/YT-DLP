<!-- AGENTS.md - Agentic Coding Guide for YT-DLP Container Project -->

# AGENTS.md - Agentic Coding Guide for YT-DLP Container Project

## Project Overview

This project is a **Docker/Podman-based orchestration system** for running [yt-dlp](https://github.com/yt-dlp/yt-dlp) (a YouTube/video downloader) with optional VPN support. It manages multiple services including:

- **MeTube Web UI** (`ghcr.io/alexta69/metube:latest`) — Original web interface for managing downloads
- **YT-DLP Dashboard** (custom Angular 17 app) — Modern standalone dashboard on port 9090
- **yt-dlp CLI** (`ghcr.io/jim60105/yt-dlp:pot`) — The actual downloader with Deno support for YouTube JS challenges
- **OpenVPN Client** (`dperson/openvpn-client`) — VPN tunnel for privacy/anonymity
- **Landing Page** (custom Python/Flask app named "Боба") — Cookie authentication gateway that guides users through exporting/uploading YouTube cookies
- **Watchtower** (`containrrr/watchtower:latest`) — Auto-image updates for Docker users

**Container runtime preference:** Podman is preferred over Docker when both are available.

**Current release:** v1.2.0 (April 2026) — switched yt-dlp image to `ghcr.io/jim60105/yt-dlp:pot` to resolve YouTube JS challenge errors.

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Container Runtime** | Podman (preferred) or Docker (fallback) |
| **Orchestration** | Docker Compose / Podman Compose |
| **CLI / Downloader** | yt-dlp (`ghcr.io/jim60105/yt-dlp:pot`) |
| **Web UI** | MeTube (`ghcr.io/alexta69/metube:latest`) |
| **Dashboard** | Angular 17 + nginx (`dashboard/`) |
| **VPN** | OpenVPN Client (`dperson/openvpn-client`) |
| **Landing Page** | Python 3.11 + Flask + requests |
| **Auto-Updates (Docker)** | Watchtower (`containrrr/watchtower:latest`) |
| **Auto-Updates (Podman)** | Host cron job |
| **Orchestration Scripts** | Bash (`#!/bin/bash`, `set -e`) |
| **Configuration** | `.env` file + `docker-compose.yml` |
| **API Contract** | OpenAPI 3.0 (`contracts/metube-api.openapi.yaml`) |
| **E2E Testing** | Playwright (`tests/e2e/`) |

**Note:** There is no `pyproject.toml`, `package.json`, `Cargo.toml`, or similar language-specific manifest at the project root. Build steps are the Flask landing page (`landing/Dockerfile`) and the Angular dashboard (`dashboard/Dockerfile`). The dashboard uses Angular 17.3.0 (not 19), as declared in `dashboard/package.json`.

---

## Project Structure

```
.
├── docker-compose.yml          # Service definitions (8 services, 4 profiles)
├── .env.example               # Configuration template
├── .env                       # Live configuration (not in git)
├── .gitignore                # Comprehensive git ignore
│
├── init                       # Environment setup: validates .env, creates dirs/configs, vpn-auth.txt
├── start                      # Start services (reads USE_VPN from .env)
├── start_no_vpn              # Force start WITHOUT VPN regardless of .env
├── stop                       # Stop all services and clean up resources
├── restart                    # Convenience wrapper: stop + start
├── download                   # Download helper CLI (single URL, --batch, --channels)
├── status                     # Service & runtime status dashboard
├── cleanup                    # Remove containers (all | ytdlp | jdownloader)
├── check-vpn                 # Verify VPN connection via ipinfo.io
├── update-images             # Pull latest container images
├── setup-auto-update         # Install cron job for Podman auto-updates
├── prepare-release.sh        # Git commit/push helper for releases
│
├── Makefile                   # Convenience targets (init, start, stop, test, ci, smoke, audit, dev-check, build)
│
├── lib/
│   └── container-runtime.sh  # Shared runtime detection functions
│
├── landing/
│   ├── app.py                # Flask landing page proxy + cookie upload handler
│   ├── Dockerfile            # python:3.11-slim, installs flask + requests
│   ├── requirements.txt      # flask>=2.0, requests>=2.25
│   ├── logo.png              # Branding asset
│   └── AGENTS.md             # Landing-page-specific agent guidance
│
├── dashboard/
│   ├── src/app/              # Angular 17 standalone components
│   │   ├── components/       # download-form, queue, history, cookies, navbar, not-found, error-boundary
│   │   ├── services/         # MetubeService (HTTP + polling), ErrorInterceptorService
│   │   ├── models/           # download.model.ts
│   │   └── app.routes.ts     # Lazy-loaded routes
│   ├── src/environments/     # environment.ts, environment.prod.ts
│   ├── Dockerfile            # Multi-stage: node:22-alpine → nginx:alpine
│   ├── nginx.conf.template   # SPA fallback + /api proxy with dynamic resolver
│   ├── entrypoint.sh         # Generates nginx.conf from template at runtime
│   ├── package.json          # Angular 17.3.0 dependencies
│   └── AGENTS.md             # Dashboard-specific agent guidance
│
├── yt-dlp/
│   ├── config/
│   │   └── yt-dlp.conf       # Default yt-dlp config (generated by ./init)
│   ├── cookies/              # YouTube cookie files + export scripts for restricted content
│   └── archive/              # Download archive tracking
│
├── metube/
│   └── config/               # MeTube state & cookies
│
├── contracts/
│   └── metube-api.openapi.yaml  # OpenAPI spec for MeTube API proxy contract
│
├── scripts/
│   ├── bootstrap.sh          # Environment bootstrap
│   ├── dev-check.sh          # Pre-push validation gate (shell syntax, Python, compose, build, smoke, audit, git)
│   ├── smoke-test.sh         # E2E smoke tests against REAL running services
│   ├── test-audit.sh         # Test suite quality audit (mock vs integration ratio)
│   ├── validate-contract.sh  # OpenAPI contract validation against live API
│   └── install-hooks.sh      # Git hooks installer
│
├── tests/                     # Automated test suite
│   ├── run-tests.sh          # Main test runner with assertions and profiling
│   ├── run-full-suite.sh     # Full suite with container lifecycle management
│   ├── run-comprehensive-tests.sh  # Extended comprehensive runner
│   ├── test-unit.sh          # Unit tests (runtime detection, compose, colors, env, ports)
│   ├── test-integration.sh   # Integration tests (init, start, stop, download, update-images)
│   ├── test-integration-realhttp.sh  # Real HTTP integration tests
│   ├── test-scenarios.sh     # Scenario tests (Podman/Docker × VPN/no-VPN combinations)
│   ├── test-errors.sh        # Error tests (missing runtime, missing .env, invalid configs)
│   ├── test-dashboard.sh     # Dashboard & landing page HTTP/container tests
│   ├── test-media-services.sh # Media service tests
│   ├── test-chaos.sh         # Chaos/resilience tests
│   ├── test-vpn-smoke.sh     # VPN-specific smoke tests
│   ├── test-dashboard-operations.sh  # Dashboard operations tests
│   ├── config/               # Test .env files
│   ├── logs/                 # Test execution logs
│   ├── results/              # Test reports
│   ├── e2e/                  # Playwright E2E tests
│   ├── cookies/              # Cookie auth validation tests
│   ├── benchmark/            # Performance benchmarks
│   ├── README.md             # Test suite documentation
│   └── AGENTS.md             # Test-specific agent guidance
│
├── docs/                      # Additional documentation
│   ├── FIX_SUMMARY.md
│   ├── VERIFICATION.md
│   └── YOUTUBE_DOWNLOAD_FIX.md
│
├── .github/workflows/
│   ├── ci.yml                # CI: shell checks, unit tests, compose validation, dashboard build, Python validation, code quality
│   ├── integration.yml       # Integration: container startup, dashboard tests, integration/scenario tests, E2E smoke, contract validation
│   └── gates.yml             # Quality gates
│
├── Upstreams/
│   └── GitHub.sh             # Git upstream configuration
│
├── README.md                  # Human-facing documentation
├── USER_GUIDE.md             # Complete user manual
├── CONTRIBUTING.md           # Contribution guidelines
├── CHANGES_SUMMARY.md        # Change log
├── RELEASE_v1.2.0.md         # Release notes
├── TEST_RESULTS.md           # Test reports
├── READY_FOR_TESTING.md      # Release checklist
├── CHALLENGES.md             # Known challenges and decisions
├── Constitution.md           # Project constitution/governance
└── AGENTS.md                 # This file
```

---

## Build / Deploy Commands

### Daily Operations

```bash
# Initialize environment (creates dirs, validates .env, detects runtime, creates yt-dlp.conf)
./init

# Start services (auto-detects Podman/Docker, calls init + update-images first)
./start                    # Uses USE_VPN from .env
./start_no_vpn            # Force no-VPN mode regardless of .env

# Stop services
./stop                     # Stops all profiles, cleans up Podman pods/networks

# Restart services
./restart                  # Stop + Start

# Download videos
./download <URL>           # Download single video
./download --batch        # Download from ./yt-dlp/config/urls.txt
./download --channels     # Download from ./yt-dlp/config/channels.txt
./download --help         # Show help

# Status and diagnostics
./status                   # Check service status, ports, disk usage, external IP
./check-vpn               # Verify VPN connection

# Maintenance
./update-images           # Pull latest container images
./setup-auto-update       # Setup cron job for auto-updates (Podman)
./cleanup [all|ytdlp|jdownloader]  # Remove containers
```

### Makefile Convenience Targets

```bash
make init        # Initialize environment
make start       # Start all services (no-VPN mode)
make stop        # Stop all services
make restart     # Stop then start
make status      # Show service status + HTTP health checks
make smoke       # Run E2E smoke tests (requires running services)
make audit       # Run test suite quality audit
make dev-check   # Run all pre-push validation gates
make build       # Build dashboard container image
make test        # Run full test suite
make ci          # Run CI-level validation (compose, build, tests)
make validate    # Validate API contract
make chaos       # Run chaos tests
```

### Container Runtime Detection

All scripts automatically detect the container runtime:
- **Podman** (preferred if available)
- **Docker** (fallback)

Detection function (embedded in all scripts, also available in `lib/container-runtime.sh`):
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

---

## Service Architecture

### Compose Profiles

- **`vpn`** — Services routed through OpenVPN
- **`no-vpn`** — Direct internet access
- **`vpn-cli`** — CLI-only VPN mode
- **`docker`** — Watchtower (Docker-only auto-updater)

### Services Detail

| Service | Image | Profile | Network | Ports | Purpose |
|---------|-------|---------|---------|-------|---------|
| `openvpn-yt-dlp` | `dperson/openvpn-client` | `vpn` | bridge | `3130:3129/tcp` | VPN tunnel |
| `metube` | `ghcr.io/alexta69/metube:latest` | `vpn` | `service:openvpn-yt-dlp` | — | Web UI via VPN |
| `landing-vpn` | Build `./landing` | `vpn` | bridge | `8087:8080/tcp` | Cookie auth gateway → MeTube VPN |
| `yt-dlp-cli` | `ghcr.io/jim60105/yt-dlp:pot` | `vpn`, `vpn-cli`, `no-vpn` | bridge | — | General CLI container |
| `yt-dlp-cli-vpn` | `ghcr.io/jim60105/yt-dlp:pot` | `vpn`, `vpn-cli` | `service:openvpn-yt-dlp` | — | CLI forced through VPN |
| `metube-direct` | `ghcr.io/alexta69/metube:latest` | `no-vpn` | bridge | `8088:8081/tcp` | Direct MeTube web UI |
| `landing-no-vpn` | Build `./landing` | `no-vpn` | bridge | `8086:80/tcp` | Cookie auth gateway → MeTube direct |
| `dashboard` | Build `./dashboard` | `no-vpn` | bridge | `9090:8080/tcp` | Angular dashboard → MeTube API |
| `watchtower` | `containrrr/watchtower:latest` | `docker` | bridge | — | Auto-image updates every 3h |

### Port Mapping

| Port | Service |
|------|---------|
| **8086** | Landing Page (No VPN) |
| **8087** | Landing Page (VPN) |
| **8088** | MeTube Direct (No VPN) |
| **9090** | YT-DLP Dashboard (No VPN) |
| **8081** | MeTube API (internal) |
| **3130** | yt-dlp VPN proxy |

### Key Volumes

- `${DOWNLOAD_DIR}` → `/downloads` (shared across services)
- `./metube/config` → MeTube state & cookies
- `./yt-dlp/config` → yt-dlp config & batch files
- `./yt-dlp/cookies` → Cookie files for restricted content
- `./yt-dlp/archive` → Download archive tracking
- `${VPN_OVPN_PATH}` → OpenVPN config (read-only)
- `./vpn-auth.txt` → VPN credentials (read-only)

### Health Checks

- `openvpn-yt-dlp` pings `8.8.8.8` every 30s
- `metube` and `yt-dlp-cli-vpn` depend on `openvpn-yt-dlp` being healthy

### yt-dlp Config Defaults (generated by `./init`)

- Archives downloads to `/archive/downloaded.txt`
- Embeds thumbnails and subtitles
- Writes English/Spanish/French subtitles
- Limits video quality to 1080p
- Uses 5 concurrent fragments
- Spoofs Chrome 120 user-agent
- `--verbose` logging enabled

### Landing Page (`landing/app.py`)

A Flask application (branded "Боба") that:
1. Serves a 3-step authentication UI (open YouTube → sign in → export/upload cookies)
2. Handles drag-and-drop cookie file uploads via `/api/upload-cookies`
3. Proxies requests to MeTube via `/app`
4. Checks cookie status via `/api/cookie-status`
5. Provides `/api/delete-download` to remove history items and optionally files
6. Exposes `/health` endpoint for monitoring

### Dashboard (`dashboard/`)

An Angular 17 standalone application served by nginx:
- **Routes:** `/` (download form), `/queue`, `/history`, `/cookies`
- **API Proxy:** nginx proxies `/api/*` to `metube-direct:8081` and `/api/delete-download`, `/api/upload-cookies`, `/api/delete-cookies`, `/api/cookie-status` to `metube-landing:8080`
- **DNS Resilience:** Uses `resolver` directive + variable-based `proxy_pass` to survive container restarts
- **SPA Fallback:** `try_files $uri $uri/ /index.html` for Angular routing
- **Cache Control:** `index.html` is never cached; static assets use `public, no-cache, must-revalidate`

---

## Image Updates

All container images are automatically updated:

1. **On every start**: `./start` and `./start_no_vpn` run `./update-images` before starting containers
2. **Every 3-4 hours**: Automated background updates

### Docker (Watchtower)

Docker users use Watchtower (configured in `docker-compose.yml`):
- Checks for image updates every 3 hours (`WATCHTOWER_SCHEDULE=0 0 */3 * * *`)
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

### Images Referenced

The following images are used by the project:
- `ghcr.io/alexta69/metube:latest`
- `ghcr.io/jim60105/yt-dlp:pot` — Used in `docker-compose.yml`
- `dperson/openvpn-client:latest`
- `containrrr/watchtower:latest` — Docker only

---

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
- **Required vars:** `USE_VPN`, `DOWNLOAD_DIR`
- **VPN vars:** `VPN_USERNAME`, `VPN_PASSWORD`, `VPN_OVPN_PATH`
- **Runtime var:** `CONTAINER_RUNTIME` (podman/docker/auto)

### Naming Conventions

- **Scripts:** lowercase-with-hyphens (no `.sh` extension for top-level scripts, but `.sh` for tests and helpers)
- **Functions:** `lowercase_with_underscores`
- **Variables:** lowercase for local, UPPER_CASE for env/global
- **Containers:** lowercase-with-hyphens (yt-dlp-cli, openvpn-yt-dlp)
- **Directories:** lowercase (metube, yt-dlp, config)

### Docker Compose

- **Profiles:** `vpn`, `no-vpn`, `vpn-cli`, `docker`
- **Container names:** Explicit with `container_name`
- **Restart policy:** `unless-stopped`
- **Health checks:** For VPN containers
- **Network mode:** `service:openvpn-yt-dlp` for VPN routing
- **Resource limits:** All services have `mem_limit`, `memswap_limit`, `pids_limit`, and `oom_score_adj`

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

---

## Testing

> **Anti-Bluff (CONST-034) — read before adding any test.**
> A test passes only when the user-visible behavior it claims to
> cover actually works. Every check in `tests/`, every script in
> `challenges/scripts/`, every gate in `scripts/dev-check.sh`, and
> every assertion under `dashboard/src/**/*.spec.ts` is held to this
> bar. Bluff patterns (status-only assertions, silent network
> short-circuits, mocks across service boundaries, syntactic-success
> as a stand-in for behavioral success) are forbidden — see
> `CONSTITUTION.md` § CONST-034 for the full rule and forbidden
> patterns. Code-review heuristic: *"If I deleted the implementation,
> would this test still pass?"* If yes, the test is bluff. Rewrite it.

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

1. **Unit Tests** (`test-unit.sh`): Individual function testing (runtime detection, compose commands, colors, env parsing, ports, file permissions, string manipulation, VPN config parsing, compose syntax)
2. **Integration Tests** (`test-integration.sh`): Script workflow testing (init, start, stop, download, update-images, cleanup, status, check-vpn, setup-auto-update, compose health)
3. **Scenario Tests** (`test-scenarios.sh`): Combination testing:
   - Podman + No VPN
   - Podman + VPN
   - Docker + No VPN
   - Docker + VPN
   - Batch/Channel downloads
   - Complete workflows
4. **Error Tests** (`test-errors.sh`): Edge cases and error conditions (missing runtime, missing .env, invalid configs, permission issues, port conflicts)
5. **Dashboard Tests** (`test-dashboard.sh`): Container health, HTTP responses, API proxy, DNS resilience, landing page, E2E download flow, CORS, history management, file deletion, cookie/version verification
6. **Media Services Tests** (`test-media-services.sh`): Media-specific validation
7. **Real HTTP Integration** (`test-integration-realhttp.sh`): Live HTTP tests against running services

### Test Assertions

Available in `tests/run-tests.sh`:
- `assert_true "condition" "message"`
- `assert_false "condition" "message"`
- `assert_file_exists "path"`
- `assert_dir_exists "path"`
- `assert_command_exists "cmd"`

### Smoke Tests

```bash
# Run E2E smoke tests against REAL running services
./scripts/smoke-test.sh
```

Tests 6 gates:
1. Service Availability (HTTP 200 on dashboard, landing, MeTube)
2. MeTube Direct API Contract (`/history`, `/version` fields)
3. Dashboard API Proxy (`/api/history`, `/api/version`)
4. Landing Page API (`/api/cookie-status`, `/health`)
5. Critical User Journey (landing has dashboard link, Angular app markers, add download, delete endpoint)
6. Container Health (running containers)

### Test Quality Audit

```bash
# Audit test suite for mock-vs-integration ratio, E2E coverage, contract specs, health checks
./scripts/test-audit.sh
```

Scores out of 70. Need ≥ 60 for "strong" rating. Flags "fantasy-land" tests that mock across boundaries.

### API Contract Validation

```bash
# Validate live API responses against contracts/metube-api.openapi.yaml
./scripts/validate-contract.sh
```

Validates `HistoryResponse`, `DownloadInfo`, `VersionResponse`, `CookieStatusResponse`, `StatusResponse` schemas and cross-service consistency.

### Pre-Push Validation Gate

```bash
# Run before every commit/push — equivalent of CI locally
./scripts/dev-check.sh
```

Checks 6 gates:
0. Shell script syntax (`bash -n`)
1. Python syntax (`python3 -m py_compile`)
2. Docker Compose validation
3. Dashboard build (`ng build --configuration production`)
4. Smoke tests (if containers running)
5. Test audit score (need ≥ 60/70)
6. Git hygiene (staged/unstaged changes)

### CI/CD Pipelines

**`.github/workflows/ci.yml`** runs on push/PR to `main`:
- Shell script syntax validation
- Unit tests (`run-tests.sh -p unit`)
- Docker Compose configuration validation
- Angular dashboard build (Node 22)
- Python syntax validation
- Code quality checks (executable permissions, trailing whitespace)

**`.github/workflows/integration.yml`** runs on push/PR/manual dispatch:
- Environment verification
- Container startup with `no-vpn` profile
- Service readiness checks (dashboard HTML, landing page, MeTube API)
- Unit tests, dashboard tests, integration tests, scenario tests
- E2E smoke tests
- Real HTTP integration tests
- Test quality audit
- API contract validation
- Uploads test logs as artifacts

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

# 6. Run dev-check before pushing
./scripts/dev-check.sh
```

---

## Security Considerations

- **Never commit `.env` or `vpn-auth.txt`** — both are in `.gitignore`
- **Mask credentials in output** — scripts mask `USERNAME` and `PASSWORD` fields
- **Use 600 permissions for sensitive files** — `vpn-auth.txt` is created with `chmod 600`
- **VPN credentials** stored in `vpn-auth.txt` (two lines: username, password)
- **Cookie files** — YouTube cookies at `./yt-dlp/cookies/` and `./metube/config/cookies.txt`
- **Rootless by default** — Podman runs rootless; `./start` uses `--userns=keep-id`
- **VPN isolation** — Separate VPN containers; can run alongside JDownloader with different external IPs
- **Path traversal protection** — `landing/app.py` `delete_download()` validates `target_dir.startswith(os.path.abspath(DOWNLOAD_DIR))`
- **Cookie validation** — `landing/app.py` `_validate_cookie_file()` enforces Netscape format and recognises video-platform domains

---

## Common Tasks

### Add a new service to docker-compose.yml

1. Use existing services as template
2. Add to appropriate profile(s)
3. Set explicit `container_name`
4. Add `restart: unless-stopped`
5. Set resource limits (`mem_limit`, `memswap_limit`, `pids_limit`, `oom_score_adj`)
6. Update `./status` script

### Add a new script

1. Create with `#!/bin/bash` and `set -e`
2. Include runtime detection functions (`detect_container_runtime`, `get_compose_cmd`)
3. Add to README.md Scripts Overview section
4. Make executable: `chmod +x scriptname`
5. Follow color output conventions
6. Add `--help` support
7. Add to `scripts/dev-check.sh` shell syntax gate
8. Add to `.github/workflows/ci.yml` shell check step

### Update documentation

- Keep `README.md` current with new features
- Update `CONTRIBUTING.md` for process changes
- Update this `AGENTS.md` for coding standards
- Update `.env.example` for new variables

---

## Container Runtime Notes

### Podman (Preferred)
- Rootless by default
- No daemon required
- Drop-in Docker replacement
- Use `podman-compose` or `podman compose`
- Auto-updates via host cron (`./setup-auto-update`)
- `./start` passes `--in-pod false --podman-run-args="--userns=keep-id"` to preserve host UID ownership

### Docker (Fallback)
- Traditional container runtime
- Requires daemon
- Use `docker-compose` or `docker compose`
- Auto-updates via Watchtower container

### Runtime Selection

Scripts automatically prefer Podman. To force a runtime:
```bash
# In .env
CONTAINER_RUNTIME=podman   # or docker
```

Or inline:
```bash
CONTAINER_RUNTIME=docker ./start
```

---

## Subdirectory AGENTS.md Files

This project contains additional `AGENTS.md` files in subdirectories that provide more specific guidance:

- **`landing/AGENTS.md`** — Flask app-specific conventions
- **`dashboard/AGENTS.md`** — Angular dashboard-specific conventions
- **`tests/AGENTS.md`** — Test suite-specific conventions

When working in those directories, their local `AGENTS.md` takes precedence over this root file for directory-specific concerns.

---

## Universal Mandatory Constraints

> Cascaded from the HelixAgent root `CLAUDE.md` via `/tmp/UNIVERSAL_MANDATORY_RULES.md`.
> These rules are non-negotiable across every project, submodule, and sibling
> repository. Project-specific addenda are welcome but cannot weaken or
> override these.

### Hard Stops (permanent, non-negotiable)

1. **NO CI/CD pipelines.** No `.github/workflows/`, `.gitlab-ci.yml`,
   `Jenkinsfile`, `.travis.yml`, `.circleci/`, or any automated pipeline.
   No Git hooks either. All builds and tests run manually or via
   Makefile/script targets.
2. **NO HTTPS for Git.** SSH URLs only (`git@github.com:…`,
   `git@gitlab.com:…`, etc.) for clones, fetches, pushes, and submodule
   updates. Including for public repos. SSH keys are configured on every
   service.
3. **NO manual container commands.** Container orchestration is owned by
   the project's binary/orchestrator (e.g. `make build` → `./bin/<app>`).
   Direct `docker`/`podman start|stop|rm` and `docker-compose up|down`
   are prohibited as workflows. The orchestrator reads its configured
   `.env` and brings up everything.

### Mandatory Development Standards

1. **100% Test Coverage.** Every component MUST have unit, integration,
   E2E, automation, security/penetration, and benchmark tests. No false
   positives. Mocks/stubs ONLY in unit tests; all other test types use
   real data and live services.
2. **Challenge Coverage.** Every component MUST have Challenge scripts
   (`./challenges/scripts/`) validating real-life use cases. No false
   success — validate actual behavior, not return codes.
3. **Real Data.** Beyond unit tests, all components MUST use actual API
   calls, real databases, live services. No simulated success. Fallback
   chains tested with actual failures.
4. **Health & Observability.** Every service MUST expose health
   endpoints. Circuit breakers for all external dependencies.
   Prometheus / OpenTelemetry integration where applicable.
5. **Documentation & Quality.** Update `CLAUDE.md`, `AGENTS.md`, and
   relevant docs alongside code changes. Pass language-appropriate
   format/lint/security gates. Conventional Commits:
   `<type>(<scope>): <description>`.
6. **Validation Before Release.** Pass the project's full validation
   suite (`make ci-validate-all`-equivalent) plus all challenges
   (`./challenges/scripts/run_all_challenges.sh`).
7. **No Mocks or Stubs in Production.** Mocks, stubs, fakes,
   placeholder classes, TODO implementations are STRICTLY FORBIDDEN in
   production code. All production code is fully functional with real
   integrations. Only unit tests may use mocks/stubs.
8. **Comprehensive Verification.** Every fix MUST be verified from all
   angles: runtime testing (actual HTTP requests / real CLI
   invocations), compile verification, code structure checks,
   dependency existence checks, backward compatibility, and no false
   positives in tests or challenges. Grep-only validation is NEVER
   sufficient.
9. **Resource Limits for Tests & Challenges (CRITICAL).** ALL test and
   challenge execution MUST be strictly limited to 30-40% of host
   system resources. Use `GOMAXPROCS=2`, `nice -n 19`, `ionice -c 3`,
   `-p 1` for `go test`. Container limits required. The host runs
   mission-critical processes — exceeding limits causes system crashes.
10. **Bugfix Documentation.** All bug fixes MUST be documented in
    `docs/issues/fixed/BUGFIXES.md` (or the project's equivalent) with
    root cause analysis, affected files, fix description, and a link to
    the verification test/challenge.
11. **Real Infrastructure for All Non-Unit Tests.** Mocks/fakes/stubs/
    placeholders MAY be used ONLY in unit tests (files ending
    `_test.go` run under `go test -short`, equivalent for other
    languages). ALL other test types — integration, E2E, functional,
    security, stress, chaos, challenge, benchmark, runtime
    verification — MUST execute against the REAL running system with
    REAL containers, REAL databases, REAL services, and REAL HTTP
    calls. Non-unit tests that cannot connect to real services MUST
    skip (not fail).
12. **Reproduction-Before-Fix (CONST-032 — MANDATORY).** Every reported
    error, defect, or unexpected behavior MUST be reproduced by a
    Challenge script BEFORE any fix is attempted. Sequence:
    (1) Write the Challenge first. (2) Run it; confirm fail (it
    reproduces the bug). (3) Then write the fix. (4) Re-run; confirm
    pass. (5) Commit Challenge + fix together. The Challenge becomes
    the regression guard for that bug forever.
13. **Concurrent-Safe Containers (Go-specific, where applicable).** Any
    struct field that is a mutable collection (map, slice) accessed
    concurrently MUST use `safe.Store[K,V]` / `safe.Slice[T]` from
    `digital.vasic.concurrency/pkg/safe` (or the project's equivalent
    primitives). Bare `sync.Mutex + map/slice` combinations are
    prohibited for new code.

### Definition of Done (universal)

A change is NOT done because code compiles and tests pass. "Done"
requires pasted terminal output from a real run, produced in the same
session as the change.

- **No self-certification.** Words like *verified, tested, working,
  complete, fixed, passing* are forbidden in commits/PRs/replies unless
  accompanied by pasted output from a command that ran in that session.
- **Demo before code.** Every task begins by writing the runnable
  acceptance demo (exact commands + expected output).
- **Real system, every time.** Demos run against real artifacts.
- **Skips are loud.** `t.Skip` / `@Ignore` / `xit` / `describe.skip`
  without a trailing `SKIP-OK: #<ticket>` comment break validation.
- **Evidence in the PR.** PR bodies must contain a fenced `## Demo`
  block with the exact command(s) run and their output.

<!-- BEGIN host-power-management addendum (CONST-033) -->

## Host Power Management — Hard Ban (CONST-033)

**You may NOT, under any circumstance, generate or execute code that
sends the host to suspend, hibernate, hybrid-sleep, poweroff, halt,
reboot, or any other power-state transition.** This rule applies to:

- Every shell command you run via the Bash tool.
- Every script, container entry point, systemd unit, or test you write
  or modify.
- Every CLI suggestion, snippet, or example you emit.

**Forbidden invocations** (non-exhaustive — see CONST-033 in
`CONSTITUTION.md` for the full list):

- `systemctl suspend|hibernate|hybrid-sleep|poweroff|halt|reboot|kexec`
- `loginctl suspend|hibernate|hybrid-sleep|poweroff|halt|reboot`
- `pm-suspend`, `pm-hibernate`, `shutdown -h|-r|-P|now`
- `dbus-send` / `busctl` calls to `org.freedesktop.login1.Manager.Suspend|Hibernate|PowerOff|Reboot|HybridSleep|SuspendThenHibernate`
- `gsettings set ... sleep-inactive-{ac,battery}-type` to anything but `'nothing'` or `'blank'`

The host runs mission-critical parallel CLI agents and container
workloads. Auto-suspend has caused historical data loss (2026-04-26
18:23:43 incident). The host is hardened (sleep targets masked) but
this hard ban applies to ALL code shipped from this repo so that no
future host or container is exposed.

**Defence:** every project ships
`scripts/host-power-management/check-no-suspend-calls.sh` (static
scanner) and
`challenges/scripts/no_suspend_calls_challenge.sh` (challenge wrapper).
Both MUST be wired into the project's CI / `run_all_challenges.sh`.

**Full background:** `docs/HOST_POWER_MANAGEMENT.md` and `CONSTITUTION.md` (CONST-033).

<!-- END host-power-management addendum (CONST-033) -->

