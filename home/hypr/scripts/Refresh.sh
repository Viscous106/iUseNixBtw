#!/usr/bin/env bash
/usr/bin/hyprctl reload
killall waybar
waybar &
