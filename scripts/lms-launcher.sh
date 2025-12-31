#!/bin/bash

# LM Studio Launcher
# ------------------
# A script to manage launching one or two instances of LM Studio,
# in either GUI or headless mode, with persistent settings.

# --- Load Configuration ---
CONFIG_PATH="$(dirname "$0")/lms-launcher.conf"
if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
else
    echo "Error: Configuration file not found at '$CONFIG_PATH'!"
    echo "Please ensure 'lms-launcher.conf' is in the same directory as this script."
    exit 1
fi

# --- Global Variables ---
SERVICE_NAME="lmstudio.service"
WAS_RUNNING=0
SECONDARY_HOME_FULL_PATH="$HOME/$SECONDARY_HOME_NAME"

# --- Function Definitions ---

# Pre-flight check for required executables
check_deps() {
    if ! command -v xvfb-run &> /dev/null; then
        echo "Warning: 'xvfb-run' is not installed."
        echo "Headless mode will not be available. Please install it to enable."
        echo "On Debian/Ubuntu: sudo apt-get install xvfb"
        echo "On Fedora: sudo dnf install xorg-x11-server-Xvfb"
        XVFB_AVAILABLE=0
    else
        XVFB_AVAILABLE=1
    fi

    if [ ! -f "$APPIMAGE_PATH" ]; then
        echo "Error: LM Studio AppImage not found at '$APPIMAGE_PATH'"
        echo "Please check the APPIMAGE_PATH in '$CONFIG_PATH'."
        exit 1
    fi
}

# Stop the systemd service if it's running to prevent conflicts
handle_service_conflict() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "The systemd service '$SERVICE_NAME' is currently active."
        read -p "Stop it to continue with manual launch? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Stopping '$SERVICE_NAME'..."
            if sudo systemctl stop "$SERVICE_NAME"; then
                echo "Service stopped successfully."
                WAS_RUNNING=1
            else
                echo "Failed to stop '$SERVICE_NAME'. You may need sudo privileges."
                echo "Exiting to prevent conflicts."
                exit 1
            fi
        else
            echo "Exiting. The '$SERVICE_NAME' is still running."
            exit 0
        fi
        echo ""
    fi
}

# launch_gui(port, home_dir)
launch_gui() {
    local port=$1
    local home_dir=$2

    echo "Launching GUI instance on port $port..."
    if [ -n "$home_dir" ]; then
        mkdir -p "$home_dir"
        env HOME="$home_dir" "$APPIMAGE_PATH" --port "$port" &
    else
        "$APPIMAGE_PATH" --port "$port" &
    fi
}

# launch_headless(port, home_dir)
launch_headless() {
    if [ "$XVFB_AVAILABLE" -eq 0 ]; then
        echo "Cannot launch in headless mode: xvfb-run is not available."
        return 1
    fi

    local port=$1
    local home_dir=$2
    
    echo "Launching headless instance on port $port..."
    if [ -n "$home_dir" ]; then
        mkdir -p "$home_dir"
        env HOME="$home_dir" xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' "$APPIMAGE_PATH" --headless --port "$port" &
    else
        xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' "$APPIMAGE_PATH" --headless --port "$port" &
    fi
}

show_instructions() {
    echo ""
    echo "---"
    echo "IMPORTANT: For any ISOLATED (Secondary) instance, you must configure the model folder:"
    echo "1. In the new LM Studio window, go to Settings > General."
    echo "2. Change 'Models Folder' to: $DEFAULT_MODEL_PATH"
    echo "---"
    echo ""
}

# --- Main Menu ---
main_menu() {
    echo "========================================"
    echo "        LM Studio Launcher"
    echo "========================================"
    echo "  Single Instance"
    echo "    1) Launch Primary Instance (GUI)"
    echo "    2) Launch Secondary Instance (GUI, Isolated)"
    if [ "$XVFB_AVAILABLE" -eq 1 ]; then
        echo "    3) Launch Primary Instance (Headless)"
        echo "    4) Launch Secondary Instance (Headless, Isolated)"
    fi
    echo ""
    echo "  Dual Instances"
    echo "    5) Launch Dual Instances (GUI)"
    if [ "$XVFB_AVAILABLE" -eq 1 ]; then
        echo "    6) Launch Dual Instances (Headless)"
    fi
    echo ""
    echo "  q) Quit"
    echo "----------------------------------------"
    read -p "Enter your choice: " choice
    echo ""

    case $choice in
        1)
            launch_gui "$PRIMARY_PORT"
            ;;
        2)
            launch_gui "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
            show_instructions
            ;;
        3)
            [ "$XVFB_AVAILABLE" -eq 1 ] && launch_headless "$PRIMARY_PORT" || echo "Invalid choice."
            ;;
        4)
            [ "$XVFB_AVAILABLE" -eq 1 ] && {
                launch_headless "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
                show_instructions
            } || echo "Invalid choice."
            ;;
        5)
            echo "--- Launching Dual GUI Instances ---"
            launch_gui "$PRIMARY_PORT"
            sleep 1
            launch_gui "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
            show_instructions
            ;;
        6)
            if [ "$XVFB_AVAILABLE" -eq 1 ]; then
                echo "--- Launching Dual Headless Instances ---"
                launch_headless "$PRIMARY_PORT"
                sleep 1
                launch_headless "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
                show_instructions
            else
                echo "Invalid choice."
            fi
            ;;
        q|Q)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
    echo "Launch command issued. Instances are running in the background."
    echo ""
}

# --- Script Start ---
check_deps
handle_service_conflict

# If a command-line argument is provided, execute it directly. Otherwise, show the menu.
if [ -n "$1" ]; then
    case "$1" in
        --primary-gui)
            launch_gui "$PRIMARY_PORT"
            ;;
        --secondary-gui)
            launch_gui "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
            show_instructions
            ;;
        --primary-headless)
            [ "$XVFB_AVAILABLE" -eq 1 ] && launch_headless "$PRIMARY_PORT" || echo "Headless mode not available."
            ;;
        --secondary-headless)
            [ "$XVFB_AVAILABLE" -eq 1 ] && {
                launch_headless "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
                show_instructions
            } || echo "Headless mode not available."
            ;;
        --dual-gui)
            echo "--- Launching Dual GUI Instances ---"
            launch_gui "$PRIMARY_PORT"
            sleep 1
            launch_gui "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
            show_instructions
            ;;
        --dual-headless)
            if [ "$XVFB_AVAILABLE" -eq 1 ]; then
                echo "--- Launching Dual Headless Instances ---"
                launch_headless "$PRIMARY_PORT"
                sleep 1
                launch_headless "$SECONDARY_PORT" "$SECONDARY_HOME_FULL_PATH"
                show_instructions
            else
                echo "Headless mode not available."
            fi
            ;;
        *)
            echo "Invalid argument: $1"
            echo "Running in interactive mode instead..."
            main_menu
            ;;
    esac
    echo "Launch command issued. Instances are running in the background."
    echo ""
else
    main_menu
fi


if [ "$WAS_RUNNING" -eq 1 ]; then
    echo "------------------------------------------------------------------"
    echo "The '$SERVICE_NAME' service was stopped by this script."
    echo "To restart it when you are finished, run:"
    echo "  sudo systemctl start $SERVICE_NAME"
    echo "------------------------------------------------------------------"
fi

exit 0