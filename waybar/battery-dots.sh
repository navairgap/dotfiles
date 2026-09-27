#!/usr/bin/env bash
# battery as a 20-dot strip — red when critical, ▲ while charging
cap=$(cat /sys/class/power_supply/*/capacity 2>/dev/null | head -1)
[ -z "$cap" ] && { echo "○"; exit 0; }
total=20; filled=$((cap * total / 100)); out=""
for i in $(seq 1 $total); do
  if [ "$i" -le "$filled" ]; then
    if [ "$cap" -le 15 ]; then out+="<span color='#ff3122'>●</span>"
    else out+="●"; fi
  else out+="○"; fi
done
[ "$(cat /sys/class/power_supply/*/status 2>/dev/null | head -1)" = "Charging" ] && out+=" <span color='#ff3122'>▲</span>"
echo "$out"
