#!/usr/bin/env bash

BUTTON=${1:-left} # Default to left click if no argument is provided
STATE_FILE="/tmp/wl-kbptr-button"

# Check if wl-kbptr is running by checking for its process ID
if pgrep -x "wl-kbptr" > /dev/null
then
    # If it is running, get the last used button
    LAST_BUTTON=$(cat "$STATE_FILE" 2>/dev/null)
    
    # Kill all instances
    pkill -x "wl-kbptr"
    
    # If the requested button is different from the last one, restart with the new button
    if [ "$LAST_BUTTON" != "$BUTTON" ]; then
        echo "$BUTTON" > "$STATE_FILE"
        wl-kbptr -o modes=tile,bisect,click -o mode_click.button="$BUTTON"
    else
        # If it's the same button, we just leave it killed (toggle off)
        rm -f "$STATE_FILE"
    fi
else
    # If it is not running, start it with the specified button and save state
    echo "$BUTTON" > "$STATE_FILE"
    wl-kbptr -o modes=tile,bisect,click -o mode_click.button="$BUTTON"
fi
