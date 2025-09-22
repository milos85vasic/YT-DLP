#!/bin/sh
# yt-dlp-service.sh - Service script for yt-dlp container

set -e

# Default settings
SERVICE_MODE="${SERVICE_MODE:-false}"
CHECK_INTERVAL="${CHECK_INTERVAL:-3600}"
CONFIG_DIR="${CONFIG_DIR:-/config}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/downloads}"

echo "========================================"
echo "     yt-dlp Docker Container Service    "
echo "========================================"
echo ""
echo "Service Mode: $SERVICE_MODE"
echo "Check Interval: $CHECK_INTERVAL seconds"
echo "Config Dir: $CONFIG_DIR"
echo "Download Dir: $DOWNLOAD_DIR"
echo ""

# Function to process URLs file
process_urls() {
    if [ -f "$CONFIG_DIR/urls.txt" ] && [ -s "$CONFIG_DIR/urls.txt" ]; then
        echo "[$(date)] Processing URLs from $CONFIG_DIR/urls.txt..."
        yt-dlp --config-location "$CONFIG_DIR/yt-dlp.conf" \
               --batch-file "$CONFIG_DIR/urls.txt" || true
        
        # Clear processed URLs
        > "$CONFIG_DIR/urls.txt"
        echo "[$(date)] Cleared urls.txt"
    fi
}

# Function to process channels
process_channels() {
    if [ -f "$CONFIG_DIR/channels.txt" ] && [ -s "$CONFIG_DIR/channels.txt" ]; then
        echo "[$(date)] Processing channel subscriptions..."
        while IFS= read -r channel; do
            # Skip comments and empty lines
            case "$channel" in
                "#"*|"") continue ;;
            esac
            
            echo "[$(date)] Checking channel: $channel"
            yt-dlp --config-location "$CONFIG_DIR/yt-dlp.conf" \
                   --download-archive "/archive/archive.txt" \
                   --dateafter "now-7days" \
                   "$channel" || true
        done < "$CONFIG_DIR/channels.txt"
    fi
}

# Main loop
if [ "$SERVICE_MODE" = "true" ]; then
    echo "Starting in service mode..."
    while true; do
        process_urls
        process_channels
        
        echo "[$(date)] Sleeping for $CHECK_INTERVAL seconds..."
        sleep "$CHECK_INTERVAL"
    done
else
    echo "Running in standby mode..."
    echo "Use 'docker exec yt-dlp yt-dlp [URL]' to download videos"
    echo "Or add URLs to $CONFIG_DIR/urls.txt and run:"
    echo "  docker exec yt-dlp /scripts/process-urls.sh"
    
    # Keep container running
    while true; do
        sleep 3600
    done
fi
