#!/bin/bash

# 1. Clean slate: Remove the specific monitor if it already exists
# This prevents "Output already exists" errors or ghost monitors
hyprctl output remove temp_monitor 2>/dev/null

# 2. Create the virtual monitor with a specific name "temp_monitor"
echo ">>> Creating virtual monitor 'temp_monitor'..."
hyprctl output create headless temp_monitor

# Wait a split second for Hyprland to register it
sleep 1

# 3. Configure Resolution & Scale
# We force scale 1 so you get real 1080p space, not zoomed in 2x
echo ">>> Setting resolution 1920x1080 and Scale 1.0..."
hyprctl keyword monitor "temp_monitor,1920x1080@60,auto-right,1"

# 4. Setup ADB Reverse Tethering
echo ">>> Setting up USB forwarding..."
adb reverse tcp:5900 tcp:5900

# 5. Start WayVNC attached to 'temp_monitor'
echo ">>> Starting VNC Server on temp_monitor..."
echo ">>> CONNECT NOW on your phone: localhost:5900"
wayvnc 0.0.0.0 5900 --output=temp_monitor --disable-input=false --render-cursor
