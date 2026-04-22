#!/usr/bin/env bash
# Hyprlock wallpaper sync script
# Automatically uses current awww wallpaper for lockscreen

HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
CACHE_DIR="$HOME/.cache/hyprlock"
LOG_FILE="$CACHE_DIR/wallpaper_sync.log"

mkdir -p "$CACHE_DIR"

echo "=== Wallpaper sync at $(date) ===" >> "$LOG_FILE"

# Get current wallpaper from awww
WALLPAPER=""
if command -v awww &> /dev/null; then
    # Parse awww query to get current wallpaper
    SWWW_OUTPUT=$(awww query 2>/dev/null | head -1)
    if [[ "$SWWW_OUTPUT" =~ image:\ (.+)$ ]]; then
        WALLPAPER="${BASH_REMATCH[1]}"
        echo "Found wallpaper: $WALLPAPER" >> "$LOG_FILE"
    fi
fi

# Fallback to default if no wallpaper found
if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    WALLPAPER="$HOME/Pictures/wallpapers/favs/swiss-alps-moewalls-com.mp4"
    echo "Using fallback: $WALLPAPER" >> "$LOG_FILE"
fi

# Update hyprlock config with current wallpaper
if [ -f "$HYPRLOCK_CONF" ]; then
    # Create backup
    cp "$HYPRLOCK_CONF" "$CACHE_DIR/hyprlock.conf.bak"
    
    # Update path line in background section
    sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HYPRLOCK_CONF"
    echo "Updated hyprlock config" >> "$LOG_FILE"
fi

# Launch hyprlock
echo "Launching hyprlock..." >> "$LOG_FILE"
exec hyprlock
