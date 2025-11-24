#!/bin/bash
# Wrapper to run LM Studio GUI while temporarily stopping the headless service

SERVICE_NAME="lmstudio.service"
APPIMAGE_PATH="/opt/lmstudio/LM-Studio-latest.AppImage"

# Check if AppImage exists
if [ ! -f "$APPIMAGE_PATH" ]; then
    echo "Error: AppImage not found at $APPIMAGE_PATH"
    echo "Please ensure LM Studio is installed in /opt/lmstudio/"
    read -p "Press Enter to exit..."
    exit 1
fi

echo "Checking headless service status..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping headless service ($SERVICE_NAME)..."
    # This will trigger a PolicyKit authentication prompt if needed
    if ! systemctl stop "$SERVICE_NAME"; then
        echo "Failed to stop service. You may need sudo privileges."
        read -p "Press Enter to exit..."
        exit 1
    fi
    WAS_RUNNING=1
else
    echo "Service is not running. Proceeding..."
    WAS_RUNNING=0
fi

echo "Launching LM Studio GUI..."
"$APPIMAGE_PATH"

# When the GUI closes, we reach here
if [ "$WAS_RUNNING" -eq 1 ]; then
    echo "GUI closed. Restarting headless service..."
    systemctl start "$SERVICE_NAME"
    echo "Service restarted."
    sleep 2
fi
