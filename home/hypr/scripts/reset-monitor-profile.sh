#!/usr/bin/env bash
# Auto-reset to safe monitor profile on boot

monitor_dir="$HOME/.config/hypr/configs/Monitor_Profiles"
target="$HOME/.config/hypr/configs/monitors.conf"

# Check if external monitor is connected
if hyprctl monitors | grep -q "HDMI-A-1"; then
    # External connected - use Extend profile as default
    cp "$monitor_dir/Extend.conf" "$target"
else
    # No external - use Laptop-Only profile
    cp "$monitor_dir/Laptop-Only.conf" "$target"
fi

# Reload Hyprland
hyprctl reload
