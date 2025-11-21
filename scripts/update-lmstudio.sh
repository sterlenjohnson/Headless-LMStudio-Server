#!/bin/bash

# LM Studio Auto-Update Script
# This script downloads the latest LM Studio AppImage, extracts it, and restarts the service

# IMPORTANT: Replace <YOUR_USERNAME> with your actual Linux username
SERVICE_USER="<YOUR_USERNAME>"
INSTALL_DIR="/opt/lmstudio"
DOWNLOAD_URL="https://lmstudio.ai/download/latest/linux/x64"
NEW_FILE="LM-Studio-latest.AppImage"

echo "$(date): Starting Update..." | tee -a "$INSTALL_DIR/update.log"
cd "$INSTALL_DIR" || exit 1

# 1. Download latest version
echo "Downloading latest version..."
wget -q --show-progress -O "$NEW_FILE.tmp" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "$(date): Download failed." | tee -a "$INSTALL_DIR/update.log"
    rm -f "$NEW_FILE.tmp"
    exit 1
fi

# 2. Stop Service
echo "Stopping LM Studio service..."
systemctl stop lmstudio.service

# 3. Backup & Replace
echo "Creating backup and replacing AppImage..."
rm -rf squashfs-root.bak
mv squashfs-root squashfs-root.bak 2>/dev/null
mv "$NEW_FILE.tmp" "$NEW_FILE"
chmod +x "$NEW_FILE"

# 4. Extract (Crucial for headless execution)
echo "Extracting AppImage..."
./"$NEW_FILE" --appimage-extract > /dev/null

# 5. Fix Permissions
echo "Fixing permissions..."
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR"

# 6. Restart Service
echo "Restarting LM Studio service..."
systemctl start lmstudio.service

echo "$(date): Update Complete." | tee -a "$INSTALL_DIR/update.log"