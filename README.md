# navairgap dotfiles — Nothing OS × Hyprland

A Hyprland rice inspired by **Nothing OS**: monochrome black, dot-matrix
accents, one red (`#ff3122`), zero chrome. Everything says less.

```
● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ●
```

## Stack

| piece         | app                         |
| ------------- | --------------------------- |
| WM            | Hyprland                    |
| bar           | waybar (dot workspaces)     |
| launcher      | rofi-wayland                |
| terminal      | kitty                       |
| notifications | dunst                       |
| wallpaper     | swww + generated dot-matrix |
| fetch         | fastfetch                   |

## Install (Arch)

```bash
git clone https://github.com/navairgap/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/install.sh
```

Log out, pick `Hyprland` at the display manager, log in. Existing configs are
backed up to `~/.config/backup-<date>/` before anything is symlinked.

## After install

- `SUPER + T` terminal · `SUPER + R` rofi · `SUPER + Q` close
- `SUPER + 1..9` workspaces · `SUPER + SHIFT + 1..9` move window
- `SUPER + F` fullscreen · `SUPER + M` maximize · drag to screen edges snaps
- `SUPER + SHIFT + R` reload hyprland
- regenerate wallpaper: `~/dotfiles/scripts/make-wallpaper.sh`

## Fonts

JetBrains Mono **Nerd Font** (installed by the script). If you own a Nothing
phone, drop an NDot-style font into `~/.local/share/fonts` and swap it into
`waybar/style.css` + `kitty/kitty.conf` for the full dot-matrix look.

## Structure

```
hypr/        hyprland.conf, keybinds, execs, rules, colors
waybar/      config.jsonc, style.css
rofi/        config.rasi, nothing.rasi
kitty/       kitty.conf
dunst/       dunstrc
fastfetch/   config.jsonc
scripts/     install.sh, make-wallpaper.sh
wallpapers/  nothing-dots.png (pre-generated)
```

## Palette

| role    | hex       |
| ------- | --------- |
| bg      | `#000000` |
| fg      | `#f5f5f5` |
| muted   | `#8a8a8a` |
| accent  | `#ff3122` |
| surface | `#141414` |

## License

MIT (see LICENSE)
