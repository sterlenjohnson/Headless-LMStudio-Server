#!/bin/bash

# ==============================================================================
#
# LM Studio Launcher - Function Library
#
# This script is NOT meant to be executed directly. It is a library of
# functions to be sourced by other wrapper scripts.
#
# ==============================================================================


# --- Load Configuration ---
# This sources the config file from the same directory as the library.
CONFIG_PATH="$(dirname "$0")/lms-launcher.conf"
if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
else
    echo "Error: Configuration file not found at '$CONFIG_PATH'!"
    exit 1
fi


# --- State Variables ---
# These are used by the functions to track state.
_SERVICE_NAME="lmstudio.service"
_WAS_RUNNING=0
_LAUNCHED_PIDS=()
_SECONDARY_HOME_FULL_PATH="$HOME/$SECONDARY_HOME_NAME"


# --- Function Definitions ---

# _check_dependencies: Ensures AppImage and xvfb-run (for headless) exist.
function _check_dependencies() {
    if [ ! -f "$APPIMAGE_PATH" ]; then
        echo "Error: LM Studio AppImage not found at '$APPIMAGE_PATH'"
        echo "Please check the APPIMAGE_PATH in '$CONFIG_PATH'."
        exit 1
    fi

    if ! command -v xvfb-run &> /dev/null; then
        echo "Warning: 'xvfb-run' is not installed. Headless mode will not be available."
        return 1
    fi
    return 0
}

# _stop_service_if_active: Checks for the main systemd service and stops it.
function _stop_service_if_active() {
    if systemctl is-active --quiet "$_SERVICE_NAME"; then
        echo "The systemd service '$_SERVICE_NAME' is currently active."
        # Interactively ask for permission only if we are in a terminal
        if [ -t 1 ]; then
            read -p "Stop it to continue with manual launch? (y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Exiting. The '$_SERVICE_NAME' is still running."
                exit 0
            fi
        fi

        echo "Stopping '$_SERVICE_NAME'..."
        if sudo systemctl stop "$_SERVICE_NAME"; then
            echo "Service stopped successfully."
            _WAS_RUNNING=1
        else
            echo "Failed to stop '$_SERVICE_NAME'. You may need sudo privileges."
            echo "Exiting to prevent conflicts."
            exit 1
        fi
    else
        _WAS_RUNNING=0
    fi
    echo ""
}

# _launch_primary_gui: Launches the primary instance in GUI mode.
function _launch_primary_gui() {
    echo "Launching Primary GUI instance on port $PRIMARY_PORT..."
    "$APPIMAGE_PATH" --port "$PRIMARY_PORT" &
    _LAUNCHED_PIDS+=($!)
}

# _launch_secondary_gui: Launches the isolated secondary instance in GUI mode.
function _launch_secondary_gui() {
    echo "Launching Secondary GUI instance (Isolated) on port $SECONDARY_PORT..."
    mkdir -p "$_SECONDARY_HOME_FULL_PATH"
    env HOME="$_SECONDARY_HOME_FULL_PATH" "$APPIMAGE_PATH" --port "$SECONDARY_PORT" &
    _LAUNCHED_PIDS+=($!)
    echo "---"
    echo "IMPORTANT: In the 'Secondary' window, set the 'Models Folder' to:"
    echo "$DEFAULT_MODEL_PATH"
    echo "---"
}

# _launch_primary_headless: Launches the primary instance in headless mode.
function _launch_primary_headless() {
    _check_dependencies || return 1
    echo "Launching Primary Headless instance on port $PRIMARY_PORT..."
    xvfb-run --auto-servernum -d "$APPIMAGE_PATH" --headless --port "$PRIMARY_PORT" &
     _LAUNCHED_PIDS+=($!)
}

# _launch_secondary_headless: Launches the isolated secondary instance in headless mode.
function _launch_secondary_headless() {
    _check_dependencies || return 1
    echo "Launching Secondary Headless instance (Isolated) on port $SECONDARY_PORT..."
    mkdir -p "$_SECONDARY_HOME_FULL_PATH"
    env HOME="$_SECONDARY_HOME_FULL_PATH" xvfb-run --auto-servernum -d "$APPIMAGE_PATH" --headless --port "$SECONDARY_PORT" &
    _LAUNCHED_PIDS+=($!)
}

# _wait_for_launched_pids: Waits for all launched processes to exit.
function _wait_for_launched_pids() {
    if [ ${#_LAUNCHED_PIDS[@]} -gt 0 ]; then
        echo ""
        echo "Launcher is running. Waiting for all LM Studio windows to be closed..."
        echo "Press Ctrl+C in this terminal to close all instances."
        wait "${_LAUNCHED_PIDS[@]}"
    fi
}

# _restart_service_if_stopped: Restarts the main systemd service if it was stopped earlier.
function _restart_service_if_stopped() {
    echo ""
    if [ "$_WAS_RUNNING" -eq 1 ]; then
        echo "All LM Studio windows closed."
        echo "Restarting the '$_SERVICE_NAME' service..."
        if sudo systemctl start "$_SERVICE_NAME"; then
            echo "Service restarted successfully."
        else
            echo "Failed to restart '$_SERVICE_NAME'. Please check system logs."
        fi
    else
        echo "Exiting."
    fi
}
