#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Rofi menu for KooL Hyprland Quick Settings (SUPER SHIFT E)
# Edit entries repointed to the Lua config (lua/*.lua) after the .conf -> Lua migration.

# variables
lua="$HOME/.config/hypr/lua"
configs="$HOME/.config/hypr/configs"
term="kitty"
edit="${EDITOR:-nvim}"

rofi_theme="$HOME/.config/rofi/config-edit.rasi"
msg=' ⁉️ Choose what to do ⁉️'
iDIR="$HOME/.config/swaync/images"
scriptsDir="$HOME/.config/hypr/scripts"

# Function to show info notification
show_info() {
    notify-send -i "$iDIR/info.png" "Info" "$1"
}

# Function to display the menu options without numbers
menu() {
    cat <<EOF
--- EDIT CONFIG (lua) ---
Edit Defaults
Edit Keybinds
Edit ENV variables
Edit Startup Apps
Edit Window Rules
Edit Settings
Edit Decorations
Edit Animations
Edit Monitors
Edit Laptop Settings
--- UTILITIES ---
Choose Kitty Terminal Theme
Configure Monitors (nwg-displays)
Configure Workspace Rules (nwg-displays)
GTK Settings (nwg-look)
QT Apps Settings (qt6ct)
QT Apps Settings (qt5ct)
Choose Rofi Themes
Toggle Game Mode
Switch Dark-Light Theme
EOF
}

# Main function to handle menu selection
main() {
    choice=$(menu | rofi -i -dmenu -config $rofi_theme -mesg "$msg")

    # Map choices to corresponding files
    case "$choice" in
        "Edit Defaults") file="$lua/user_defaults.lua" ;;
        "Edit Keybinds") file="$lua/keybinds.lua" ;;
        "Edit ENV variables") file="$configs/ENVariables.conf" ;;
        "Edit Startup Apps") file="$lua/startup_apps.lua" ;;
        "Edit Window Rules") file="$lua/window_rules.lua" ;;
        "Edit Settings") file="$lua/system_settings.lua" ;;
        "Edit Decorations") file="$lua/decorations.lua" ;;
        "Edit Animations") file="$lua/animations.lua" ;;
        "Edit Monitors") file="$lua/monitors.lua" ;;
        "Edit Laptop Settings") file="$lua/laptops.lua" ;;
        "Choose Kitty Terminal Theme") $scriptsDir/Kitty_themes.sh ;;
        "Configure Monitors (nwg-displays)")
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
        "Configure Workspace Rules (nwg-displays)")
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
        "GTK Settings (nwg-look)")
            if ! command -v nwg-look &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-look first"
                exit 1
            fi
            nwg-look ;;
        "QT Apps Settings (qt6ct)")
            if ! command -v qt6ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt6ct first"
                exit 1
            fi
            qt6ct ;;
        "QT Apps Settings (qt5ct)")
            if ! command -v qt5ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt5ct first"
                exit 1
            fi
            qt5ct ;;
        "Choose Rofi Themes") $scriptsDir/RofiThemeSelector.sh ;;
        "Toggle Game Mode") $scriptsDir/GameMode.sh ;;
        "Switch Dark-Light Theme") $scriptsDir/DarkLight.sh ;;
        *) return ;;  # Do nothing for invalid choices
    esac

    # Open the selected file in the terminal with the text editor
    if [ -n "$file" ]; then
        $term -e $edit "$file"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
