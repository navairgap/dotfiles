#!/usr/bin/env bash
# screenshot helper — grim + slurp, copies to clipboard
set -e
DIR="$HOME/Pictures/shots"
mkdir -p "$DIR"
OUT="$DIR/$(date +%Y%m%d-%H%M%S).png"

if [ "${1:-}" = "-f" ]; then
  grim "$OUT"
elif command -v slurp >/dev/null; then
  grim -g "$(slurp)" "$OUT"
else
  grim "$OUT"
fi

wl-copy < "$OUT"
echo "saved: $OUT (also copied to clipboard)"
