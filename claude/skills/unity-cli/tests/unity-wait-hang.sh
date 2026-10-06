#!/usr/bin/env bash
# Offline test for `unity-wait recompile` telling a hung editor from a busy one, and for unity-suite
# naming the hang instead of compile errors. A stub stands in for `unity`; the scripts are real.
#   hung     - server answers `ready`, no command answers: exit 4 within the hang window.
#   dialog   - same, server `blocked_by_dialog`: exit 4.
#   reload   - no command answers, server down (a domain reload): waits out the deadline, exit 2.
#   answered - recompile_status answers: compiled clean, exit 0.
#   suite    - unity-suite on a hung editor says "editor hung", not "compiler errors", and runs nothing.
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -R "$(cd "$(dirname "$0")/.." && pwd)/scripts" "$TMP/scripts"
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$PROJ/Logs" "$TMP/home/.unity/bin" "$TMP/home/Library/Logs/Unity"
touch "$PROJ/ProjectSettings/ProjectVersion.txt" "$TMP/home/Library/Logs/Unity/Editor.log"
PROJ=$(cd "$PROJ" && pwd)
printf 'header\n%s\n' "$PROJ" >"$PROJ/Logs/Editor.log"

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "status "*)
    state=ready; [[ \$STUB == dialog ]] && state=blocked_by_dialog
    if [[ \$STUB == reload && -f "$TMP/recompiled" ]]; then echo '{"data":{"instances":[]}}'
    else echo '{"data":{"instances":[{"project":"$PROJ","state":"'\$state'"}]}}'; fi;;
  "command recompile") touch "$TMP/recompiled"; echo '{"data":{}}';;
  "command recompile_status")
    [[ \$STUB == answered ]] && echo '{"data":{"result":{"status":"up_to_date","failed":false}}}' || echo '{"data":{}}';;
  "command editor_status")
    [[ \$STUB == answered ]] && echo '{"data":{"result":{"status":"ready","playMode":"stopped"}}}' || echo '{"data":{}}';;
  "command run_tests") echo run_tests >>"$TMP/calls"; echo '{"data":{}}';;
  *) echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/home/.unity/bin/unity"

fail=0
run() { # run <stub> <command...>: sets out, code, took
  rm -f "$TMP/recompiled" "$TMP/calls"
  local start=$SECONDS
  out=$(STUB=$1 HOME="$TMP/home" UNITY_WAIT_HANG=3 UNITY_WAIT_SETTLE=6 "${@:2}" 2>&1); code=$?
  took=$(( SECONDS - start ))
}
check() { # check <name> <condition...>
  if "${@:2}"; then echo "ok   $1"; else echo "FAIL $1 (exit $code, ${took}s): $out"; fail=1; fi
}
wait_cmd=("$TMP/scripts/unity-wait" --project-path "$PROJ" recompile 12)

run hung "${wait_cmd[@]}"
check hung     eval '(( code == 4 && took < 12 )) && [[ $out == *"editor hung - unity-editor ensure"* ]]'
run dialog "${wait_cmd[@]}"
check dialog   eval '(( code == 4 && took < 12 ))'
run reload "${wait_cmd[@]}"
check reload   eval '(( code == 2 )) && [[ $out != *hung* ]]'
run answered "${wait_cmd[@]}"
check answered eval '(( code == 0 )) && [[ $out == *"compiled clean"* ]]'
run hung "$TMP/scripts/unity-suite" "$PROJ" --filter FooTests
check suite    eval '(( code == 2 )) && [[ $out == *"editor hung - unity-editor ensure"* && $out != *"compiler errors"* && ! -e $TMP/calls ]]'
exit $fail
