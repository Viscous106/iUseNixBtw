#!/run/current-system/sw/bin/bash
# NixOS: hyprctl lives in the nix profile, not /usr/bin — the old hardcoded
# /usr/bin/hyprctl path doesn't exist here, so `reload` was silently never
# running at all.
hyprctl reload

# NixOS wraps waybar via makeWrapper: the real binary's kernel process name
# (/proc/PID/comm) is ".waybar-wrapped", not "waybar", even though argv[0]
# is still "waybar". `killall waybar` / `pkill -x waybar` match against the
# comm name, so they silently matched nothing — the old instance never
# actually died, and the `waybar &` below just added a second bar on top of
# it. Match on the full command line instead, and wait for it to actually
# exit before relaunching.
pkill -f '^waybar$' 2>/dev/null || true
for _ in $(seq 1 20); do
    pgrep -f '^waybar$' >/dev/null || break
    sleep 0.1
done
pkill -9 -f '^waybar$' 2>/dev/null || true

waybar &
