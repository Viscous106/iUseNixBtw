#!/run/current-system/sw/bin/bash

# Notify once per discharge (flag file) when any battery drops to THRESHOLD%.
THRESHOLD=15
NOTIFIED_FILE="/tmp/battery_notified"

for i in {0..3}; do
  if [ -f /sys/class/power_supply/BAT$i/capacity ]; then
    battery_status=$(cat /sys/class/power_supply/BAT$i/status)
    battery_capacity=$(cat /sys/class/power_supply/BAT$i/capacity)
    
    if [ "$battery_status" = "Discharging" ] && [ "$battery_capacity" -le "$THRESHOLD" ]; then
      if [ ! -f "$NOTIFIED_FILE" ]; then
        notify-send -u critical "Battery Low" "Battery at ${battery_capacity}%! Please charge your device." -i battery-caution
        touch "$NOTIFIED_FILE"
      fi
    else
      if [ -f "$NOTIFIED_FILE" ] && { [ "$battery_status" = "Charging" ] || [ "$battery_capacity" -gt "$THRESHOLD" ]; }; then
        rm "$NOTIFIED_FILE"
      fi
    fi
  fi
done
