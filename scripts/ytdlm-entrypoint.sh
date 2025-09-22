#!/bin/sh
# Custom entrypoint for YoutubeDL-Material

echo "Updating to latest yt-dlp..."

# Download latest yt-dlp
wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp

# Replace youtube-dl with yt-dlp
rm -f /app/node_modules/youtube-dl/bin/youtube-dl
ln -s /usr/local/bin/yt-dlp /app/node_modules/youtube-dl/bin/youtube-dl

echo "yt-dlp updated to: $(/usr/local/bin/yt-dlp --version)"

# Start the original entrypoint
exec /app/entrypoint.sh "$@"
