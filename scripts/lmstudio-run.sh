#!/bin/bash

# This script is executed by Systemd to launch LM Studio in headless mode.
# IMPORTANT: Replace <YOUR_USERNAME> with your actual Linux username.

# Set Home to the service user's home (essential for configs and model cache)
export HOME=/home/<YOUR_USERNAME>

# Navigate to the extracted folder (created by the update script/initial run)
cd /opt/lmstudio/squashfs-root || exit 1

# Launch with xvfb-run to simulate a display, and use --headless for server mode.
# The server will listen on port 1234 by default.
exec xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
    ./lm-studio --no-sandbox --headless
