#!/bin/bash

if ! pgrep -x "warpd" > /dev/null
then
    warpd --hint &
    notify-send "Warpd" "Warp mode on"
else
    notify-send "Warpd" "Warp mode is already active"
fi