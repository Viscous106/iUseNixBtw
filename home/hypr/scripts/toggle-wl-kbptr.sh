#!/bin/bash
# NixOS: explicitly set PATH so wl-kbptr is found from Hyprland exec
export PATH="/home/viscous/.nix-profile/bin:/etc/profiles/per-user/viscous/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

BUTTON=${1:-left} # Default to left click if no argument is provided

# Check if wl-kbptr is running by checking for its process ID
if pgrep -x "wl-kbptr" > /dev/null
then
    # If it is running, kill all instances
    pkill -x "wl-kbptr"
else
    # If it is not running, start it with the specified button
    wl-kbptr -o modes=tile,bisect,click -o mode_click.button="$BUTTON"
fi