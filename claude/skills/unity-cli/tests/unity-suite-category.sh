#!/usr/bin/env bash
# Offline test for unity-suite's NUnit pass-through (a stub `unity` records its arguments), and that
# the batch editor logs to the project's own Editor.log, and that a bare call inside a project prints the usage instead of running the suite.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/unity-suite"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$TMP/home/.unity/bin"
touch "$PROJ/ProjectSettings/ProjectVersion.txt"

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
[[ \$1 == test ]] || { echo '{"data":{}}'; exit 0; }
printf '%s\n' "\$@" >"$TMP/args"
while [[ \$# -gt 0 ]]; do [[ \$1 == --output ]] && out=\$2; shift; done
echo '<test-run total="1" passed="1" failed="0" skipped="0"/>' >"\$out"
EOF
chmod +x "$TMP/home/.unity/bin/unity"

out=$(cd "$PROJ" && HOME="$TMP/home" "$SCRIPT" 2>&1); code=$?
if [[ $code == 2 && $out == usage:* && ! -e "$TMP/args" ]]; then echo "ok   bare call prints usage"
else echo "FAIL bare call (exit $code): $out"; exit 1; fi

out=$(HOME="$TMP/home" "$SCRIPT" "$PROJ" --category '!Integration' --assemblies 'A;B' 2>&1) || {
  printf '%s\n' "$out" >&2
  exit 1
}
want="--
-logFile
$PROJ/Logs/Editor.log
-assemblyNames
A;B
-testCategory
!Integration"
if [[ $(tail -7 "$TMP/args" 2>/dev/null) == "$want" ]]; then echo "ok   project log, category and assemblies after --"
else echo "FAIL: $out"; cat "$TMP/args" 2>/dev/null; exit 1; fi
