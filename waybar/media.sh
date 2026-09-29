#!/usr/bin/env bash
# now-playing for waybar — playerctl with a quiet fallback
if command -v playerctl >/dev/null; then
  status=$(playerctl status 2>/dev/null)
  if [ "$status" = "Playing" ]; then
    echo "▶ $(playerctl metadata --format '{{ artist }} — {{ title }}' 2>/dev/null | cut -c1-40)"
  elif [ "$status" = "Paused" ]; then
    echo "⏸ $(playerctl metadata --format '{{ artist }} — {{ title }}' 2>/dev/null | cut -c1-40)"
  else
    echo ""
  fi
else
  echo ""
fi
