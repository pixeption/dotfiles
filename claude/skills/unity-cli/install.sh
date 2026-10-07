#!/usr/bin/env bash
# Run: install.sh <installed skill dir> — copies this copy's scripts/ over that skill's scripts/.
# Each changed file goes to a temp file beside its target and is renamed over it: bash reads a running
# script as it goes, so a file rewritten in place breaks every run of it in flight.
set -euo pipefail
SRC=$(cd "$(dirname "$0")/scripts" && pwd)
DEST=$(cd "${1:?usage: install.sh <installed skill dir>}/scripts" && pwd)
[[ "$SRC" != "$DEST" ]] || { echo "install.sh: source and target are the same directory" >&2; exit 1; }
cd "$SRC"
find . -type f ! -name .DS_Store | while read -r f; do
  cmp -s "$f" "$DEST/$f" && continue
  mkdir -p "$DEST/$(dirname "$f")"
  tmp="$DEST/$(dirname "$f")/.$(basename "$f").install.$$"
  cp -p "$f" "$tmp" && mv -f "$tmp" "$DEST/$f" || { rm -f "$tmp"; exit 1; }
  echo "installed $f"
done
