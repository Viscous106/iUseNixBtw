#!/usr/bin/env bash
# Screensaver - displays video fullscreen (no password needed)
# Press ANY KEY or MOVE MOUSE to exit
# Continues playing even if lockscreen appears

CACHE_DIR="$HOME/.cache/hypr-screensaver"
LOG_FILE="$CACHE_DIR/screensaver.log"
INPUT_CONF="$CACHE_DIR/mpv-input.conf"
MPV_PID_FILE="$CACHE_DIR/mpv.pid"

mkdir -p "$CACHE_DIR"
echo "=== Screensaver started at $(date) ===" >> "$LOG_FILE"

# Cleanup function
cleanup() {
    echo "Cleaning up screensaver..." >> "$LOG_FILE"
    if [ -f "$MPV_PID_FILE" ]; then
        MPV_PID=$(cat "$MPV_PID_FILE")
        if kill -0 "$MPV_PID" 2>/dev/null; then
            kill "$MPV_PID" 2>/dev/null
        fi
        rm -f "$MPV_PID_FILE"
    fi
}

trap cleanup EXIT INT TERM

# Get current wallpaper or use default
WALLPAPER=""
if command -v swww &> /dev/null; then
    SWWW_OUTPUT=$(swww query 2>/dev/null | head -1)
    if [[ "$SWWW_OUTPUT" =~ image:\ (.+)$ ]]; then
        WALLPAPER="${BASH_REMATCH[1]}"
    fi
fi

# Fallback to a video from collection
if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    WALLPAPER=$(find ~/Pictures/wallpapers/favs -type f \( -name "*.mp4" -o -name "*.webm" \) 2>/dev/null | shuf -n1)
fi

# If wallpaper is not a video, find a random video
if [[ ! "$WALLPAPER" =~ \.(mp4|mkv|webm|mov)$ ]]; then
    WALLPAPER=$(find ~/Pictures/wallpapers/favs -type f \( -name "*.mp4" -o -name "*.webm" \) 2>/dev/null | shuf -n1)
fi

echo "Playing: $WALLPAPER" >> "$LOG_FILE"

if [ ! -f "$WALLPAPER" ]; then
    echo "ERROR: No video found" >> "$LOG_FILE"
    exit 1
fi

# Get initial mouse position
INITIAL_MOUSE_POS=$(hyprctl cursorpos 2>/dev/null | tr -d ',' | tr -d ' ')
echo "Initial mouse position: $INITIAL_MOUSE_POS" >> "$LOG_FILE"

# Start MPV in fullscreen on top - covering everything
mpv \
    --fullscreen \
    --loop=inf \
    --no-audio \
    --no-osc \
    --no-osd-bar \
    --no-border \
    --keep-open=no \
    --ontop \
    --geometry=0:0 \
    --autofit=100%x100% \
    --cursor-autohide=always \
    --input-conf="$INPUT_CONF" \
    "$WALLPAPER" \
    &>> "$LOG_FILE" &

MPV_PID=$!
echo "MPV started with PID: $MPV_PID" >> "$LOG_FILE"
echo $MPV_PID > "$MPV_PID_FILE"

# Monitor for mouse movement and manual exit
# Don't exit when lockscreen appears - only on user input
while kill -0 "$MPV_PID" 2>/dev/null; do
    CURRENT_MOUSE_POS=$(hyprctl cursorpos 2>/dev/null | tr -d ',' | tr -d ' ')
    
    # Only exit on mouse movement if lockscreen is NOT active
    if ! pidof hyprlock > /dev/null; then
        if [ "$CURRENT_MOUSE_POS" != "$INITIAL_MOUSE_POS" ]; then
            echo "Mouse moved! Exit screensaver. Initial: $INITIAL_MOUSE_POS, Current: $CURRENT_MOUSE_POS" >> "$LOG_FILE"
            kill "$MPV_PID" 2>/dev/null
            break
        fi
    fi
    
    sleep 0.1
done

echo "Screensaver dismissed at $(date)" >> "$LOG_FILE"
cleanup



