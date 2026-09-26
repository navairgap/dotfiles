#!/usr/bin/env bash
# nothing dot-matrix wallpaper — generates + sets via swww
set -e
OUT="$HOME/.cache/nothing-wallpaper.png"
mkdir -p "$(dirname "$OUT")"

# 48px tile: dark dots on black; one accent cluster near the golden ratio
convert -size 1920x1080 xc:'#000000'   -size 48x48 'xc:#000000'   -fill '#1c1c1c' -draw 'circle 24,24 24,16'   -size 48x48 -clone 0 -tile 40x23 -geometry +0+0 -composite +swap -delete 0   -fill '#ff3122'   -draw 'circle 1180,680 1180,672'   -draw 'circle 1230,720 1230,712'   -draw 'circle 1130,730 1130,722'   -draw 'circle 1210,640 1210,632'   -draw 'circle 1150,610 1150,602'   "$OUT"

# fallback tiling if the clone trick above misbehaves on older imagemagick
if [ ! -s "$OUT" ]; then
  convert -size 48x48 xc:none -fill '#1c1c1c' -draw 'circle 24,24 24,16' mpr:dot +delete     -size 1920x1080 tile:mpr:dot     -fill '#ff3122' -draw 'circle 1180,680 1180,672'     "$OUT"
fi

if pgrep -x swww-daemon >/dev/null; then
  swww img "$OUT" --transition-type fade --transition-duration 1
else
  echo "swww-daemon not running; wallpaper written to $OUT"
fi
