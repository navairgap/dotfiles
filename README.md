# pulse

nothing os rice for hyprland + quickshell. black, white dots, one red.

the whole desktop lives in one quickshell shell — bar, home screen, launcher,
quick settings, dashboard, screenshots, clipboard, lock screen, login screen.
no waybar, no rofi, no dunst. hyprland is configured in lua (needs hyprland 0.56+).

## install

```bash
git clone https://github.com/navairgap/dotfiles ~/dotfiles
cd ~/dotfiles
./scripts/install.sh
```

arch only. installs the packages, backs up your old ~/.config to
~/.config/backup-<date>, symlinks everything, installs the fonts and the
sddm login theme, seeds ~/Pictures/Wallpapers (the wallpaper picker reads
from there). `--with telegram,spotify,clash` adds the extras up front.
reboot, pick hyprland, log in.

on a machine that's already set up, or another distro: `./scripts/install.sh --links`
(the package list is in scripts/install.sh; quickshell 0.3.1+ and hyprland 0.56+ are the load-bearing ones).

every run keeps a log at `~/.local/state/pulse/install-<date>.log` (last five kept). if a
step fails, the script prints what died, the log tail and the full path — paste that when asking for help.

## keys

| key | what |
| --- | --- |
| super (tap) | launcher — apps, windows, calculator, style |
| super + a | quick settings, media, notifications |
| super + space | deck — the dashboard from the bottom edge |
| super + i | prefs — style, bar/home layout, audio devices |
| print | screenshot / recording, with editor |
| super + v | clipboard history |
| super + . | emoji, kaomoji, symbols |
| super + shift + w | wallpapers |
| super + p | vpn panel (clash verge) |
| super + esc | power menu |
| super + l | lock screen |
| alt+tab / super+tab | window switcher — hold, tap, release |
| super + ctrl + up | overview: every workspace on one scrim |
| super + alt + arrows / 1..4 | snap: halves / quarters |
| ctrl + alt + k | keybind cheat sheet |
| super + q / w | terminal / browser (apps in hypr/variables.lua) |
| super + h/j/k/l or arrows | focus |
| super + 1..5 | workspaces |
| click the clock | calendar + focus timer |

the full list lives in hypr/hyprland/keybinds.lua — ctrl+alt+k shows the
cheat sheet on screen. every panel also opens from screen edges, the tray
and the bar; right-click the empty wallpaper for the desktop menu.

## what's here

hypr/ (lua config: entry, variables, keybinds, rules, animations…) ·
pulse/ (the quickshell shell — bar, home, launcher, quick, deck, prefs, shot,
clip, charms, walls, vpn, cal, buds, power, lock, edge osd) · rice/ (shell
switcher cli + picker) · sddm/ (login theme: camera-dial session wheel,
tachometer that fills as you type) · kitty · fish · qtengine · fonts
(doto, space grotesk, space mono) · wallpapers

## style

three sources, switchable in prefs or the launcher: nothing (black/white/red),
a tone of your wallpaper through a material you variant, or a palette —
catppuccin, rosé pine, gruvbox, nord, dracula, tokyo night, everforest,
kanagawa. shell, hyprland and kitty follow at once; gtk and qt apps on their
next start.

## palette

bg `#000000` · surface `#0E0E0E` `#1A1A1A` · line `#2A2A2A` `#4A4A4A` ·
muted `#8C8C8C` · fg `#F2F2F2` · red `#D71921` — dark and light.

## your own stuff

`hypr/user.lua` is gitignored — put your binds and app overrides there and
`git pull` never touches it:

```lua
require("variables").apps.editor = "codium"   -- super+shift+k, empty by default
```

## borrowed from

- the shell is a from-scratch rewrite of [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice)
  — same look, same feature set, my own code. that repo took its shape from
  [caelestia](https://github.com/caelestia-dots/shell) and Nothing OS; the
  earbuds protocol came from Gadgetbridge, the doto font from oliverlalan.
- keybind layout and the general shape: prasanthrangan/hyprdots
- wallpapers: Runixe786/NThing-UI (rainmeter skin) — personal-use only, go star the original

## license

gpl-3.0 (see LICENSE). the shell above is a derivative work of glyph-rice, so
this repo ships under gpl-3.0 too — that's the license doing its job, not a
disclaimer of the rewrite. the fonts are under the ofl (fonts/OFL.txt).

## known issues / todo

- first boot after install: give sddm a reboot, the theme needs the copied fonts.
- the vpn panel reads clash verge's tray in english — switch the app if the panel looks dead.
- nixos: quickshell 0.3.0 (26.05) crashes in prefs → audio; take it from unstable.
- todo: screenshots for this readme once i boot it on real hardware.
- todo: waybar/rofi/dunst configs from the old rice are gone — they're in git
  history if anyone wants them.

---
maintained · verified 2026-11-08
