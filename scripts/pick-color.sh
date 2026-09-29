#!/usr/bin/env bash
# hyprpicker — click a pixel, hex lands in clipboard and a notification shows
command -v hyprpicker >/dev/null || { echo "hyprpicker not installed"; exit 1; }
hyprpicker -a -n
notify-send -h string:x-dunst-stack-tag:picker "color copied" "$(wl-paste)"
