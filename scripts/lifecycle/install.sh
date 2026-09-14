#!/bin/bash
#
# Installation script for YT-DLP Container System
# Prepares the environment and installs dependencies
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
echo -e "${BLUE}    YT-DLP System Installation Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Check and Install Container Runtime
# =============================================================================

check_container_runtime() {
    log_info "Checking container runtime..."
    
    if command -v podman &> /dev/null; then
        local version
        version=$(podman --version 2>/dev/null | head -1)
        log_success "Podman found: $version"
        CONTAINER_RUNTIME="podman"
        return 0
    elif command -v docker &> /dev/null; then
        local version
        version=$(docker --version 2>/dev/null | head -1)
        log_success "Docker found: $version"
        CONTAINER_RUNTIME="docker"
        return 0
    else
        log_warning "No container runtime found (Podman or Docker)"
        return 1
    fi
}

install_container_runtime() {
    log_info "Attempting to install container runtime..."
    
    # Detect package manager
    if command -v apt &> /dev/null; then
        log_info "Detected apt package manager (Debian/Ubuntu)"
        if [ -z "$AUTO_INSTALL" ]; then
            read -p "Install Podman using apt? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Container runtime installation skipped by user"
                return 1
            fi
        fi
        
        apt update && apt install -y podman podman-compose
        
    elif command -v dnf &> /dev/null; then
        log_info "Detected dnf package manager (Fedora/RHEL)"
        if [ -z "$AUTO_INSTALL" ]; then
            read -p "Install Podman using dnf? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Container runtime installation skipped by user"
                return 1
            fi
        fi
        
        dnf install -y podman podman-compose
        
    elif command -v pacman &> /dev/null; then
        log_info "Detected pacman package manager (Arch Linux)"
        if [ -z "$AUTO_INSTALL" ]; then
            read -p "Install Podman using pacman? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Container runtime installation skipped by user"
                return 1
            fi
        fi
        
        pacman -S --noconfirm podman podman-compose
        
    elif command -v zypper &> /dev/null; then
        log_info "Detected zypper package manager (openSUSE)"
        if [ -z "$AUTO_INSTALL" ]; then
            read -p "Install Podman using zypper? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Container runtime installation skipped by user"
                return 1
            fi
        fi
        
        zypper install -y podman podman-compose
        
    elif command -v brew &> /dev/null; then
        log_info "Detected Homebrew (macOS)"
        if [ -z "$AUTO_INSTALL" ]; then
            read -p "Install Podman using Homebrew? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Container runtime installation skipped by user"
                return 1
            fi
        fi
        
        brew install podman
        
    else
        log_error "No supported package manager found"
        log_error "Please install Podman or Docker manually:"
        log_error "  • Podman: https://podman.io/getting-started/installation"
        log_error "  • Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    # Verify installation
    if command -v podman &> /dev/null; then
        local version
        version=$(podman --version 2>/dev/null | head -1)
        log_success "Podman installed successfully: $version"
        CONTAINER_RUNTIME="podman"
        return 0
    else
        log_error "Container runtime installation failed"
        return 1
    fi
}

# Check for container runtime
if ! check_container_runtime; then
    if [ -n "$AUTO_INSTALL" ]; then
        install_container_runtime || exit 1
    else
        log_error "Please install Podman or Docker before continuing"
        log_error "Run with AUTO_INSTALL=1 to attempt automatic installation"
        exit 1
    fi
fi

# =============================================================================
# Check and Install Compose Plugin
# =============================================================================

check_compose_plugin() {
    log_info "Checking compose plugin..."
    
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        if command -v podman-compose &> /dev/null || podman compose version &> /dev/null 2>&1; then
            log_success "Podman compose plugin found"
            return 0
        else
            log_warning "Podman compose plugin not found"
            return 1
        fi
    else
        if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
            log_success "Docker compose plugin found"
            return 0
        else
            log_warning "Docker compose plugin not found"
            return 1
        fi
    fi
}

install_compose_plugin() {
    log_info "Attempting to install compose plugin..."
    
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        # Podman compose is usually installed with podman or via pip
        if command -v pip3 &> /dev/null; then
            if [ -z "$AUTO_INSTALL" ]; then
                read -p "Install podman-compose using pip3? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_error "Compose plugin installation skipped by user"
                    return 1
                fi
            fi
            pip3 install --user podman-compose
        else
            log_error "pip3 not found, cannot install podman-compose"
            return 1
        fi
    else
        # Docker compose v2 is usually included with Docker Desktop
        # For Docker Engine, it might need separate installation
        log_warning "Docker compose v2 should be included with Docker installation"
        log_warning "If missing, install Docker Desktop or the docker-compose-plugin package"
        return 1
    fi
    
    if check_compose_plugin; then
        log_success "Compose plugin installed successfully"
        return 0
    else
        log_error "Compose plugin installation failed"
        return 1
    fi
}

if ! check_compose_plugin; then
    if [ -n "$AUTO_INSTALL" ]; then
        install_compose_plugin || log_warning "Compose plugin installation failed, but continuing..."
    else
        log_warning "Compose plugin not found. Run with AUTO_INSTALL=1 to attempt installation."
    fi
fi

# =============================================================================
# Run Environment Setup (init)
# =============================================================================

log_info "Running environment setup..."
echo ""

if [ -f "$PROJECT_DIR/scripts/setup/init" ]; then
    cd "$PROJECT_DIR"
    "$PROJECT_DIR/scripts/setup/init"
    INIT_EXIT_CODE=$?
    
    if [ $INIT_EXIT_CODE -eq 0 ]; then
        log_success "Environment setup completed successfully"
    else
        log_error "Environment setup failed with exit code $INIT_EXIT_CODE"
        exit $INIT_EXIT_CODE
    fi
else
    log_error "Init script not found at $PROJECT_DIR/scripts/setup/init"
    exit 1
fi

# =============================================================================
# Setup Systemd User Services
# =============================================================================

log_info "Setting up systemd user services..."
echo ""

if [ -f "$PROJECT_DIR/scripts/setup/setup-systemd.sh" ]; then
    cd "$PROJECT_DIR"
    "$PROJECT_DIR/scripts/setup/setup-systemd.sh"
    SETUP_EXIT_CODE=$?
    
    if [ $SETUP_EXIT_CODE -eq 0 ]; then
        log_success "Systemd user services setup completed successfully"
    else
        log_error "Systemd user services setup failed with exit code $SETUP_EXIT_CODE"
        exit $SETUP_EXIT_CODE
    fi
else
    log_warning "Systemd setup script not found, skipping systemd setup"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Installation Complete! ✓${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${CYAN}Container Runtime:${NC} $CONTAINER_RUNTIME"
echo -e "${CYAN}Project Directory:${NC} $PROJECT_DIR"
echo ""

echo -e "${GREEN}Next steps:${NC}"
echo "  1. Start services (docker-compose):  ./scripts/service/start"
echo "  2. Start services (systemd):         ./scripts/service/start-systemd.sh"
echo "  3. Check status:                     ./scripts/service/status"
echo "  4. Check systemd status:             ./scripts/service/status-systemd.sh"
echo "  5. Download video:                   ./scripts/service/download 'VIDEO_URL'"
echo ""

if [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo -e "${CYAN}Note:${NC} For Podman, services will not auto-start on boot by default."
    echo "  To enable auto-start, run: loginctl enable-linger \$USER"
    echo "  And enable services: systemctl --user enable <service>.service"
fi

echo ""
log_success "Installation completed successfully!"

