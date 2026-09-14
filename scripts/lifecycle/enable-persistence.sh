#!/bin/bash
#
# Enable service persistence across reboots
# Configures systemd user services to start automatically on boot
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
echo -e "${BLUE}    Enable Service Persistence${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Check if running as root (not needed for user services)
# =============================================================================

if [ "$EUID" -eq 0 ]; then
    log_warning "Running as root - this script is designed for user-level systemd services"
    log_warning "Run as your regular user instead"
fi

# =============================================================================
# Enable Linger
# =============================================================================

log_info "Checking linger status for user: $(whoami)"

if loginctl show-user "$(whoami)" --property=Linger 2>/dev/null | grep -q "Linger=yes"; then
    log_success "Linger is already enabled"
else
    log_info "Enabling linger for user: $(whoami)"
    
    if loginctl enable-linger "$(whoami)" 2>/dev/null; then
        log_success "Linger enabled successfully"
    else
        log_warning "Failed to enable linger (may require sudo)"
        log_warning "Run manually: sudo loginctl enable-linger $(whoami)"
    fi
fi

echo ""

# =============================================================================
# Verify Systemd User Services
# =============================================================================

log_info "Checking systemd user services..."

SERVICES=(
    "openvpn-yt-dlp.service"
    "metube.service"
    "landing-vpn.service"
    "yt-dlp-cli.service"
    "yt-dlp-cli-vpn.service"
    "metube-direct.service"
    "landing-no-vpn.service"
    "dashboard.service"
    "media-postprocessor.service"
    "watchtower.service"
)

ENABLED_COUNT=0
TOTAL_COUNT=0

for service in "${SERVICES[@]}"; do
    if systemctl --user list-unit-files | grep -q "^${service}"; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        ENABLED=$(systemctl --user is-enabled "$service" 2>/dev/null || echo "disabled")
        
        if [ "$ENABLED" = "enabled" ]; then
            log_success "$service is enabled"
            ENABLED_COUNT=$((ENABLED_COUNT + 1))
        else
            log_warning "$service is not enabled (status: $ENABLED)"
            log_info "  Enabling $service..."
            systemctl --user enable "$service" 2>/dev/null && log_success "  Enabled" || log_warning "  Failed to enable"
        fi
    fi
done

echo ""
log_info "Enabled services: $ENABLED_COUNT / $TOTAL_COUNT"

# =============================================================================
# Verify Restart Policies
# =============================================================================

log_info "Verifying restart policies in unit files..."

RESTART_OK=0
RESTART_TOTAL=0

for service in "${SERVICES[@]}"; do
    UNIT_FILE="$HOME/.config/systemd/user/$service"
    if [ -f "$UNIT_FILE" ]; then
        RESTART_TOTAL=$((RESTART_TOTAL + 1))
        if grep -q "Restart=unless-stopped\|Restart=always\|Restart=on-failure" "$UNIT_FILE"; then
            RESTART_OK=$((RESTART_OK + 1))
            log_success "$service has restart policy"
        else
            log_warning "$service missing restart policy"
        fi
    fi
done

echo ""
log_info "Services with restart policy: $RESTART_OK / $RESTART_TOTAL"

# =============================================================================
# Verify Service Dependencies
# =============================================================================

log_info "Verifying service dependencies..."

# Check that VPN services depend on openvpn
VPN_DEPS=(
    "metube.service:openvpn-yt-dlp.service"
    "landing-vpn.service:metube.service"
    "yt-dlp-cli-vpn.service:openvpn-yt-dlp.service"
)

for dep in "${VPN_DEPS[@]}"; do
    SERVICE="${dep%%:*}"
    REQUIRES="${dep##*:}"
    
    UNIT_FILE="$HOME/.config/systemd/user/$SERVICE"
    if [ -f "$UNIT_FILE" ]; then
        if grep -q "Requires=$REQUIRES\|After=$REQUIRES" "$UNIT_FILE"; then
            log_success "$SERVICE depends on $REQUIRES"
        else
            log_warning "$SERVICE missing dependency on $REQUIRES"
        fi
    fi
done

# Check that direct services don't depend on VPN
NO_VPN_DEPS=(
    "metube-direct.service"
    "landing-no-vpn.service"
    "dashboard.service"
)

for service in "${NO_VPN_DEPS[@]}"; do
    UNIT_FILE="$HOME/.config/systemd/user/$service"
    if [ -f "$UNIT_FILE" ]; then
        if grep -q "openvpn-yt-dlp" "$UNIT_FILE"; then
            log_warning "$service unexpectedly references openvpn-yt-dlp"
        else
            log_success "$service correctly independent of VPN"
        fi
    fi
done

echo ""

# =============================================================================
# Summary
# =============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Persistence Configuration Complete${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${CYAN}For services to auto-start on boot:${NC}"
echo "  1. Linger must be enabled: loginctl enable-linger \$(whoami)"
echo "  2. Services must be enabled: systemctl --user enable <service>"
echo "  3. Services must have Restart=unless-stopped (already configured)"
echo "  4. Service dependencies must be correctly defined (already configured)"
echo ""

if [ "$ENABLED_COUNT" -eq "$TOTAL_COUNT" ] && [ "$RESTART_OK" -eq "$RESTART_TOTAL" ]; then
    log_success "All services configured for persistence across reboots!"
    exit 0
else
    log_warning "Some services need attention (see above)"
    exit 1
fi

