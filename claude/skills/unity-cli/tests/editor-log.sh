#!/usr/bin/env bash
# Offline test for _common.sh's editor_log / in_safe_mode / compile_errors / server_failed (Unity 6.6
# project logs) and not_running.
set -uo pipefail
COMMON="$(cd "$(dirname "$0")/.." && pwd)/scripts/_common.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; mkdir -p "$PROJ/Logs"
SAFE='Safe Mode: Only loading a subset of assemblies'
ERR='Assets/Foo.cs(3,1): error CS1002: ; expected'

write() { printf '%s\n' "${@:2}" >"$1"; }
FAILED='Failed to start Pipeline Server: Address already in use'
probe() { PROJECT=${2:-$PROJ} UNITY_EDITOR_LOG="$TMP/global.log" bash -c "source '$COMMON'; $1"; }

fail=0
check() { # check <name> <want> <got>
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want [$2] got [$3]"; fail=1; fi
}

# Unity 6.6 session: the global log holds only the header, the project log the rest.
write "$TMP/global.log" "$PROJ" "Logs moved to project-relative Editor.log file"
touch -t 202601010000 "$TMP/global.log"
write "$PROJ/Logs/Editor.log" "$PROJ" "$SAFE" "$ERR" "$ERR"
check "project log is read"          "$PROJ/Logs/Editor.log" "$(probe editor_log)"
check "safe mode seen in project log" yes "$(probe 'in_safe_mode && echo yes')"
check "compile errors, deduplicated" "$ERR" "$(probe compile_errors)"

# A fresh launch before the move: the stale project log's Safe Mode line must not count.
write "$TMP/global.log" "$PROJ" "still starting"
check "newer global log of ours wins" "$TMP/global.log" "$(probe editor_log)"
check "stale safe mode ignored"      no "$(probe 'in_safe_mode && echo yes || echo no')"

# Another project launched later: its global log is not ours, so ours stays the project log.
write "$TMP/global.log" "/elsewhere/Other" "$SAFE"
check "foreign global log skipped"   "$PROJ/Logs/Editor.log" "$(probe editor_log)"

# A server that could not bind is reported; a relaunch ignores the line until its own log is written.
write "$PROJ/Logs/Editor.log" "$PROJ" "$FAILED"
check "failed server seen"           "$FAILED" "$(probe server_failed)"
touch "$TMP/launch"
check "previous session's failure ignored" no "$(LAUNCH_MARKER=$TMP/launch probe 'server_failed || echo no')"
echo "$FAILED" >>"$PROJ/Logs/Editor.log"
check "failure since launch seen"    "$FAILED" "$(LAUNCH_MARKER=$TMP/launch probe server_failed)"

# not_running matches the whole project path: a live .../GameCore says nothing about .../Game.
bash -c 'sleep 30; :' "Unity -projectpath $TMP/GameCore -automated" & SLEEPER=$!
check "sibling project's editor ignored" yes "$(probe 'not_running && echo yes' "$TMP/Game")"
check "own editor seen"              no "$(probe 'not_running && echo yes || echo no' "$TMP/GameCore")"
kill $SLEEPER

# No project log (pre-6.6 editor): the global log is the only one.
rm "$PROJ/Logs/Editor.log"; write "$TMP/global.log" "$PROJ" "$SAFE"
check "fallback to global log"       yes "$(probe 'in_safe_mode && echo yes')"
exit $fail
