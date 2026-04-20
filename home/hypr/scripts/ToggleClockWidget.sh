#!/bin/bash

# Toggle ALL AGS Desktop Widgets visibility with Meta+T

# Check if AGS is running
if pgrep -f "gjs.*ags" > /dev/null 2>&1; then
    # AGS is running, toggle ALL desktop widgets
    ags request "toggle:DesktopWidgets" 2>&1
else
    # AGS is not running
    notify-send "AGS" "AGS is not running"
# fi