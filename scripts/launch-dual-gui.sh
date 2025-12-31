#!/bin/bash

# ==============================================================================
#
# LM Studio - Dual GUI Launcher
#
# This script launches both the Primary and the isolated Secondary
# instances of LM Studio in GUI mode.
#
# It sources the main function library to perform the actual work.
#
# ==============================================================================

# Find the directory of this script and source the library
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lms-launcher.sh"

# --- Main Execution ---

# 1. Stop the background service if it's running
_stop_service_if_active

# 2. Launch both GUI instances
_launch_primary_gui
sleep 1 # Stagger the launches slightly
_launch_secondary_gui

# 3. Wait for the user to close the GUI windows
_wait_for_launched_pids

# 4. Restart the background service if it was running before
_restart_service_if_stopped

exit 0
