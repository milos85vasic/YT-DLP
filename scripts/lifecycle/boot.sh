#!/bin/bash
#
# Boot script for YT-DLP Container System
# Starts all services and verifies they are running
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    YT-DLP System Boot Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Load Environment
# =============================================================================

if [ ! -f "$PROJECT_DIR/.env" ]; then
    log_error ".env file not found in $PROJECT_DIR"
    log_error "Run ./scripts/setup/init first"
    exit 1
fi

set -a
source "$PROJECT_DIR/.env"
set +a

# Determine container runtime
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_RUNTIME="docker"
else
    log_error "No container runtime found (Podman or Docker)"
    exit 1
fi

log_info "Container Runtime: $CONTAINER_RUNTIME"
log_info "VPN Enabled: ${USE_VPN:-false}"
echo ""

# =============================================================================
# Determine Start Method
# =============================================================================

USE_SYSTEMD="${USE_SYSTEMD:-false}"

if [ "$USE_SYSTEMD" = "true" ]; then
    log_info "Using systemd user services for startup"
    START_SCRIPT="$PROJECT_DIR/scripts/service/start-systemd.sh"
    STATUS_SCRIPT="$PROJECT_DIR/scripts/service/status-systemd.sh"
else
    log_info "Using docker-compose for startup"
    START_SCRIPT="$PROJECT_DIR/scripts/service/start"
    STATUS_SCRIPT="$PROJECT_DIR/scripts/service/status"
fi

# =============================================================================
# Start Services
# =============================================================================

log_info "Starting services..."
echo ""

if [ ! -f "$START_SCRIPT" ]; then
    log_error "Start script not found: $START_SCRIPT"
    exit 1
fi

# Run start script
"$START_SCRIPT"
START_EXIT_CODE=$?

if [ $START_EXIT_CODE -ne 0 ]; then
    log_error "Service startup failed with exit code $START_EXIT_CODE"
    exit $START_EXIT_CODE
fi

# Wait for services to stabilize
log_info "Waiting for services to stabilize..."
sleep 5

# =============================================================================
# Verify Services
# =============================================================================

log_info "Verifying service health..."
echo ""

if [ ! -f "$STATUS_SCRIPT" ]; then
    log_error "Status script not found: $STATUS_SCRIPT"
    exit 1
fi

# Run status script to check health
"$STATUS_SCRIPT"
STATUS_EXIT_CODE=$?

# =============================================================================
# Additional Health Checks
# =============================================================================

echo ""
log_info "Running additional health checks..."

HEALTH_FAILED=0

# Check if we can reach the web interfaces
if [ "$USE_SYSTEMD" = "true" ]; then
    # Systemd mode - check systemd status
    log_info "Checking systemd service status..."
    
    if [ "${USE_VPN:-false}" = "true" ]; then
        SERVICES_TO_CHECK=(
            "openvpn-yt-dlp.service"
            "metube.service"
            "landing-vpn.service"
            "yt-dlp-cli.service"
            "yt-dlp-cli-vpn.service"
        )
    else
        SERVICES_TO_CHECK=(
            "metube-direct.service"
            "landing-no-vpn.service"
            "dashboard.service"
            "media-postprocessor.service"
            "yt-dlp-cli.service"
        )
    fi
    
    if [ "$CONTAINER_RUNTIME" = "docker" ]; then
        SERVICES_TO_CHECK+=("watchtower.service")
    fi
    
    for service in "${SERVICES_TO_CHECK[@]}"; do
        if systemctl --user list-unit-files | grep -q "^${service}"; then
            SUBSTATE=$(systemctl --user show "$service" --property=SubState --value 2>/dev/null)
            if [ "$SUBSTATE" = "running" ]; then
                log_success "$service is running"
            else
                log_error "$service is not running (state: $SUBSTATE)"
                HEALTH_FAILED=$((HEALTH_FAILED + 1))
            fi
        fi
    done
else
    # Docker-compose mode - check HTTP endpoints
    log_info "Checking HTTP endpoints..."
    
    # Check dashboard
    if curl -sf "http://localhost:9090" > /dev/null 2>&1; then
        log_success "Dashboard (port 9090) is accessible"
    else
        log_warning "Dashboard (port 9090) is not accessible"
    fi
    
    # Check landing page
    if [ "${USE_VPN:-false}" = "true" ]; then
        if curl -sf "http://localhost:8087" > /dev/null 2>&1; then
            log_success "Landing page VPN (port 8087) is accessible"
        else
            log_warning "Landing page VPN (port 8087) is not accessible"
        fi
    else
        if curl -sf "http://localhost:8086" > /dev/null 2>&1; then
            log_success "Landing page (port 8086) is accessible"
        else
            log_warning "Landing page (port 8086) is not accessible"
        fi
    fi
    
    # Check MeTube
    if [ "${USE_VPN:-false}" = "true" ]; then
        if curl -sf "http://localhost:8086" > /dev/null 2>&1; then
            log_success "MeTube VPN (port 8086) is accessible"
        else
            log_warning "MeTube VPN (port 8086) is not accessible"
        fi
    else
        if curl -sf "http://localhost:8088" > /dev/null 2>&1; then
            log_success "MeTube Direct (port 8088) is accessible"
        else
            log_warning "MeTube Direct (port 8088) is not accessible"
        fi
    fi
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
if [ $HEALTH_FAILED -eq 0 ] && [ $STATUS_EXIT_CODE -eq 0 ]; then
    echo -e "${BLUE}    Boot Complete - All Services Healthy ✓${NC}"
else
    echo -e "${BLUE}    Boot Complete - Some Issues Detected ⚠${NC}"
fi
echo -e "${BLUE}============================================${NC}"
echo ""

if [ $HEALTH_FAILED -gt 0 ]; then
    log_warning "$HEALTH_FAILED service(s) failed health checks"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check service logs: journalctl --user -u <service> (systemd)"
    echo "  • Check container logs: $CONTAINER_RUNTIME logs <container> (docker-compose)"
    echo "  • Verify .env configuration"
    echo "  • Run ./scripts/service/status for detailed status"
fi

echo ""
log_success "Boot process completed!"

# Exit with appropriate code
if [ $HEALTH_FAILED -gt 0 ]; then
    exit 1
fi

