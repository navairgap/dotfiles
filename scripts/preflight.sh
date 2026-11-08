#!/usr/bin/env bash
# Read-only checks for the checked-out dotfiles before install.sh changes the system.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

fail() {
  printf 'error: %s\n' "$*" >&2
  errors=$((errors + 1))
}

for required in \
  scripts/install.sh \
  hypr pulse rice kitty fish qtengine sddm fonts wallpapers; do
  if [[ ! -e "$ROOT/$required" ]]; then
    fail "missing repository path: $required"
  fi
done

font_count=0
for font in "$ROOT"/fonts/*.ttf "$ROOT"/fonts/*.otf; do
  if [[ -f "$font" ]]; then
    font_count=$((font_count + 1))
  fi
done
if ((font_count == 0)); then
  fail "fonts/ contains no font files"
fi

if ! command -v bash >/dev/null 2>&1; then
  fail "bash is required"
else
  for file in "$ROOT"/scripts/*.sh; do
    [[ -f "$file" ]] || continue
    if ! bash -n "$file"; then
      fail "shell syntax check failed: $(basename "$file")"
    fi
  done
  if ! sh -n "$ROOT/rice/rice"; then
    fail "shell syntax check failed: rice/rice"
  fi
fi

if ! command -v pacman >/dev/null 2>&1; then
  fail "pacman was not found; install.sh supports Arch Linux only (--links works anywhere)"
fi

if ((errors)); then
  printf 'preflight failed with %d error(s); no files were changed.\n' "$errors" >&2
  exit 1
fi

printf 'preflight passed: required assets and shell syntax look valid.\n'
printf 'this check is read-only; review scripts/install.sh before running it.\n'
