#!/bin/bash
# Launches both Primary and Secondary LM Studio instances in Headless mode.
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lms-launcher.sh"

_stop_service_if_active
_launch_primary_headless
sleep 1
_launch_secondary_headless
_wait_for_launched_pids
_restart_service_if_stopped

exit 0
