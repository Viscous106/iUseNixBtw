#!/bin/env bash

LOG_FILE="$HOME/.cache/swaylock_debug.log"
CACHE_DIR="$HOME/.cache/swaylock_monitors"

mkdir -p "$CACHE_DIR"
echo "=== Swaylock started at $(date) ===" >> "$LOG_FILE"

# Get current wallpapers from swww for each monitor
declare -A MONITOR_WALLPAPERS
SWAYLOCK_IMAGES=()

if command -v swww > /dev/null; then
    while IFS= read -r line; do
        # Parse swww query output: "eDP-1: ... currently displaying: image: /path/to/wallpaper.png"
        if [[ "$line" =~ ^:\ ([^:]+):.*currently\ displaying:\ image:\ (.+)$ ]]; then
            monitor="${BASH_REMATCH[1]}"
            wallpaper="${BASH_REMATCH[2]}"
            MONITOR_WALLPAPERS["$monitor"]="$wallpaper"
            echo "DEBUG: Monitor $monitor -> $wallpaper" >> "$LOG_FILE"
        fi
    done < <(swww query 2>/dev/null)
fi

# Process each monitor and prepare swaylock image arguments
for monitor in "${!MONITOR_WALLPAPERS[@]}"; do
    wallpaper="${MONITOR_WALLPAPERS[$monitor]}"
    
    if [ -f "$wallpaper" ]; then
        case "$wallpaper" in
            *.mp4|*.mkv|*.webm|*.mov)
                # Handle video wallpapers - extract frame
                if command -v ffmpeg > /dev/null; then
                    VIDEO_FRAME="$CACHE_DIR/${monitor}_frame.png"
                    ffmpeg -i "$wallpaper" -vframes 1 "$VIDEO_FRAME" -y &>/dev/null
                    if [ -f "$VIDEO_FRAME" ]; then
                        SWAYLOCK_IMAGES+=("--image" "${monitor}:${VIDEO_FRAME}")
                        echo "DEBUG: Video frame for $monitor: $VIDEO_FRAME" >> "$LOG_FILE"
                    fi
                fi
                ;;
            *)
                # Regular image file
                SWAYLOCK_IMAGES+=("--image" "${monitor}:${wallpaper}")
                echo "DEBUG: Image for $monitor: $wallpaper" >> "$LOG_FILE"
                ;;
        esac
    fi
done

# Fallback if no wallpapers were found
if [ ${#SWAYLOCK_IMAGES[@]} -eq 0 ]; then
    echo "WARNING: No wallpapers found, using screenshot fallback" >> "$LOG_FILE"
    if command -v grim > /dev/null; then
        SCREENSHOT_PATH="$CACHE_DIR/lockscreen.png"
        grim "$SCREENSHOT_PATH"
        if command -v magick > /dev/null; then
            magick "$SCREENSHOT_PATH" -blur 0x8 "$SCREENSHOT_PATH"
        fi
        SWAYLOCK_IMAGES+=("--image" "$SCREENSHOT_PATH")
    fi
fi

# Execute swaylock with per-monitor images
echo "DEBUG: Executing swaylock with: ${SWAYLOCK_IMAGES[*]}" >> "$LOG_FILE"
/usr/bin/swaylock \
    "${SWAYLOCK_IMAGES[@]}" \
    --clock \
    --indicator-radius 160 \
    --indicator-thickness 10 \
    --ring-color 000000 \
    --ring-ver-color 00ff00 \
    --ring-wrong-color ff0000 \
    --key-hl-color 00ffff \
    --text-color 000000 \
    --text-caps-lock-color ff0000 \
    --inside-color 0000005c \
    --separator-color 00000000

# Cleanup
rm -f "$CACHE_DIR"/*.png
echo "DEBUG: Cleaned up cache files" >> "$LOG_FILE"
