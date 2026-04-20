#!/bin/bash

# This script moves the mouse cursor by a small amount in a given direction.

direction=$1
amount=10

case $direction in
  left)
    wtype -M "$amount" 0
    ;;
  right)
    wtype -m "$amount" 0
    ;;
  up)
    wtype -M 0 "$amount"
    ;;
  down)
    wtype -m 0 "$amount"
    ;;
esac
