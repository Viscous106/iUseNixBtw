# 1. Kill any leftovers
killall wayvnc 2>/dev/null
hyprctl output remove temp_monitor 2>/dev/null

# 2. Create the monitor and WAIT (Crucial step)
hyprctl output create headless temp_monitor
echo "Waiting for monitor to initialize..."
sleep 2

# 3. Force resolution
hyprctl keyword monitor "temp_monitor,1920x1080@60,auto-right,1"

# 4. Start VNC
adb reverse tcp:5900 tcp:5900
wayvnc 0.0.0.0 5900 --output=temp_monitor --disable-input=false --render-cursor
