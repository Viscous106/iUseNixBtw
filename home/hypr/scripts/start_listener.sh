#!/bin/bash
LOG_FILE="$HOME/listener_log.txt"
# Run the python listener in the background, redirecting its output to the log file.
python3 "$HOME/.config/hypr/scripts/hypr_last_app_listener.py" > "$LOG_FILE" 2>&1 &
