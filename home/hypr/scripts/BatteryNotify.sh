#!/usr/bin/env bash

# Battery notification script with 15% threshold
THRESHOLD=15
NOTIFIED_FILE="/tmp/battery_notified"

for i in {0..3}; do
  if [ -f /sys/class/power_supply/BAT$i/capacity ]; then
    battery_status=$(cat /sys/class/power_supply/BAT$i/status)
    battery_capacity=$(cat /sys/class/power_supply/BAT$i/capacity)
    
    # Check if battery is discharging and below threshold
    if [ "$battery_status" = "Discharging" ] && [ "$battery_capacity" -le "$THRESHOLD" ]; then
      # Only notify if we haven't notified yet
      if [ ! -f "$NOTIFIED_FILE" ]; then
        notify-send -u critical "Battery Low" "Battery at ${battery_capacity}%! Please charge your device." -i battery-caution
        touch "$NOTIFIED_FILE"
      fi
    else
      # Remove the notification flag if charging or above threshold
      if [ -f "$NOTIFIED_FILE" ] && { [ "$battery_status" = "Charging" ] || [ "$battery_capacity" -gt "$THRESHOLD" ]; }; then
        rm "$NOTIFIED_FILE"
      fi
    fi
  fi
done
