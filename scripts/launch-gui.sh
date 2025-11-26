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

# Check if the headless service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping headless service ($SERVICE_NAME)..."
    # This will trigger a PolicyKit authentication prompt if needed
    if ! sudo systemctl stop "$SERVICE_NAME"; then
        echo "Failed to stop service. You may need sudo privileges."
        read -p "Press Enter to exit..."
        exit 1
    fi
    WAS_RUNNING=1
else
    echo "Service is not running. Proceeding..."
    WAS_RUNNING=0
fi

# Launch the LM Studio GUI
echo "Launching LM Studio GUI..."
if ! "$APPIMAGE_PATH"; then
    echo "Failed to launch LM Studio GUI."
    if [ "$WAS_RUNNING" -eq 1 ]; then
        echo "Attempting to restart headless service..."
        sudo systemctl start "$SERVICE_NAME"
    fi
    read -p "Press Enter to exit..."
    exit 1
fi

# Wait for the GUI process to finish
GUI_PID=$!
wait "$GUI_PID"
EXIT_CODE=$?

if [ "$WAS_RUNNING" -eq 1 ]; then
    echo "GUI closed. Restarting headless service..."
    if ! sudo systemctl start "$SERVICE_NAME"; then
        echo "Failed to restart service. Please check the logs for details."
        read -p "Press Enter to exit..."
        exit 1
    else
        echo "Service restarted successfully."
    fi
else
    echo "No need to restart the headless service as it was not running initially."
fi

echo "Exiting..."
exit $EXIT_CODE
