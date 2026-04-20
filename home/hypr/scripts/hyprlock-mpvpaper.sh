#!/usr/bin/env bash
# Advanced hyprlock launcher with mpvpaper live wallpaper support
# This creates a true live wallpaper effect on the lockscreen

CACHE_DIR="$HOME/.cache/hyprlock"
LOG_FILE="$CACHE_DIR/mpvpaper_lock.log"
PID_FILE="$CACHE_DIR/mpvpaper.pid"

mkdir -p "$CACHE_DIR"
echo "=== Hyprlock with mpvpaper at $(date) ===" >> "$LOG_FILE"

# Function to cleanup mpvpaper on exit
cleanup() {
    echo "Cleaning up mpvpaper..." >> "$LOG_FILE"
    if [ -f "$PID_FILE" ]; then
        MPVPAPER_PID=$(cat "$PID_FILE")
        if kill -0 "$MPVPAPER_PID" 2>/dev/null; then
            kill "$MPVPAPER_PID"
            echo "Killed mpvpaper PID: $MPVPAPER_PID" >> "$LOG_FILE"
        fi
        rm -f "$PID_FILE"
    fi
}

trap cleanup EXIT

# Get current wallpaper from swww
WALLPAPER=""
if command -v swww &> /dev/null; then
    SWWW_OUTPUT=$(swww query 2>/dev/null | head -1)
    if [[ "$SWWW_OUTPUT" =~ image:\ (.+)$ ]]; then
        WALLPAPER="${BASH_REMATCH[1]}"
        echo "Found wallpaper: $WALLPAPER" >> "$LOG_FILE"
    fi
fi

# Check if wallpaper is a video
IS_VIDEO=false
if [[ "$WALLPAPER" =~ \.(mp4|mkv|webm|mov)$ ]]; then
    IS_VIDEO=true
    echo "Detected video wallpaper" >> "$LOG_FILE"
fi

# Launch mpvpaper for video wallpapers on lockscreen layer
if [ "$IS_VIDEO" = true ] && [ -f "$WALLPAPER" ]; then
    echo "Launching mpvpaper with: $WALLPAPER" >> "$LOG_FILE"
    
    # Kill any existing mpvpaper instances on lockscreen layer
    pgrep -f "mpvpaper.*DP-" | while read pid; do
        kill "$pid" 2>/dev/null
    done
    
    # Get all monitors
    MONITORS=$(hyprctl monitors -j | jq -r '.[].name')
    
    # Launch mpvpaper on each monitor with lockscreen layer
    for monitor in $MONITORS; do
        mpvpaper -o "loop" -l "lockscreen" "$monitor" "$WALLPAPER" &>> "$LOG_FILE" &
        MPVPAPER_PID=$!
        echo "$MPVPAPER_PID" >> "$PID_FILE"
        echo "Started mpvpaper on $monitor with PID: $MPVPAPER_PID" >> "$LOG_FILE"
    done
    
    # Give mpvpaper time to start
    sleep 0.5
    
    # Update hyprlock config to use transparent background (mpvpaper shows through)
    HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
    if [ -f "$HYPRLOCK_CONF" ]; then
        # Backup original config
        cp "$HYPRLOCK_CONF" "$CACHE_DIR/hyprlock.conf.backup"
        
        # Set background to transparent/minimal for video passthrough
        sed -i 's|^    path = .*|    path = screenshot|' "$HYPRLOCK_CONF"
        sed -i 's|^    blur_passes = .*|    blur_passes = 3|' "$HYPRLOCK_CONF"
    fi
else
    # For static images, update hyprlock config normally
    HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
    if [ -f "$HYPRLOCK_CONF" ] && [ -n "$WALLPAPER" ]; then
        cp "$HYPRLOCK_CONF" "$CACHE_DIR/hyprlock.conf.backup"
        sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HYPRLOCK_CONF"
    fi
fi

# Launch hyprlock
echo "Launching hyprlock..." >> "$LOG_FILE"
hyprlock

# Cleanup happens via trap EXIT
echo "Hyprlock exited" >> "$LOG_FILE"

# Restore original hyprlock config
if [ -f "$CACHE_DIR/hyprlock.conf.backup" ]; then
    cp "$CACHE_DIR/hyprlock.conf.backup" "$HOME/.config/hypr/hyprlock.conf"
fi
