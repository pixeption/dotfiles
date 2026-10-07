#!/usr/bin/env bash
# Offline test for unity-wait's arguments: --project-path works before or after the mode, from a cwd
# outside any project, and an unknown option fails instead of being read as the mode or a deadline.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/unity-wait"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$TMP/home/.unity/bin"
touch "$PROJ/ProjectSettings/ProjectVersion.txt"
PROJ=$(cd "$PROJ" && pwd)
cat >"$TMP/home/.unity/bin/unity" <<STUB
#!/usr/bin/env bash
echo '{"data":{"result":{"status":"ready","playMode":"stopped"}}}'
STUB
chmod +x "$TMP/home/.unity/bin/unity"
check() {                            # check <name> <want exit> <args...>
  local name=$1 want=$2 out code; shift 2
  out=$(cd "$TMP" && HOME="$TMP/home" "$SCRIPT" "$@" 2>&1); code=$?
  if [[ $code == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name (exit $code, want $want): $out"; FAILED=1; fi
}
FAILED=0
check before 0 --project-path "$PROJ" ready 5
check after  0 ready 5 --project-path "$PROJ"
check middle 0 ready --project-path "$PROJ" 5
check unknown 1 ready --project "$PROJ"
check missing 1 ready --project-path
exit $FAILED
