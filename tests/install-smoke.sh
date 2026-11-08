#!/usr/bin/env bash
# Exercise the installer with an isolated HOME and harmless command stubs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home/.config" "$TMP/custom-config" "$TMP/bin"
ln -s "$TMP/custom-config" "$TMP/home/.config/hypr"

for command_name in sudo pacman systemctl yay fc-cache; do
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

[[ -L "$TMP/home/.config/quickshell/pulse" ]]
[[ "$(readlink "$TMP/home/.config/quickshell/pulse")" == "$ROOT/pulse" ]]
[[ -L "$TMP/home/.config/quickshell/rice" ]]
[[ "$(readlink "$TMP/home/.config/quickshell/rice")" == "$ROOT/rice" ]]
[[ -L "$TMP/home/.config/starship.toml" ]]
[[ "$(readlink "$TMP/home/.config/starship.toml")" == "$ROOT/pulse/term/starship.toml" ]]

[[ -L "$TMP/home/.local/bin/rice" ]]
[[ "$(readlink "$TMP/home/.local/bin/rice")" == "$ROOT/rice/rice" ]]

[[ -f "$TMP/home/.local/share/fonts/pulse/Doto[ROND,wght].ttf" ]]
[[ -f "$TMP/home/.local/state/rice/shell" ]]
grep -qx pulse "$TMP/home/.local/state/rice/shell"

printf 'installer smoke test: links, backup and state seeded under a stubbed home\n'
