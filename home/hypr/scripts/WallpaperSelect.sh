#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# This script for selecting wallpapers (SUPER W)

# WALLPAPERS PATH
terminal=kitty
wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/configs/wallpaper_effects/.wallpaper_current"

# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

# awww transition config
FPS=60
TYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

# Check if package bc exists
if ! command -v bc &>/dev/null;
  then
  notify-send -i "$iDIR/error.png" "bc missing" "Install package bc first"
  exit 1
fi

# Variables
rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Ensure focused_monitor is detected
if [[ -z "$focused_monitor" ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Could not detect focused monitor"
  exit 1
fi

# Monitor details
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Kill existing wallpaper daemons for video
kill_wallpaper_for_video() {
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

# Kill existing wallpaper daemons for image
kill_wallpaper_for_image() {
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

# Rofi command
rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

# Function to browse wallpapers
browse_wallpapers() {
    local current_dir="$1"
    local random_pic_for_preview="$2"

    # Add a ".." entry to go up, except for the root directory
    if [ "$current_dir" != "$wallDIR" ]; then
        printf "..\x00icon\x1f%s\n" "$iDIRi/back.png"
    fi

    # Add "Random" option with a preview
    if [ -n "$random_pic_for_preview" ]; then
        printf "Random\x00icon\x1f%s\n" "$random_pic_for_preview"
    else
        printf "Random\x00icon\x1f%s\n" "$iDIRi/random.png"
    fi

    # Add directories with previews
    for dir in "$current_dir"/*/; do
        if [ -d "$dir" ]; then
            dir_name=$(basename "$dir")
            # Find the first image in the directory for a preview
            preview_image=$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print -quit)
            if [ -n "$preview_image" ]; then
                printf "%s/\x00icon\x1f%s\n" "$dir_name" "$preview_image"
            else
                printf "%s/\x00icon\x1f%s\n" "$dir_name" "$iDIRi/folder.png"
            fi
        fi
    done

    # Add files
    for pic_path in "$current_dir"/*;
    do
        if [ -f "$pic_path" ]; then
            pic_name=$(basename "$pic_path")
            # The existing logic for generating thumbnails can be used here
            if [[ "$pic_name" =~ \.gif$ ]]; then
              cache_gif_image="$HOME/.cache/gif_preview/${pic_name}.png"
              if [[ ! -f "$cache_gif_image" ]]; then
                mkdir -p "$HOME/.cache/gif_preview"
                magick "$pic_path[0]" -resize 1920x1080 "$cache_gif_image"
              fi
              printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_gif_image"
            elif [[ "$pic_name" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
              cache_preview_image="$HOME/.cache/video_preview/${pic_name}.png"
              if [[ ! -f "$cache_preview_image" ]]; then
                mkdir -p "$HOME/.cache/video_preview"
                ffmpeg -v error -y -i "$pic_path" -ss 00:00:01.000 -vframes 1 "$cache_preview_image"
              fi
              printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_preview_image"
            else
              printf "%s\x00icon\x1f%s\n" "$pic_name" "$pic_path"
            fi
        fi
    done
}


# Offer SDDM Simple Wallpaper Option (only for non-video wallpapers)
set_sddm_wallpaper() {
  sleep 1

  # Resolve SDDM themes directory (standard and NixOS path)
  local sddm_themes_dir=""
  if [ -d "/usr/share/sddm/themes" ]; then
    sddm_themes_dir="/usr/share/sddm/themes"
  elif [ -d "/run/current-system/sw/share/sddm/themes" ]; then
    sddm_themes_dir="/run/current-system/sw/share/sddm/themes"
  fi

  [ -z "$sddm_themes_dir" ] && return 0

  local sddm_simple="$sddm_themes_dir/simple_sddm_2"

  # Only prompt if theme exists and its Backgrounds directory is writable
  if [ -d "$sddm_simple" ] && [ -w "$sddm_simple/Backgrounds" ]; then

    # Check if yad is running to avoid multiple notifications
    if pidof yad >/dev/null;
      then
      killall yad
    fi

    if yad --info --text="Set current wallpaper as SDDM background?\n\nNOTE: This only applies to SIMPLE SDDM v2 Theme" \
      --text-align=left \
      --title="SDDM Background" \
      --timeout=5 \
      --timeout-indicator=right \
      --button="yes:0" \
      --button="no:1"; then

      # Check if terminal exists
      if ! command -v "$terminal" &>/dev/null;
        then
        notify-send -i "$iDIR/error.png" "Missing $terminal" "Install $terminal to enable setting of wallpaper background"
        exit 1
      fi

      exec "$SCRIPTSDIR/sddm_wallpaper.sh" --normal

    fi
  fi
}

modify_startup_config() {
  # Note: This function needs to be updated to handle per-monitor live wallpapers for persistence.
  # The current implementation only supports one live wallpaper at a time on startup.
  local selected_file="$1"
  local startup_config="$HOME/.config/hypr/configs/Startup_Apps.conf"

  # Check if it's a live wallpaper (video)
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm)$ ]]; then
    # For video wallpapers:
    sed -i '/^\s*exec-once\s*=\s*awww-daemon\s*--format\s*xrgb\s*$/s/^/#/' "$startup_config"
    sed -i '/^\s*#\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^#\s*//;' "$startup_config"

    # Update the livewallpaper variable with the selected video path (using $HOME)
    selected_file="${selected_file/#$HOME/\$HOME}" # Replace /home/user with $HOME
    sed -i "s|^\$livewallpaper=.*|\$livewallpaper=\"$selected_file\"|" "$startup_config"

    echo "Configured for live wallpaper (video)."
  else
    # For image wallpapers:
    sed -i '/^\s*#\s*exec-once\s*=\s*awww-daemon\s*--format\s*xrgb\s*$/s/^\s*#\s*//;' "$startup_config"

    sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/#/' "$startup_config"

    echo "Configured for static wallpaper (image)."
  fi
}

# Apply Image Wallpaper
apply_image_wallpaper() {
  local image_path="$1"
    local monitor="$focused_monitor"
    local pid_file="$HOME/.cache/hypr/mpvpaper_${monitor}.pid"

    # Kill mpvpaper instance on this monitor if it exists
    if [ -f "$pid_file" ]; then
        kill "$(cat "$pid_file")"
        rm "$pid_file"
    fi

  kill_wallpaper_for_image

  mkdir -p "$(dirname "$wallpaper_current")" # Ensure directory exists
  if ! pgrep -x "awww-daemon" >/dev/null;
    then
    echo "Starting awww-daemon..."
    awww-daemon --format xrgb &
  fi

  awww img -o "$focused_monitor" "$image_path" $SWWW_PARAMS
  echo "$image_path" > "$wallpaper_current"

  # Run additional scripts (pass the image path to avoid cache race conditions)
  # "$SCRIPTSDIR/WallustSwww.sh" "$image_path"
  sleep 2
  "$SCRIPTSDIR/Refresh.sh"
  sleep 1

  set_sddm_wallpaper
}

apply_video_wallpaper() {
    local video_path="$1"
    local monitor="$focused_monitor"
    local pid_dir="$HOME/.cache/hypr"
    local pid_file="$pid_dir/mpvpaper_${monitor}.pid"

    # Check if mpvpaper is installed
    if ! command -v mpvpaper &>/dev/null; then
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "mpvpaper not found"
        return 1
    fi

    # Create PID directory if it doesn't exist
    mkdir -p "$pid_dir"

    # Kill existing mpvpaper instance for this monitor
    if [ -f "$pid_file" ]; then
        kill "$(cat "$pid_file")" 2>/dev/null
        rm "$pid_file"
    fi

    # Ensure awww is not controlling the monitor
    awww clear "$monitor" >/dev/null 2>&1

    # Apply video wallpaper using mpvpaper
    mpvpaper -o "no-audio --loop" "$monitor" "$video_path" &
    echo $! > "$pid_file"
}

# Main function
main() {
    local current_dir="$wallDIR"

    # Pre-select a random picture for the "Random" preview
    mapfile -d '' ALL_PICS < <(find -L "${wallDIR}" -type f \( \
      -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
      -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
      -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)
    RANDOM_PIC="${ALL_PICS[$((RANDOM % ${#ALL_PICS[@]}))]}"
    
    while true;
    do
        choice=$(browse_wallpapers "$current_dir" "$RANDOM_PIC" | $rofi_command)
        
        if [[ -z "$choice" ]]; then
            echo "No choice selected. Exiting."
            exit 0
        fi

        # Handle "Random" selection
        if [ "$choice" == "Random" ]; then
            selected_file="$RANDOM_PIC"
            modify_startup_config "$selected_file"
            if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
                apply_video_wallpaper "$selected_file"
            else
                apply_image_wallpaper "$selected_file"
            fi
            break
        fi

        # Handle going up
        if [ "$choice" == ".." ]; then
            current_dir=$(dirname "$current_dir")
            continue
        fi

        # Handle directory selection
        if [[ "$choice" == */ ]]; then
            current_dir="$current_dir/$(basename "$choice")"
            continue
        fi

        # Handle file selection
        selected_file="$current_dir/$choice"
        
        if [[ -f "$selected_file" ]]; then
            modify_startup_config "$selected_file"
            
            if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
                apply_video_wallpaper "$selected_file"
            else
                apply_image_wallpaper "$selected_file"
            fi
            break
        else
            # This is a fallback, should not happen if logic is correct
            # Maybe the basename logic needs adjustment
            selected_file_path=$(find "$current_dir" -iname "$choice.*" -print -quit)
            if [ -n "$selected_file_path" ]; then
                modify_startup_config "$selected_file_path"
                if [[ "$selected_file_path" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
                    apply_video_wallpaper "$selected_file_path"
                else
                    apply_image_wallpaper "$selected_file_path"
                fi
                break
            fi
            notify-send "Error" "Selected item is not a file or directory."
            exit 1
        fi
    done
}

# Check if rofi is already running
if pidof rofi >/dev/null;
  then
  pkill rofi
fi

main
