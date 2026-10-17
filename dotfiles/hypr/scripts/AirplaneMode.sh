#!/run/current-system/sw/bin/bash
# Toggle all wifi radios via rfkill.

notif="$HOME/.config/hypr/icons/ja.png"

wifi_blocked=$(rfkill list wifi | grep -o "Soft blocked: yes")

if [ -n "$wifi_blocked" ]; then
    rfkill unblock wifi
    notify-send -u low -i "$notif" " Airplane" " mode: OFF"
else
    rfkill block wifi
    notify-send -u low -i "$notif" " Airplane" " mode: ON"
fi
