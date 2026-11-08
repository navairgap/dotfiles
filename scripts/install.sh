#!/usr/bin/env bash
# pulse dotfiles — Nothing OS × Hyprland × Quickshell installer (Arch)
#
#   ./scripts/install.sh                        packages + services + links + login theme
#   ./scripts/install.sh --with telegram,clash  same, extras picked up front
#   ./scripts/install.sh --links                links only (already-set-up machine, or another distro)
#   ./scripts/install.sh --sddm                 login theme only (sudo); re-run after editing sddm/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$HOME/.config"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$CONFIG/backup-$(date +%Y%m%d-%H%M%S)"

need_pacman() {
  command -v pacman >/dev/null 2>&1 || {
    printf 'error: this installer requires Arch Linux (pacman was not found); no files were changed.\n' >&2
    printf '       on another distro run: %s --links  (package list lives in the readme)\n' "$0" >&2
    exit 1
  }
}

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
dot()   { printf "  \033[31m●\033[0m %s\n" "$*"; }

# ---------- what gets installed ----------
PKGS=(
  # session
  hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
  # sound, network, bluetooth
  pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
  # things the binds and the shell call
  brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
  gpu-screen-recorder ydotool libnotify trash-cli jq curl python
  # terminal side
  kitty fish starship fastfetch btop cava eza zoxide direnv thunar pavucontrol
  # fonts + icon/color base
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(qtengine darkly-bin bibata-cursor-theme-bin zen-browser-bin)

# picked with --with, or asked about. these open the special-workspace binds (hypr/variables.lua)
declare -A EXTRA=(
  [telegram]="telegram-desktop"                                        # super+d
  [spotify]="spotify-launcher spicetify-cli spicetify-marketplace-bin" # super+m
  [clash]="clash-verge-rev-bin"                                        # the vpn panel, super+p
)

LINKS=(
  "pulse/term/qtengine.colors     $CONFIG/qtengine.colors"
  "pulse/term/starship.toml       $CONFIG/starship.toml"
  "pulse/term/fastfetch           $CONFIG/fastfetch"
  "pulse/term/btop                $CONFIG/btop"
  "pulse/term/cava                $CONFIG/cava"
  "pulse/term/gtk-3.0/gtk.css     $CONFIG/gtk-3.0/gtk.css"
  "pulse/term/gtk-4.0/gtk.css     $CONFIG/gtk-4.0/gtk.css"
  "gtk-3.0/settings.ini           $CONFIG/gtk-3.0/settings.ini"
)

# ---------- helpers ----------
link() {  # link <repo-relative> <absolute-target>
  local source="$REPO_DIR/$1"
  local target="$2"
  local backup_target="$BACKUP/$(basename "$target")"
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "    $target already points to $1"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
      printf 'error: backup path already exists: %s\n' "$backup_target" >&2
      exit 1
    fi
    mv "$target" "$backup_target"
    echo "    backed up $target → $backup_target"
  fi

  ln -s "$source" "$target"
  echo "    $target → $1"
}

extras() {  # --with or a question → EXT, installed apart from the AUR core
  EXT=()
  if [ -z "${WITH+x}" ]; then
    dot "anything else? space-separated, enter for none"
    local w
    for w in "${!EXTRA[@]}"; do printf '    %-9s %s\n' "$w" "${EXTRA[$w]}"; done
    read -rp "    > " WITH || true
  fi
  local w
  for w in ${WITH//,/ }; do
    [ -n "${EXTRA[$w]-}" ] || { printf 'no such extra: %s (available: %s)\n' "$w" "${!EXTRA[*]}"; exit 1; }
    EXT+=(${EXTRA[$w]})
  done
}

# ---------- steps ----------
packages() {
  dot "installing packages (${#PKGS[@]})…"
  # pulseaudio modules fight pipewire-pulse — get them out first, pacman won't offer the swap
  local pa
  pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer} 2>/dev/null || true)
  [ -z "$pa" ] || sudo pacman -R --noconfirm $pa
  if pacman -Qq pulseaudio >/dev/null 2>&1; then
    dot "pulseaudio is installed; pacman will ask to remove it (pipewire-pulse takes over) — answer yes"
  fi
  sudo pacman -S --needed --noconfirm "${PKGS[@]}"

  # aur: optional, a failed build must not take the whole install down
  if ! command -v yay >/dev/null 2>&1; then
    dot "bootstrapping yay…"
    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" 2>/dev/null; then
      (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || dot "yay build failed — install yay by hand, the rest still applies"
    else
      dot "couldn't fetch yay-bin — install yay by hand, the rest still applies"
    fi
    rm -rf "$tmp"
  fi
  yay -S --needed --noconfirm "${AUR[@]}" 2>/dev/null || dot "some aur packages failed, see above — everything else continues"
  if [ "${#EXT[@]}" -gt 0 ]; then
    yay -S --needed --noconfirm "${EXT[@]}" 2>/dev/null || dot "some extras failed, see above"
  fi
}

services() {
  command -v systemctl >/dev/null 2>&1 || return 0
  dot "enabling services…"
  sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
  systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
  systemctl --user enable pipewire-pulse.socket wireplumber ydotool
  sudo usermod -aG input,video "$USER"  # ydotool (uinput) and brightnessctl (backlight)
  xdg-user-dirs-update
}

links() {
  dot "backing up existing configs → $BACKUP"
  mkdir -p "$BACKUP"
  local d
  for d in hypr kitty fish qtengine; do
    [ -e "$CONFIG/$d" ] && [ ! -L "$CONFIG/$d" ] && mv "$CONFIG/$d" "$BACKUP/" && echo "    moved $d"
  done

  dot "linking configs…"
  link hypr   "$CONFIG/hypr"
  link kitty  "$CONFIG/kitty"
  link fish   "$CONFIG/fish"
  link qtengine "$CONFIG/qtengine"
  # the shell and its switcher live under quickshell/, next to any other shell you might install
  mkdir -p "$CONFIG/quickshell"
  link pulse "$CONFIG/quickshell/pulse"
  link rice  "$CONFIG/quickshell/rice"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$REPO_DIR/rice/rice" "$HOME/.local/bin/rice"
  chmod +x "$REPO_DIR/rice/rice" "$REPO_DIR"/scripts/*.sh

  # terminal-app theming: per-file, so gtk-3.0/bookmarks and friends survive
  local entry src dst
  for entry in "${LINKS[@]}"; do
    read -r src dst <<<"$entry"
    link "$src" "$dst"
  done

  # state the shell expects on first boot
  mkdir -p "$CONFIG/pulse" "$STATE/rice"
  [ -f "$STATE/rice/shell" ] || echo pulse > "$STATE/rice/shell"

  dot "installing fonts…"
  mkdir -p "$HOME/.local/share/fonts/pulse"
  cp "$REPO_DIR/fonts/"* "$HOME/.local/share/fonts/pulse/"
  fc-cache -f >/dev/null 2>&1 || true

  dot "seeding ~/Pictures/Wallpapers (the super+shift+w picker reads from there)…"
  mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Gifs"
  local w
  for w in "$REPO_DIR/wallpapers/"*; do
    [ -e "$HOME/Pictures/Wallpapers/$(basename "$w")" ] || cp "$w" "$HOME/Pictures/Wallpapers/"
  done

  # dark scheme for zen, electron apps and libadwaita (via the portal), plus the gtk3 base under our gtk.css
  if command -v gsettings >/dev/null 2>&1 && gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
  fi
}

greeter() {  # the login theme. copied, not linked: the sddm user can't read your home. -L pulls the fonts symlink in
  if [ ! -d /usr/share/sddm/themes ]; then
    dot "sddm isn't installed, skipping the login theme"
    return 0
  fi
  dot "installing the pulse login theme (sudo)…"
  sudo rm -rf /usr/share/sddm/themes/pulse
  sudo cp -rLT "$REPO_DIR/sddm" /usr/share/sddm/themes/pulse
  sudo chmod -R a+rX /usr/share/sddm/themes/pulse
  # empty InputMethod: sddm's default (qtvirtualkeyboard) puts an on-screen keyboard over this theme
  sudo mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=pulse\n\n[General]\nInputMethod=\n' | sudo tee /etc/sddm.conf.d/zz-pulse.conf >/dev/null
  # /etc/sddm.conf outranks conf.d — if it names another theme, say so
  if grep -qsE '^\s*Current=' /etc/sddm.conf && ! grep -qsE '^\s*Current=pulse\s*$' /etc/sddm.conf; then
    dot "/etc/sddm.conf sets its own theme and wins: set Current=pulse there"
  fi
}

# ---------- run ----------
if [ "$EUID" -eq 0 ]; then
  printf 'error: run as your user, not root — sudo is asked for when it is needed.\n' >&2
  exit 1
fi

bold "pulse — Nothing OS × Hyprland × Quickshell"
dot "repo: $REPO_DIR"

case "${1:-}" in
  --links)
    links ;;  # any distro; packages are on you, the readme lists them
  --sddm)
    greeter ;;
  ""|--with)
    need_pacman
    [ "${1:-}" = "--with" ] && WITH="${*:2}"  # commas or spaces both work
    extras
    packages
    services
    links
    greeter
    if [[ " ${WITH//,/ } " == *" spotify "* ]]; then
      dot "spotify: launch it once, log in, then: spicetify config custom_apps marketplace && spicetify backup apply"
    fi
    bold "done. reboot, pick Hyprland at the login screen."
    dot "super tap launcher · super+a quick settings · super+space deck · super+i prefs"
    ;;
  *)
    printf 'usage: %s [--with telegram,spotify,clash | --links | --sddm]\n' "$0"
    exit 1
    ;;
esac
