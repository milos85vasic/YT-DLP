#!/bin/sh
# yt-dlp-wrapper.sh - Wrapper to use yt-dlp from yt-dlp-cli container

# Pass all arguments to yt-dlp in the yt-dlp-cli container
# Note: We need to handle paths correctly since they're different in each container

# Replace /app/downloads with /downloads for the yt-dlp-cli container
ARGS=""
for arg in "$@"; do
    # Convert paths from YoutubeDL-Material format to yt-dlp-cli format
    modified_arg=$(echo "$arg" | sed 's|/app/downloads|/downloads|g')
    # Handle space in arguments
    if echo "$arg" | grep -q " "; then
        ARGS="$ARGS \"$modified_arg\""
    else
        ARGS="$ARGS $modified_arg"
    fi
done

# Execute yt-dlp in the yt-dlp-cli container
# Use eval to properly handle quoted arguments
eval "docker exec yt-dlp-cli yt-dlp $ARGS"
