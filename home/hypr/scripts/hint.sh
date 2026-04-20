#!/bin/bash

# This script JUMPS the cursor to a hinted location without clicking.

# 1. Use hyprpicker to get coordinates for a selection.
if ! selected_coords=$(hyprpicker -a); then
    exit 0
fi

# 2. Extract X and Y.
x=$(echo "$selected_coords" | cut -d',' -f1)
y=$(echo "$selected_coords" | cut -d',' -f2)

# 3. Use wtype to MOVE the mouse to the coordinates.
wtype -m "$x" "$y"
