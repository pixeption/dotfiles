#!/usr/bin/env bash
# Offline test for install.sh: a script running from the installed copy finishes as the old version
# when a new version is installed under it mid-run, and an unchanged file is not rewritten.
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/dev/scripts" "$TMP/live/scripts"
cp "$(cd "$(dirname "$0")/.." && pwd)/install.sh" "$TMP/dev/"
printf '#!/usr/bin/env bash\nsleep 2\necho old-done\n' >"$TMP/live/scripts/s"
printf 'same\n' | tee "$TMP/live/scripts/u" >"$TMP/dev/scripts/u"
printf '#!/usr/bin/env bash\necho "a much longer replacement line that shifts every byte offset"\nsleep 2\necho new-done\n' >"$TMP/dev/scripts/s"
bash "$TMP/live/scripts/s" >"$TMP/out" 2>&1 & pid=$!
sleep 1
out=$("$TMP/dev/install.sh" "$TMP/live") || { echo "FAIL: install.sh exited $?"; exit 1; }
wait "$pid"
[[ "$(cat "$TMP/out")" == old-done ]] || { echo "FAIL: running script printed: $(cat "$TMP/out")"; exit 1; }
cmp -s "$TMP/dev/scripts/s" "$TMP/live/scripts/s" || { echo "FAIL: new script not installed"; exit 1; }
[[ "$out" == "installed ./s" ]] || { echo "FAIL: install output: $out"; exit 1; }
echo "PASS"
