#!/usr/bin/env bash
# rofi power menu — lock / logout / suspend / reboot / shutdown
opt=$(printf "lock\nlogout\nsuspend\nreboot\nshutdown" | rofi -dmenu -config ~/.config/rofi/config.rasi -p "power")
case "$opt" in
  lock)     loginctl lock-session ;;
  logout)   hyprctl dispatch exit ;;
  suspend)  systemctl suspend ;;
  reboot)   systemctl reboot ;;
  shutdown) systemctl poweroff ;;
esac
