#!/bin/bash
# Launches the Secondary (Isolated) LM Studio instance in GUI mode.
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lms-launcher.sh"

_stop_service_if_active
_launch_secondary_gui
_wait_for_launched_pids
_restart_service_if_stopped

exit 0
