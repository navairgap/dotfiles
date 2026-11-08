# pulse

nothing os rice for hyprland + quickshell. black, white dots, one red.

the whole desktop lives in one quickshell shell — bar, home screen, launcher,
quick settings, deck, settings, screenshots, clipboard, emoji, wallpapers, vpn,
earbuds, power menu, lock screen, login screen. no waybar, no rofi, no dunst.
hyprland is configured in lua (needs hyprland 0.56+), and everything self-heals:
the shell, the idle daemon, night light and the clipboard watchers are systemd
user units — kill the shell and it's back in ~2 s.

## the desktop

| panel | what | key |
| --- | --- | --- |
| bar | pill on the left or top: launcher mark, workspace dots (hover one for its windows), clock, real tray, battery, power mode | — |
| home | doto clock, greeting, weather/notification row, 3×3 bento widgets (pick them in prefs), dot grid, cat | — |
| launcher | apps, style picker, open windows, calculator, file search, `$PATH` commands, web answer | super tap |
| quick | wifi + bluetooth (with a device picker), dnd, night light, airplane, caffeine, mic, recording, vpn, dark/light, per-app volume mixer, power modes, game mode, earbud anc, media, notifications with action buttons | super+a |
| deck | dashboard from the bottom edge: clock, weather, cpu/gpu rings + top processes, network matrix, media | super+space |
| prefs | 13 sections, everything live: home, deck, bar, look, edge lights, style, windows, display, audio, power, input, idle, shell | super+i |
| shot | screenshots + recording + a loupe editor (draw, blur, arrows, color readout) | print |
| clip | clipboard history with previews, filters, image cache | super+v |
| charms | emoji, kaomoji, symbols — searchable, ┻━┻ included | super+. |
| walls | wallpapers as a dot strip, per-screen | super+shift+w |
| vpn | clash verge panel: tunnel, portal guard, traffic | super+p |
| cal | calendar, focus timer, stopwatch | click the clock |
| buds | nothing/cmf earbuds: battery, anc | — |
| power | lock · sleep · shut down · reboot · log out | super+esc |
| lock | full-width clock, dot password field, power actions | super+l |
| sddm | login theme: camera-dial session wheel, tachometer that fills as you type, staged power-on | — |
| edge | the screen edges as leds: notification flash (pick the pattern in prefs → edge lights), volume/brightness rising from the bottom, task progress along the bottom | — |
| overview | every workspace on one scrim, type to filter, click to land | super+ctrl+up |
| keys | the cheat sheet, on screen | ctrl+alt+k |
| jot | sticky notes from the desktop menu | — |

## all the keys

full truth lives in `hypr/hyprland/keybinds.lua` (names in `variables.lua`,
change both there or override in `user.lua`). ctrl+alt+k shows the short
version on screen.

### panels

| key | what |
| --- | --- |
| super (tap) | launcher |
| super + a / super + n | quick settings |
| super + space | deck |
| super + i | prefs |
| print / super+shift+s | screenshot · recording |
| super + v | clipboard |
| super + . | charms (emoji) |
| super + shift + w | wallpapers |
| super + p | vpn |
| click the clock | calendar · timer · stopwatch |
| super + esc / ctrl+alt+del | power menu |
| super + l | lock (works with the shell dead) |
| super + alt + l | raise a dead lock while locked |
| super + ctrl + up | overview |
| ctrl + alt + k | the cheat sheet |

### windows

| key | what |
| --- | --- |
| alt+tab / super+tab | window switcher — hold, tap, release to land |
| alt+shift+tab / super+shift+tab | switcher, backwards |
| alt+esc | put the switcher down |
| super+alt+arrows | snap: left/right half · up full · down centered |
| super+alt+1..4 | snap: quarters |
| super + arrows | focus |
| super + shift + arrows | move window |
| super + drag / super+z | move |
| super + right-drag / super+x | resize |
| super + minus / equal | resize wider/narrower (shift: taller/shorter, alt too) |
| ctrl+super+backslash | center window |
| ctrl+super+alt+backslash | resize to 55×70% of the screen |
| super+alt+backslash | picture-in-picture the focused window |
| super+f / super+alt+f | fullscreen / maximize |
| super+shift+p | pin (keep above) |
| super+alt+space | float / tile |
| super+c | close |
| super+u | kill (pick a window) |
| ctrl+alt+tab | cycle window groups |

### workspaces and groups

| key | what |
| --- | --- |
| super + 1..0 | go to workspace (shift: send the window) |
| ctrl+super+1..0 | same into the window group |
| super + wheel / ctrl+super+left/right | workspace ±1 |
| ctrl+super+wheel | groups ±10 |
| super+alt+wheel / page up/down | send window ±1 |
| ctrl+super+shift+left/right | send window ±1 |
| ctrl+super+shift+up | send to the special workspace |
| ctrl+super+shift+down | send to the empty next one |
| super+u / super+comma | ungroup · toggle group |
| super+shift+comma | lock all groups |

