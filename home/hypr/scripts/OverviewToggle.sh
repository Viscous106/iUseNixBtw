#!/usr/bin/env bash
# Ensures Quickshell is running and toggles its overview.

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
set -euo pipefail

# Log file for debugging
LOG_FILE="/tmp/quickshell_toggle_debug.log"
echo "$(date): Attempting Quickshell toggle via Hyprland binding" >> "$LOG_FILE"

# Check if qs is running
if ! pgrep -x qs >/dev/null 2>&1; then
  echo "$(date): Quickshell not running, attempting to start..." >> "$LOG_FILE"
  if command -v qs >/dev/null 2>&1; then
    qs -c overview >/dev/null 2>&1 &
    # Give Quickshell time to initialize before sending IPC
    sleep 1 # Increased sleep duration for robustness
    echo "$(date): Quickshell started, waiting 1s." >> "$LOG_FILE"
  else
    echo "$(date): ERROR: Quickshell CLI (qs) not found." >> "$LOG_FILE"
    notify-send "Quickshell Error" "Quickshell CLI (qs) not found." -u critical 2>/dev/null || true
    exit 1
  fi
fi

# Now attempt to toggle overview via IPC
if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
  echo "$(date): Quickshell overview toggled successfully." >> "$LOG_FILE"
  exit 0
else
  echo "$(date): ERROR: Failed to toggle Quickshell overview via IPC." >> "$LOG_FILE"
  notify-send "Quickshell Error" "Failed to toggle Quickshell overview via IPC." -u critical 2>/dev/null || true
  exit 1
fi