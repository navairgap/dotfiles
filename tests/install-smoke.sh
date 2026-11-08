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

install_log="$(find "$TMP/home/.local/state/pulse" -name 'install-*.log' -print -quit)"
[[ -n "$install_log" ]]
grep -q 'done. reboot' "$install_log"

# failure path: a dying step must stop the install and leave a report in the log
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/home/.config" "$TMP2/bin"
for command_name in pacman systemctl yay fc-cache; do
  cp "$TMP/bin/$command_name" "$TMP2/bin/"
done
cat > "$TMP2/bin/sudo" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$TMP2/bin/sudo"

if HOME="$TMP2/home" PATH="$TMP2/bin:$PATH" bash "$ROOT/scripts/install.sh" >"$TMP2/out" 2>&1; then
  printf 'smoke test: expected the installer to fail with a stub that refuses sudo\n' >&2
  exit 1
fi
fail_log="$(find "$TMP2/home/.local/state/pulse" -name 'install-*.log' -print -quit)"
[[ -n "$fail_log" ]]
grep -q 'install failed' "$fail_log"
grep -q 'the step that died' "$fail_log"
grep -q 'full log:' "$fail_log"
grep -q 'install failed' "$TMP2/out"
rm -rf "$TMP2"

printf 'installer smoke test: links, backup, state and the log report verified (success + failure)\n'
