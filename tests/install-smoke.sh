#!/usr/bin/env bash
# Exercise the installer with an isolated HOME and harmless command stubs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home/.config" "$TMP/custom-config" "$TMP/bin"
ln -s "$TMP/custom-config" "$TMP/home/.config/hypr"

for command_name in sudo pacman pgrep swww fc-cache; do
  cat > "$TMP/bin/$command_name" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$TMP/bin/$command_name"
done

HOME="$TMP/home" PATH="$TMP/bin:$PATH" SHELL=/bin/bash \
  bash "$ROOT/scripts/install.sh"

[[ -L "$TMP/home/.config/hypr" ]]
[[ "$(readlink "$TMP/home/.config/hypr")" == "$ROOT/hypr" ]]
backup_dir="$(find "$TMP/home/.config" -maxdepth 1 -type d -name 'backup-*' -print -quit)"
[[ -n "$backup_dir" ]]
[[ -L "$backup_dir/hypr" ]]
[[ "$(readlink "$backup_dir/hypr")" == "$TMP/custom-config" ]]

[[ -L "$TMP/home/.local/bin/make-wallpaper" ]]
[[ -L "$TMP/home/.local/bin/set-wallpaper" ]]
[[ "$(readlink "$TMP/home/.local/bin/make-wallpaper")" == "$ROOT/scripts/make-wallpaper.sh" ]]
[[ "$(readlink "$TMP/home/.local/bin/set-wallpaper")" == "$ROOT/scripts/set-wallpaper.sh" ]]

printf 'installer smoke test: helper links created under ~/.local/bin\n'
