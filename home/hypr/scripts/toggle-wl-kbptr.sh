#!/bin/bash

BUTTON=${1:-left} # Default to left click if no argument is provided

# Check if wl-kbptr is running by checking for its process ID
if pgrep -x "wl-kbptr" > /dev/null
then
    # If it is running, kill all instances
    pkill -x "wl-kbptr"
else
    # If it is not running, start it with the specified button
    wl-kbptr -o modes=tile,bisect,click -o mode_click.button="$BUTTON"
fi