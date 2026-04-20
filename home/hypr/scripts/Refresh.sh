#!/usr/bin/env bash
# NixOS: hyprctl is in PATH via $PATH, not /usr/bin/
hyprctl reload
pkill waybar || true
waybar &
