#!/run/current-system/sw/bin/bash
hyprctl reload

# Monitor auto-detect runs only here (no event hooks, see lua/monitors.lua).
# Backgrounded: it holds its lock through a settle sleep.
"$HOME/.config/hypr/scripts/MonitorAuto.sh" &

# Restart caelestia (bar + notifications + launcher).
pkill -f 'caelestia-shell' 2>/dev/null || true
for _ in $(seq 1 20); do
    pgrep -f 'caelestia-shell' >/dev/null || break
    sleep 0.1
done
pkill -9 -f 'caelestia-shell' 2>/dev/null || true

caelestia-shell &
