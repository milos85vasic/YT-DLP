#!/bin/sh
# Custom entrypoint for YoutubeDL-Material

echo "Setting up yt-dlp..."

# First check if curl is available, if not use node's built-in fetch
if command -v curl >/dev/null 2>&1; then
    echo "Downloading yt-dlp with curl..."
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
elif command -v node >/dev/null 2>&1; then
    echo "Downloading yt-dlp with node..."
    node -e "
    const https = require('https');
    const fs = require('fs');
    const file = fs.createWriteStream('/usr/local/bin/yt-dlp');
    https.get('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp', (response) => {
        response.pipe(file);
        file.on('finish', () => {
            file.close();
            process.exit(0);
        });
    }).on('error', (err) => {
        fs.unlink('/usr/local/bin/yt-dlp', () => {});
        console.error(err);
        process.exit(1);
    });
    "
else
    echo "Neither curl nor node available, using existing youtube-dl"
    # Start the original entrypoint without modification
    exec /app/entrypoint.sh "$@"
fi

# Make executable
chmod +x /usr/local/bin/yt-dlp

# Replace youtube-dl with yt-dlp
rm -f /app/node_modules/youtube-dl/bin/youtube-dl
ln -s /usr/local/bin/yt-dlp /app/node_modules/youtube-dl/bin/youtube-dl

echo "yt-dlp setup complete"

# Start the original entrypoint
exec /app/entrypoint.sh "$@"
EOF

chmod +x scripts/ytdlm-entrypoint.sh
