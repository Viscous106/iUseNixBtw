#!/run/current-system/sw/bin/bash
# Seeds ~/.cache/kb_layout so waybar's custom/keyboard module (interval=1)
# never reads a missing file before SwitchKeyboardLayout.sh has run once.
set -euo pipefail

CACHE="$HOME/.cache/kb_layout"
mkdir -p "$HOME/.cache"
[[ -f "$CACHE" ]] || echo "us" > "$CACHE"
