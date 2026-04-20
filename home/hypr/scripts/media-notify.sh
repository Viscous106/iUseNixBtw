#!/bin/bash

# Define the action to take
ACTION="$1"

# Execute the playerctl command
case "$ACTION" in
    "play-pause")
        playerctl play-pause
        ;;
    "next")
        playerctl next
        ;;
    "previous")
        playerctl previous
        ;;
    *)
        exit 1
        ;;
esac

# Allow some time for playerctl to update the status
sleep 0.1

# Get player status and metadata
STATUS=$(playerctl status 2> /dev/null)
if [ "$STATUS" = "Playing" ]; then
    ICON="▶"
    URGENCY="low"
    INFO=$(playerctl metadata --format "{{ title }}\nby {{ artist }}")
elif [ "$STATUS" = "Paused" ]; then
    ICON="⏸"
    URGENCY="low"
    INFO=$(playerctl metadata --format "{{ title }}\nby {{ artist }}")
else
    # No player is active, so don't send a notification
    exit 0
fi

# Send the notification
notify-send -u "$URGENCY" "$ICON $STATUS" "$INFO" -t 3000
