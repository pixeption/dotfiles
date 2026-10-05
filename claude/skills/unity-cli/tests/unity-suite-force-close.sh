#!/usr/bin/env bash
# Offline test for unity-suite closing the live editor; stubs stand in for `unity` and `unity-editor`.
#   unreachable - the polite close fails and the editor does not answer: must force-close and run.
#   answering   - the polite close fails but the editor answers: must refuse, exit 2, no force.
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -R "$(cd "$(dirname "$0")/.." && pwd)/scripts" "$TMP/scripts"
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$TMP/home/.unity/bin"
touch "$PROJ/ProjectSettings/ProjectVersion.txt"
PROJ=$(cd "$PROJ" && pwd)

cat >"$TMP/scripts/unity-editor" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$TMP/editor-calls"
[[ \$1 != down || \$* == *--force* ]]
EOF
cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "status "*)                 echo '{"data":{"instances":[{"project":"$PROJ"}]}}';;
  "command editor_status")    [[ \$STUB == answering ]] && echo '{"data":{"result":{"playMode":"stopped"}}}' || echo '{"data":{}}';;
  "command list_open_scenes") echo '{"data":{"result":{"scenes":[]}}}';;
  "test "*)
    while [[ \$# -gt 0 ]]; do [[ \$1 == --output ]] && out=\$2; shift; done
    echo '<test-run total="1" passed="1" failed="0" skipped="0"/>' >"\$out";;
  *)                          echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/scripts/unity-editor" "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <stub> <want-exit> <want-force-closes>
  local out code forced
  rm -f "$TMP/editor-calls"
  out=$(STUB=$1 HOME="$TMP/home" "$TMP/scripts/unity-suite" "$PROJ" 2>&1); code=$?
  forced=$(grep -cF -- "down $PROJ --force" "$TMP/editor-calls")
  if [[ $code == "$2" && $forced == "$3" ]]; then echo "ok   $1"
  else echo "FAIL $1 (exit $code, $forced force-closes): $out"; fail=1; fi
}
check unreachable 0 1
check answering   2 0
exit $fail
