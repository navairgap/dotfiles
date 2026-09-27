#!/usr/bin/env bash
# set a nthing wallpaper via swww — cycles if no arg given
set -e
DIR="$HOME/dotfiles/wallpapers"
WALLS=("$DIR"/nthing-*.jpg)
if [ $# -ge 1 ] && [ -f "$1" ]; then
  CHOICE="$1"
else
  CHOICE="${WALLS[RANDOM % ${#WALLS[@]}]}"
fi
pgrep -x swww-daemon >/dev/null || swww-daemon >/dev/null 2>&1 &
sleep 0.4
swww img "$CHOICE" --transition-type wipe --transition-angle 30 --transition-duration 1.2
ln -sf "$(readlink -f "$CHOICE")" "$HOME/.cache/nthing-current"
echo "wallpaper: $CHOICE"
