#!/usr/bin/env bash
# ram as a 20-dot strip
used=$(free -m | awk '/Mem:/ {printf "%d", $3/$2*100}')
total=20; filled=$((used * total / 100)); out=""
for i in $(seq 1 $total); do
  [ "$i" -le "$filled" ] && out+="●" || out+="○"
done
echo "$out"
