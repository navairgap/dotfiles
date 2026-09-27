#!/usr/bin/env bash
# cycle to the next nthing wallpaper
DIR="$HOME/dotfiles/wallpapers"
mapfile -t WALLS < <(ls "$DIR"/nthing-*.jpg)
[ ${#WALLS[@]} -eq 0 ] && exit 0
CUR=$(readlink -f "$HOME/.cache/nthing-current" 2>/dev/null || echo "")
for i in "${!WALLS[@]}"; do
  if [ "$(readlink -f "${WALLS[$i]}")" = "$CUR" ]; then
    NEXT="${WALLS[$(( (i + 1) % ${#WALLS[@]} ))]}"; break
  fi
done
NEXT="${NEXT:-${WALLS[0]}}"
ln -sf "$(readlink -f "$NEXT")" "$HOME/.cache/nthing-current"
exec "$HOME/dotfiles/scripts/set-wallpaper.sh" "$NEXT"
