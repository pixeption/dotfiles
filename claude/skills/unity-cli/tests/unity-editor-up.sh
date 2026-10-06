#!/usr/bin/env bash
# Offline test for unity-editor's launch; a stub stands in for `unity`, and a sleeping bash named
# "Unity -projectpath <proj> <args>" stands in for the editor process. The stub splits --args the way
# `unity open` does (shell rules), and the project path holds a space.
#   headless - up opens -batchmode -automated, logging to <proj>/Logs/Editor.log; exit 0.
#   windowed - up --windowed opens -automated alone; exit 0.
#   compile  - the headless editor logs `error CS` to its -logFile and exits: up prints the
#              errors, exit 1.
#   restart  - restart of a running windowed editor relaunches it windowed.
set -uo pipefail
TMP=$(mktemp -d)
trap 'pkill -f "Unity -projectpath $TMP/" 2>/dev/null; rm -rf "$TMP"' EXIT
cp -R "$(cd "$(dirname "$0")/.." && pwd)/scripts" "$TMP/scripts"
PROJ="$TMP/my proj"; mkdir -p "$PROJ/ProjectSettings" "$TMP/home/.unity/bin" "$TMP/home/Library/Logs/Unity"
touch "$PROJ/ProjectSettings/ProjectVersion.txt"
PROJ=$(cd "$PROJ" && pwd)
ERR='Assets/Foo.cs(3,1): error CS1002: ; expected'

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
alive() { pgrep -f "Unity -projectpath $PROJ " >/dev/null; }
case "\$1 \$2" in
  "open "*)
    while [[ \$# -gt 0 ]]; do [[ \$1 == --args ]] && args=\$2; shift; done
    python3 -c 'import shlex, sys; print("|".join(shlex.split(sys.argv[1])))' "\$args" >>"$TMP/opens"
    log=\$(python3 -c 'import shlex, sys; a = shlex.split(sys.argv[1]); print(a[a.index("-logFile") + 1] if "-logFile" in a else sys.argv[2])' "\$args" "$PROJ/Logs/Editor.log")
    sleep 1; printf '%s\n' "$PROJ" >"\$log"
    if [[ \$STUB == compile ]]; then printf '%s\n' "$ERR" 'Scripts have compiler errors.' >>"\$log"
    else nohup bash -c 'sleep 60; :' "Unity -projectpath $PROJ \$args" >/dev/null 2>&1 & fi;;
  "close "*) pkill -f "Unity -projectpath $PROJ "; sleep 0.2;;
  "status "*) alive && echo '{"data":{"instances":[{"project":"$PROJ"}]}}' || echo '{"data":{"instances":[]}}';;
  "command editor_status") alive && echo '{"data":{"result":{"playMode":"stopped"}}}' || echo '{"data":{}}';;
  "command list_open_scenes") echo '{"data":{"result":{"scenes":[{"name":"","path":"","isActive":true,"rootCount":0}]}}}';;
  *) echo '{"data":{"result":{}}}';;
esac
EOF
chmod +x "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <stub> <want-exit> <want-launch-args> <want-in-output> <unity-editor args...>
  local out code
  rm -f "$TMP/opens"
  out=$(STUB=$1 HOME="$TMP/home" "$TMP/scripts/unity-editor" "${@:5}" 2>&1); code=$?
  if [[ $code == "$2" && "$(tail -1 "$TMP/opens")" == "$3" && "$out" == *"$4"* ]]; then echo "ok   $1"
  else echo "FAIL $1 (exit $code, launched [$(tail -1 "$TMP/opens")]): $out"; fail=1; fi
  pkill -f "Unity -projectpath $PROJ "; sleep 0.2
}
HEADLESS="-batchmode|-automated|-logFile|$PROJ/Logs/Editor.log"
check headless 0 "$HEADLESS"   "active scene: (untitled)" up "$PROJ"
check windowed 0 "-automated"  "active scene: (untitled)" up "$PROJ" --windowed
check compile  1 "$HEADLESS"   "$ERR"                     up "$PROJ"

nohup bash -c 'sleep 60; :' "Unity -projectpath $PROJ -automated" >/dev/null 2>&1 &
sleep 0.2
check restart  0 "-automated"  "active scene: (untitled)" restart "$PROJ"
exit $fail
