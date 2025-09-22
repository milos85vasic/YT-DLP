#!/bin/sh
# process-urls.sh - Process URLs on demand

echo "Processing URLs from /config/urls.txt..."

if [ -f "/config/urls.txt" ] && [ -s "/config/urls.txt" ]; then
    yt-dlp --config-location "/config/yt-dlp.conf" \
           --batch-file "/config/urls.txt"
    
    # Clear processed URLs
    > "/config/urls.txt"
    echo "URLs processed and cleared from urls.txt"
else
    echo "No URLs found in /config/urls.txt"
fi
