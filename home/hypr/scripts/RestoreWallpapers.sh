#!/usr/bin/env bash

# This script restores wallpapers based on the state file

# Exit if swww is not installed
if ! command -v swww &>/dev/null; then
    echo "swww not found, exiting."
    exit 1
fi

# Initialize swww-daemon if not running
if ! pgrep -x "swww-daemon" >/dev/null; then
    swww-daemon --format xrgb &
    sleep 1
fi

STATE_FILE="$HOME/.config/hypr/wallpaper.state"
PID_DIR="$HOME/.cache/hypr"

mkdir -p "$PID_DIR"

if [ ! -f "$STATE_FILE" ]; then
    echo "State file not found, nothing to restore."
    exit 0
fi

source "$STATE_FILE"

# Get a list of connected monitor names
mapfile -t connected_monitors < <(hyprctl -j monitors | jq -r '.[].name')

for monitor in "${connected_monitors[@]}"; do
    sanitized_monitor="${monitor//-/_}"
    type_var="MONITOR_${sanitized_monitor}_TYPE"
    path_var="MONITOR_${sanitized_monitor}_PATH"

    if [ -n "${!type_var}" ] && [ -n "${!path_var}" ]; then
        type="${!type_var}"
        path="${!path_var}"

        if [ "$type" == "IMAGE" ]; then
            echo "Restoring image wallpaper on $monitor: $path"
            swww img -o "$monitor" "$path"
        elif [ "$type" == "VIDEO" ]; then
            echo "Restoring video wallpaper on $monitor: $path"
            if command -v mpvpaper &>/dev/null; then
                pid_file="$PID_DIR/mpvpaper_${monitor}.pid"
                
                # Kill existing instance for this monitor before starting a new one
                if [ -f "$pid_file" ]; then
                    kill "$(cat "$pid_file")" 2>/dev/null
                fi

                mpvpaper -o "no-audio --loop" "$monitor" "$path" &
                echo $! > "$pid_file"
            else
                echo "mpvpaper not found, skipping video wallpaper."
            fi
        fi
    fi
done

"$HOME/.config/hypr/scripts/Refresh.sh"
