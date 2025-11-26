#!/bin/bash

# LM Studio Headless Run Script
# This script launches LM Studio in headless mode using Xvfb

# Set Home to the service user's home (essential for configs)
# IMPORTANT: Replace <YOUR_USERNAME> with your actual Linux username
export HOME=/home/<YOUR_USERNAME>

# Navigate to the extracted folder (created by the updater/initial run)
APP_DIR="/opt/lmstudio/squashfs-root"
if [ ! -d "$APP_DIR" ]; then
    echo "Error: Application directory not found at $APP_DIR"
    exit 1
fi

cd "$APP_DIR" || exit 1

# Check if the lm-studio binary exists
if [ ! -x "./lm-studio" ]; then
    echo "Error: LM Studio binary not found or not executable"
    exit 1
fi

# Launch with xvfb-run to simulate a display, and use --headless for server mode.
echo "Starting LM Studio in headless mode..."
exec xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
    ./lm-studio --no-sandbox --headless