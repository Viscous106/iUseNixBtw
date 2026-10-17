#!/bin/bash
# Auto-passthrough when Proxmox noVNC is focused
SOCK="/run/user/$(id -u)/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
IN_PASSTHROUGH=0

handle() {
  if [[ "$1" == activewindow* ]]; then
    TITLE=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // ""')
    if [[ "$TITLE" == *"Proxmox"* || "$TITLE" == *"noVNC"* || "$TITLE" == *"proxmox"* ]]; then
      if [[ $IN_PASSTHROUGH -eq 0 ]]; then
        hyprctl dispatch submap passthrough
        IN_PASSTHROUGH=1
      fi
    else
      if [[ $IN_PASSTHROUGH -eq 1 ]]; then
        hyprctl dispatch submap reset
        IN_PASSTHROUGH=0
      fi
    fi
  fi
}

socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do
  handle "$line"
done
