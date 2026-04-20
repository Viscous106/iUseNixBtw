#!/usr/bin/env bash
# Toggle lockscreen idle on/off

HYPRIDLE_CONF="$HOME/.config/hypr/configs/hypridle.conf"
STATE_FILE="$HOME/.cache/hypr-screensaver/lockscreen_idle_state"

mkdir -p "$(dirname "$STATE_FILE")"

# Check current state
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "disabled" ]; then
    # Enable lockscreen
    sed -i 's/^#LOCKSCREEN_DISABLED# //' "$HYPRIDLE_CONF"
    echo "enabled" > "$STATE_FILE"
    notify-send "🔒 Lockscreen Idle" "Enabled - locks after 3 min" -t 2000
else
    # Disable lockscreen
    sed -i '/^listener {$/,/^}$/ { /timeout = 180/,/^}$/ s/^/#LOCKSCREEN_DISABLED# / }' "$HYPRIDLE_CONF"
    echo "disabled" > "$STATE_FILE"
    notify-send "🔓 Lockscreen Idle" "Disabled - won't auto-lock" -t 2000
fi

# Restart hypridle
HYPRIDLE_PID=$(pgrep -f "hypridle.*configs/hypridle.conf")
if [ -n "$HYPRIDLE_PID" ]; then
    kill "$HYPRIDLE_PID"
    sleep 0.5
    hypridle -c "$HYPRIDLE_CONF" &> ~/.cache/hypridle.log &
fi
