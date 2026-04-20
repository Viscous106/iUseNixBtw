#!/usr/bin/env bash

# Define the cursor options and their corresponding theme folder names
# We use an associative array to map display name to folder name.
declare -A cursor_themes=(
    ["Bibata"]="Bibata-Modern-Ice"
    ["Hollow Knight"]="Hollow-Knight"
)

# Per-theme cursor sizes
declare -A cursor_sizes=(
    ["Bibata"]=32
    ["Hollow Knight"]=48
)

# Create a list of the display names for wofi
options="Bibata\nHollow Knight"

# Use wofi to prompt the user for a selection
selected=$(echo -e "$options" | rofi -dmenu -p "Select Cursor Theme:" -i)

# Exit if no selection was made (user pressed Escape)
if [[ -z "$selected" ]]; then
    exit 0
fi

# Get the folder name based on the selection
theme_folder="${cursor_themes[$selected]}"

# Check if the selection was valid
if [[ -z "$theme_folder" ]]; then
    exit 1
fi

# Cursor size (per-theme)
cursor_size="${cursor_sizes[$selected]}"

# 1. Apply instantly to the running Hyprland session
hyprctl setcursor "$theme_folder" "$cursor_size"

# 2. Set env vars so all newly spawned apps see the correct cursor
#    (works for both Wayland-native and XWayland apps)
hyprctl keyword env "XCURSOR_THEME,$theme_folder"
hyprctl keyword env "XCURSOR_SIZE,$cursor_size"

# 3. Update ~/.icons/default/index.theme for X11/XWayland apps and persistence
mkdir -p "$HOME/.icons/default"
cat <<EOF > "$HOME/.icons/default/index.theme"
[Icon Theme]
Inherits=$theme_folder
EOF

# 4. Persist: update the env line in ENVariables.conf for next login
ENV_FILE="$HOME/.config/hypr/configs/ENVariables.conf"

# Remove old XCURSOR_THEME / XCURSOR_SIZE lines added by this script, then re-add
sed -i '/^# --- cursor-selector ---$/,/^# --- end cursor-selector ---$/d' "$ENV_FILE"

cat <<EOF >> "$ENV_FILE"
# --- cursor-selector ---
env = XCURSOR_THEME,$theme_folder
env = XCURSOR_SIZE,$cursor_size
# --- end cursor-selector ---
EOF

# 5. Notify
notify-send "Cursor Changed" "Theme set to $selected" -t 2000
