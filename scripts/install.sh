#!/usr/bin/env bash
# navairgap dotfiles — Nothing OS × Hyprland installer (Arch)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$HOME/.config"
BACKUP="$CONFIG/backup-$(date +%Y%m%d-%H%M%S)"

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
dot()   { printf "  \033[31m●\033[0m %s\n" "$*"; }

bold "navairgap dotfiles — Nothing OS × Hyprland"
dot "repo: $REPO_DIR"

# ---------- packages ----------
PKGS=(
  hyprland waybar rofi-wayland kitty dunst swww
  pipewire pipewire-pulse wireplumber
  xdg-desktop-portal-hyprland xdg-user-dirs
  polkit-kde-agent qt5-wayland qt6-wayland
  ttf-jetbrainsmono-nerd imagemagick fastfetch
  brightnessctl cliphist wl-clipboard grim slurp
)

dot "installing packages (${#PKGS[@]})…"
if command -v pacman >/dev/null; then
  sudo pacman -S --needed --noconfirm "${PKGS[@]}"
else
  echo "  ! pacman not found — this installer targets Arch."
  echo "    Install these manually: ${PKGS[*]}"
fi

# ---------- backup ----------
dot "backing up existing configs → $BACKUP"
mkdir -p "$BACKUP"
for d in hypr waybar rofi kitty dunst fastfetch gtk-3.0; do
  [ -e "$CONFIG/$d" ] && [ ! -L "$CONFIG/$d" ] && mv "$CONFIG/$d" "$BACKUP/" && echo "    moved $d"
done

# ---------- symlink ----------
dot "linking configs…"
link() {  # link <repo-relative> <target>
  mkdir -p "$(dirname "$2")"
  ln -sfn "$REPO_DIR/$1" "$2"
  echo "    $2 → $1"
}
link hypr            "$CONFIG/hypr"
link waybar          "$CONFIG/waybar"
link rofi            "$CONFIG/rofi"
link kitty           "$CONFIG/kitty"
link dunst           "$CONFIG/dunst"
link fastfetch       "$CONFIG/fastfetch"
link gtk-3.0         "$CONFIG/gtk-3.0"

# scripts into place
mkdir -p "$HOME/bin" 2>/dev/null || true
ln -sf "$REPO_DIR/scripts/make-wallpaper.sh" "$HOME/.local/bin/make-wallpaper" 2>/dev/null || true

# ---------- wallpaper ----------
dot "generating dot-matrix wallpaper…"
bash "$REPO_DIR/scripts/make-wallpaper.sh" || echo "  ! wallpaper step skipped (imagemagick missing?)"

# ---------- default shell ----------
if command -v zsh >/dev/null && [ "$SHELL" != "$(command -v zsh)" ]; then
  dot "setting default shell to zsh…"
  chsh -s "$(command -v zsh)" || true
fi

bold "done. log out, choose Hyprland at your display manager, log in."
dot "SUPER+T terminal · SUPER+R launcher · SUPER+SHIFT+R reload"