### special workspaces

| key | what |
| --- | --- |
| super + s | terminal scratchpad (apps in variables.lua) |
| ctrl+shift+esc | system monitor |
| super + m | music |
| super + d | chat |
| super + r | todo |

each opens empty — the app launches on first open, swaps in `user.lua`.

### apps and media

| key | what |
| --- | --- |
| super + q | terminal (kitty) |
| super + w | browser (zen) |
| super + shift + k | editor (empty until you set it) |
| super + e | files (thunar) |
| ctrl+alt+v | pavucontrol |
| fn keys | volume, mic mute, brightness — osd on the edges |
| ctrl+super+space / xf86 audio keys | play · next · previous · stop |
| super+shift+m | mute |

### the system

| key | what |
| --- | --- |
| super+shift+c | hyprpicker — color to clipboard |
| super+alt+r | record with sound · ctrl+alt+r silent · super+shift+alt+r region |
| super+shift+l | suspend |
| ctrl+super+alt+r | restart the shell (works with the shell dead — it also restarts itself) |
| ctrl+super+shift+r | put the shell down |
| 4-finger swipe up/down | toggle the special workspace |
| 5-finger swipe up | sleep |

## the settings — prefs, super+i

every section is live: move a dial, the screen moves. state lives in
`~/.config/pulse/pulse.json`, per-monitor bits in `rules.json`.

- **home · deck · bar** — the widget/section/tray lists, drag to reorder
- **look** — gaps, borders, rounding, blur, shadows, animations
- **edge lights** — the notification flash pattern: breathe · pulse · double · blink · wave. hover one and the strip plays it — the same math the real edge runs (`pulse/edge/flash.js`)
- **style** — color from nothing, a wallpaper tone (nine material-you variants) or a palette: catppuccin, rosé pine, gruvbox, nord, dracula, tokyo night, everforest, kanagawa. a live desktop mock-up shows the palette under the cursor before you commit; shell, hyprland and kitty follow at once, gtk and qt on their next start
- **windows · display** — monitor map you drag, scale, refresh, brightness, night light warmth
- **audio** — output/input devices; the per-app mixer lives in quick settings
- **power · input · idle** — power modes, keyboard repeat, touchpad, layout switch, hypridle timings on a minute scale
- **shell** — the running shell's name, the rice switcher card

## under the hood

- **self-healing** — `systemd/user/` ships four units (shell, hypridle, hyprsunset, clipboard); hyprland starts them with `graphical-session.target` and any crash restarts in 2 s. `rice` routes start/kill/restart through them, direct `qs` when there's no systemd
- **the installer logs** — every run writes `~/.local/state/pulse/install-<date>.log`; a failed step prints what died and the log tail
- **the shell cli** — `rice` · `rice list` · `rice start` · `rice restart` · `rice kill` · `rice switch <name>` · `rice lock`
- **your own binds** — `hypr/user.lua` is gitignored; `git pull` never touches it:

```lua
local apps = require("variables").apps
apps.editor = "codium"              -- super+shift+k, empty by default
apps.todo   = "planify"             -- super+r

hl.bind("SUPER + G", hl.dsp.global("shell:game"))  -- game mode has no key by default
```

## install

```bash
git clone https://github.com/navairgap/dotfiles ~/dotfiles
cd ~/dotfiles
./scripts/install.sh
```

arch only. installs the packages, backs up your old ~/.config to
`~/.config/backup-<date>`, symlinks everything, installs the fonts, the sddm
login theme and the systemd units, seeds `~/Pictures/Wallpapers`. `--with
telegram,spotify,clash` adds the extras up front. reboot, pick hyprland, log in.

on a machine that's already set up, or another distro: `./scripts/install.sh
--links`. `--sddm` re-installs the login theme after you edit `sddm/`.
quickshell 0.3.1+ and hyprland 0.56+ are the load-bearing packages; the full
list is in `scripts/install.sh`.

every run keeps a log at `~/.local/state/pulse/install-<date>.log` (last five
kept); a failed step prints what died, the log tail and the full path.

## palette

bg `#000000` · surface `#0E0E0E` `#1A1A1A` · line `#2A2A2A` `#4A4A4A` ·
muted `#8C8C8C` · fg `#F2F2F2` · red `#D71921` — dark and light. red marks
the one live thing on screen. fonts: doto, space grotesk, space mono,
jetbrains mono nerd font.

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
- the switcher and overview show icon cards, not live thumbnails — hypr doesn't hand those out (yet).
- todo: screenshots for this readme once i boot it on real hardware.

---
maintained · verified 2026-11-08
