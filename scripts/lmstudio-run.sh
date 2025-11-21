#!/bin/bash

# LM Studio Headless Run Script
# This script launches LM Studio in headless mode using Xvfb

# Set Home to the service user's home (essential for configs)
# IMPORTANT: Replace <YOUR_USERNAME> with your actual Linux username
export HOME=/home/<YOUR_USERNAME>

# Navigate to the extracted folder (created by the updater/initial run)
cd /opt/lmstudio/squashfs-root || exit 1

# Launch with xvfb-run to simulate a display, and use --headless for server mode.
exec xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
    ./lm-studio --no-sandbox --headless