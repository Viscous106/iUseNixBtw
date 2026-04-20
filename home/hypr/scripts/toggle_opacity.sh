#!/bin/bash

echo "$(date): toggle_opacity.sh executed" >> /tmp/toggle_opacity_log.txt

# Define the path for the state file to store the current opacity setting
STATE_FILE="/tmp/hyprland_opacity_state"

# Define the desired opacity values
OPAQUE=1.0
TRANSPARENT=0.3

# Get the address of the currently focused window
# This uses hyprctl clients -j to get a JSON list of all windows,
# then jq to filter for the focused window and extract its address.
ACTIVE_WINDOW_ADDRESS=$(/usr/bin/hyprctl activewindow | /usr/bin/awk '/Window/ {print $2}')

# Check if an active window was found
if [ -z "$ACTIVE_WINDOW_ADDRESS" ]; then
    echo "$(date): No active window found for toggle_opacity.sh" >> /tmp/toggle_opacity_log.txt
    exit 1
fi

# Read the last set opacity from the state file
# If the file doesn't exist, default to opaque.
if [ -f "$STATE_FILE" ]; then
    CURRENT_OPACITY=$(cat "$STATE_FILE")
else
    CURRENT_OPACITY=$OPAQUE
fi

# Determine the new opacity value
if [ "$CURRENT_OPACITY" == "$OPAQUE" ]; then
    NEW_OPACITY=$TRANSPARENT
else
    NEW_OPACITY=$OPAQUE
fi

# Set the new opacity for the active window
# The 'alpha' property is used to control the window's transparency.
/usr/bin/hyprctl setprop address:"$ACTIVE_WINDOW_ADDRESS" alphaoverride 1
/usr/bin/hyprctl setprop address:"$ACTIVE_WINDOW_ADDRESS" alpha "$NEW_OPACITY"

# Save the new opacity state to the file for the next toggle
echo "$NEW_OPACITY" > "$STATE_FILE"

echo "$(date): Toggled opacity for window $ACTIVE_WINDOW_ADDRESS to $NEW_OPACITY" >> /tmp/toggle_opacity_log.txt