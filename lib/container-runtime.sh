# Container runtime detection and configuration
# This file is sourced by other scripts

# Detect available container runtime (prefer Podman over Docker)
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

# Get the appropriate compose command
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

# Check if container runtime is available
check_runtime() {
    local runtime="$1"
    if [ "$runtime" = "none" ]; then
        echo -e "${RED}ERROR: No container runtime found (Podman or Docker required)${NC}"
        exit 1
    fi
}

# Export functions for use in other scripts
export -f detect_container_runtime
export -f get_compose_cmd
export -f check_runtime
