#!/run/current-system/sw/bin/bash
# NixOS: hyprctl lives in the nix profile, not /usr/bin — the old hardcoded
# /usr/bin/hyprctl path doesn't exist here, so `reload` was silently never
# running at all.
hyprctl reload

# Monitor auto-detect runs ONLY here (SUPER+ALT+R) — no event hooks, see
# lua/monitors.lua. "open"/"closed" would force the lid state; no arg reads the
# ACPI sensor. Backgrounded: it holds its lock through a settle sleep.
"$HOME/.config/hypr/scripts/monitor-auto.sh" &

# Restart the shell. Caelestia is one process for bar + notifications +
# launcher, started from startup_apps.lua, so a refresh is just kill-and-relaunch.
# (The old block here fought waybar's makeWrapper comm name, ".waybar-wrapped",
# which made `killall waybar` silently match nothing and stack a second bar.)
pkill -f 'caelestia-shell' 2>/dev/null || true
for _ in $(seq 1 20); do
    pgrep -f 'caelestia-shell' >/dev/null || break
    sleep 0.1
done
pkill -9 -f 'caelestia-shell' 2>/dev/null || true

caelestia-shell &
