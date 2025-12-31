#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess
import configparser
from pathlib import Path

# --- Configuration ---

def read_config(config_path):
    """Reads the launcher configuration file."""
    if not config_path.is_file():
        print(f"Error: Configuration file not found at '{config_path}'")
        sys.exit(1)
    
    # Use a simple custom parser to avoid configparser's section requirement
    config = {}
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key.strip()] = value.strip().strip('"')
    return config

# --- Systemd Service Management ---

def handle_service_conflict(service_name):
    """
    Checks if the systemd service is active and stops it if necessary.
    Returns True if the service was running, False otherwise.
    """
    try:
        # Check if service is active
        is_active_cmd = ['systemctl', 'is-active', '--quiet', service_name]
        service_active = subprocess.run(is_active_cmd).returncode == 0

        if not service_active:
            return False

        print(f"The systemd service '{service_name}' is currently active.")
        
        # Prompt only if in an interactive terminal
        if sys.stdout.isatty():
            response = input("Stop it to continue with manual launch? (y/n) ").lower()
            if response != 'y':
                print(f"Exiting. The '{service_name}' is still running.")
                sys.exit(0)

        print(f"Stopping '{service_name}'...")
        stop_cmd = ['sudo', 'systemctl', 'stop', service_name]
        result = subprocess.run(stop_cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"Error: Failed to stop '{service_name}'. You may need sudo privileges.", file=sys.stderr)
            print(f"Stderr: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        
        print("Service stopped successfully.\n")
        return True

    except Exception as e:
        print(f"An error occurred while checking systemd service: {e}", file=sys.stderr)
        return False

def restart_service_if_stopped(service_name, was_running):
    """Restarts the systemd service if it was previously stopped."""
    if not was_running:
        print("Exiting.")
        return

    print("\nAll LM Studio windows closed.")
    print(f"Restarting the '{service_name}' service...")
    try:
        start_cmd = ['sudo', 'systemctl', 'start', service_name]
        result = subprocess.run(start_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error: Failed to restart '{service_name}'. Please check system logs.", file=sys.stderr)
            print(f"Stderr: {result.stderr}", file=sys.stderr)
        else:
            print("Service restarted successfully.")
    except Exception as e:
        print(f"An error occurred while restarting systemd service: {e}", file=sys.stderr)

# --- Launch Logic ---

def launch_instance(config, port, home_dir=None, headless=False):
    """Launches a single instance of LM Studio."""
    app_path = config.get('APPIMAGE_PATH')
    if not app_path or not Path(app_path).is_file():
        print(f"Error: LM Studio AppImage not found at '{app_path}'", file=sys.stderr)
        return None

    command = []
    env = os.environ.copy()

    if headless:
        if subprocess.run(['which', 'xvfb-run'], capture_output=True).returncode != 0:
            print("Error: 'xvfb-run' is not installed. Cannot launch in headless mode.", file=sys.stderr)
            return None
        command.extend(['xvfb-run', '--auto-servernum', '-d'])
    
    command.extend([app_path, '--port', str(port)])
    if headless:
        command.append('--headless')

    if home_dir:
        home_path = Path(home_dir).expanduser()
        home_path.mkdir(parents=True, exist_ok=True)
        env['HOME'] = str(home_path)
        instance_type = "Isolated"
    else:
        instance_type = "Primary"

    mode = "Headless" if headless else "GUI"
    print(f"Launching {instance_type} {mode} instance on port {port}...")
    
    try:
        process = subprocess.Popen(command, env=env)
        return process
    except Exception as e:
        print(f"Failed to launch instance on port {port}: {e}", file=sys.stderr)
        return None

# --- Main ---

def main():
    # --- Get base paths ---
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    
    # --- Read Config ---
    config = read_config(script_dir / 'lms-launcher.conf')

    # --- Argument Parsing ---
    parser = argparse.ArgumentParser(description="Launcher for LM Studio.")
    subparsers = parser.add_subparsers(dest='command', required=True, help='Available commands')
    
    launch_parser = subparsers.add_parser('launch', help='Launch one or more instances.')
    launch_parser.add_argument('instance', choices=['primary', 'secondary', 'dual'], help='Which instance(s) to launch.')
    launch_parser.add_argument('mode', choices=['gui', 'headless'], help='Launch in GUI or headless mode.')

    args = parser.parse_args()

    # --- Execute Command ---
    if args.command == 'launch':
        service_name = 'lmstudio.service'
        was_running = handle_service_conflict(service_name)
        
        processes = []
        
        primary_port = config.get('PRIMARY_PORT', 1234)
        secondary_port = config.get('SECONDARY_PORT', 1235)
        secondary_home = config.get('SECONDARY_HOME_NAME', 'lms-secondary-home')
        
        is_headless = (args.mode == 'headless')
        
        # Launch Primary
        if args.instance in ['primary', 'dual']:
            proc = launch_instance(config, primary_port, headless=is_headless)
            if proc:
                processes.append(proc)
        
        # Launch Secondary
        if args.instance in ['secondary', 'dual']:
            home_dir = Path.home() / secondary_home
            proc = launch_instance(config, secondary_port, home_dir=home_dir, headless=is_headless)
            if proc:
                processes.append(proc)
            print("---\nIMPORTANT: In the 'Secondary' window, set the 'Models Folder' to:\n"
                  f"{config.get('DEFAULT_MODEL_PATH', '~/.cache/lm-studio/models')}\n---")

        # Wait for processes to finish
        if processes:
            print("\nLauncher is running. Waiting for all LM Studio instances to be closed...")
            print("Press Ctrl+C in this terminal to close all instances.")
            try:
                for p in processes:
                    p.wait()
            except KeyboardInterrupt:
                print("\nCtrl+C detected. Terminating all instances...")
                for p in processes:
                    p.terminate()
        
        # Restart service if it was stopped
        restart_service_if_stopped(service_name, was_running)

if __name__ == '__main__':
    main()
