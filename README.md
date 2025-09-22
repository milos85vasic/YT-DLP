# YT-DLP

Run YT-DLP inside the Docker container.

## How to Use

Create an .env file (optional but recommended) in the same directory as your docker-compose.yml:

```bash
# Download Directory Path on Host
DOWNLOAD_DIR=/mnt/DATA/Downloads

# YT-DLP Options
AUTO_UPDATE=true
SERVICE_MODE=false
CHECK_INTERVAL=3600

# Timezone
TZ=Europe/Moscow

# OpenVPN Settings
VPN_OVPN_PATH=/absolute/path/to/your/config.ovpn  # e.g., /home/username/vpn/config.ovpn

# Make sure that you have this in it:
# auth-user-pass /vpn/vpn.auth <-------------------------------------------------------- !!! 
# ---------------------------------------------------------------------------------------

VPN_USERNAME=your_vpn_username
VPN_PASSWORD=your_vpn_password

# Use VPN toggle
USE_VPN=true
```

Replace the placeholders with your actual values. This file should be kept secure and not shared.

Then, run the container:

```bash
./start
```

## Quick commands

- Download single video:

    ```bash
    docker exec yt-dlp yt-dlp 'https://www.youtube.com/watch?v=VIDEO_ID'
    ```

- Download from batch file:

    ```bash
    docker exec yt-dlp yt-dlp --batch-file /config/urls.txt
    ```

- Check container logs:

    ```bash
    docker-compose logs -f yt-dlp
    ```
