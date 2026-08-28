#!/run/current-system/sw/bin/bash
/usr/bin/hyprctl reload
killall waybar
waybar &
