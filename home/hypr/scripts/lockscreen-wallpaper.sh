#!/usr/bin/env bash
# Lockscreen video wallpaper manager
# Easily change lockscreen video or sync with desktop

HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
WALLPAPER_DIR="$HOME/Pictures/wallpapers/favs"

show_usage() {
    cat << EOF
Hyprlock Wallpaper Manager

Usage: $(basename "$0") [OPTION] [FILE]

Options:
    set FILE        Set specific video/image as lockscreen wallpaper
    sync            Sync lockscreen wallpaper with current desktop wallpaper
    random          Set random video from wallpaper directory
    list            List available videos
    current         Show current lockscreen wallpaper
    test            Test lockscreen immediately
    help            Show this help message

Examples:
    $(basename "$0") set ~/Pictures/video.mp4
    $(basename "$0") sync
    $(basename "$0") random
    $(basename "$0") test
EOF
}

set_wallpaper() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        exit 1
    fi
    
    echo "Setting lockscreen wallpaper to: $file"
    sed -i "s|^    path = .*|    path = $file|" "$HYPRLOCK_CONF"
    echo "✓ Lockscreen wallpaper updated"
}

sync_wallpaper() {
    if ! command -v awww &> /dev/null; then
        echo "Error: awww not found"
        exit 1
    fi
    
    SWWW_OUTPUT=$(awww query 2>/dev/null | head -1)
    if [[ "$SWWW_OUTPUT" =~ image:\ (.+)$ ]]; then
        WALLPAPER="${BASH_REMATCH[1]}"
        echo "Current desktop wallpaper: $WALLPAPER"
        set_wallpaper "$WALLPAPER"
    else
        echo "Error: Could not detect current wallpaper"
        exit 1
    fi
}

random_wallpaper() {
    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo "Error: Wallpaper directory not found: $WALLPAPER_DIR"
        exit 1
    fi
    
    mapfile -t videos < <(find "$WALLPAPER_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.mov" \) 2>/dev/null)
    
    if [ ${#videos[@]} -eq 0 ]; then
        echo "Error: No videos found in $WALLPAPER_DIR"
        exit 1
    fi
    
    random_video="${videos[$RANDOM % ${#videos[@]}]}"
    echo "Selected random video: $(basename "$random_video")"
    set_wallpaper "$random_video"
}

list_wallpapers() {
    echo "Available videos in $WALLPAPER_DIR:"
    echo ""
    find "$WALLPAPER_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.mov" \) 2>/dev/null | while read -r file; do
        size=$(du -h "$file" | cut -f1)
        echo "  • $(basename "$file") ($size)"
    done
}

show_current() {
    if [ ! -f "$HYPRLOCK_CONF" ]; then
        echo "Error: Hyprlock config not found"
        exit 1
    fi
    
    current=$(grep "^    path = " "$HYPRLOCK_CONF" | head -1 | sed 's/^    path = //')
    echo "Current lockscreen wallpaper: $current"
    
    if [ -f "$current" ]; then
        size=$(du -h "$current" | cut -f1)
        echo "File size: $size"
        if [[ "$current" =~ \.(mp4|mkv|webm|mov)$ ]]; then
            echo "Type: Video 🎬"
        else
            echo "Type: Image 🖼️"
        fi
    fi
}

test_lock() {
    echo "Testing lockscreen (press ESC to cancel)..."
    sleep 1
    hyprlock
}

# Main
case "$1" in
    set)
        if [ -z "$2" ]; then
            echo "Error: No file specified"
            show_usage
            exit 1
        fi
        set_wallpaper "$2"
        ;;
    sync)
        sync_wallpaper
        ;;
    random)
        random_wallpaper
        ;;
    list)
        list_wallpapers
        ;;
    current)
        show_current
        ;;
    test)
        test_lock
        ;;
    help|--help|-h|"")
        show_usage
        ;;
    *)
        echo "Error: Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
