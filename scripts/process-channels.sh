#!/bin/sh
# process-channels.sh - Process subscribed channels on demand

echo "Processing subscribed channels..."

if [ -f "/config/channels.txt" ] && [ -s "/config/channels.txt" ]; then
    while IFS= read -r channel; do
        # Skip comments and empty lines
        case "$channel" in
            "#"*|"") continue ;;
        esac
        
        echo "Checking channel: $channel"
        yt-dlp --config-location "/config/yt-dlp.conf" \
               --download-archive "/archive/archive.txt" \
               --dateafter "now-7days" \
               "$channel"
    done < "/config/channels.txt"
else
    echo "No channels found in /config/channels.txt"
fi
