#!/bin/sh

swayidle -w 
    timeout 60 'hyprctl dispatch dpms off' 
    resume 'hyprctl dispatch dpms on' 
    timeout 180 'loginctl lock-session' 
    before-sleep 'loginctl lock-session'
