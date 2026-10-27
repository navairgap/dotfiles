#!/usr/bin/env bash
# set a nthing wallpaper via swww — cycles if no arg given
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/wallpapers"

if [ $# -ge 1 ]; then
  if [ ! -f "$1" ]; then
    printf 'wallpaper: not a file: %s\n' "$1" >&2
    exit 2
  fi
  CHOICE="$1"
else
  shopt -s nullglob
  WALLS=("$DIR"/nthing-*.jpg)
  if [ ${#WALLS[@]} -eq 0 ]; then
    printf 'wallpaper: no nthing-*.jpg files found in %s\n' "$DIR" >&2
    exit 1
  fi
  CHOICE="${WALLS[RANDOM % ${#WALLS[@]}]}"
fi

pgrep -x swww-daemon >/dev/null || swww-daemon >/dev/null 2>&1 &
sleep 0.4
swww img "$CHOICE" --transition-type wipe --transition-angle 30 --transition-duration 1.2
mkdir -p "$HOME/.cache"
ln -sf "$(readlink -f "$CHOICE")" "$HOME/.cache/nthing-current"
echo "wallpaper: $CHOICE"
