#!/usr/bin/env bash
# weather pill — wttr.in with an offline fallback
w=$(curl -sf --max-time 3 "wttr.in/?format=%c+%t" 2>/dev/null)
[ -n "$w" ] && echo "$w" || echo "◌ offline"
