#!/usr/bin/env bash
# Exercise the installer with an isolated HOME and harmless command stubs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/bin"

for command_name in sudo pacman pgrep swww fc-cache; do
  cat > "$TMP/bin/$command_name" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$TMP/bin/$command_name"
done

HOME="$TMP/home" PATH="$TMP/bin:$PATH" SHELL=/bin/bash \
  bash "$ROOT/scripts/install.sh"

[[ -L "$TMP/home/.local/bin/make-wallpaper" ]]
[[ -L "$TMP/home/.local/bin/set-wallpaper" ]]
[[ "$(readlink "$TMP/home/.local/bin/make-wallpaper")" == "$ROOT/scripts/make-wallpaper.sh" ]]
[[ "$(readlink "$TMP/home/.local/bin/set-wallpaper")" == "$ROOT/scripts/set-wallpaper.sh" ]]

printf 'installer smoke test: helper links created under ~/.local/bin\n'
