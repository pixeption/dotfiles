#!/usr/bin/env bash
# Offline test for unity-suite choosing between the open editor and a batch editor, and for
# --output on both paths. Stubs stand in for `unity` and `unity-editor`; unity-test and unity-wait
# are the real scripts.
#   live         - filtered Edit-Mode run, clean open editor: runs there, never closes it.
#   live-dedupe  - two filter terms matching the same tests: each test is counted once.
#   full         - no filter: batch.
#   playmode     - --mode PlayMode: batch.
#   played       - the editor's log shows it entered Play this session: batch.
#   excluded     - the filter matches a test in the excluded category: batch.
#   closed       - no open editor: batch, nothing to close.
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -R "$(cd "$(dirname "$0")/.." && pwd)/scripts" "$TMP/scripts"
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$PROJ/Logs" "$TMP/home/.unity/bin" "$TMP/home/Library/Logs/Unity"
touch "$PROJ/ProjectSettings/ProjectVersion.txt" "$TMP/home/Library/Logs/Unity/Editor.log"
PROJ=$(cd "$PROJ" && pwd)
LOG="$PROJ/Logs/Editor.log"

cat >"$TMP/scripts/unity-editor" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$TMP/editor-calls"
EOF
cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "status "*) [[ \$STUB == closed ]] && echo '{"data":{"instances":[]}}' || echo '{"data":{"instances":[{"project":"$PROJ"}]}}';;
  "command editor_status")    echo '{"data":{"result":{"status":"ready","playMode":"stopped"}}}';;
  "command recompile_status") echo '{"data":{"result":{"status":"up_to_date","failed":false}}}';;
  "command list_open_scenes") echo '{"data":{"result":{"scenes":[]}}}';;
  "command list_tests")
    cat='[]'; [[ \$STUB == excluded ]] && cat='["Integration"]'
    echo '{"data":{"result":{"Tests":[{"FullName":"N.FooTests.A","Mode":"EditMode","Categories":[]},{"FullName":"N.FooTests.B","Mode":"EditMode","Categories":'"\$cat"'},{"FullName":"N.BarTests.C","Mode":"EditMode","Categories":["Integration"]}]}}}';;
  "command run_tests")
    echo run_tests >>"$TMP/calls"
    while [[ \$# -gt 0 ]]; do [[ \$1 == --filter ]] && echo "\$2" >"$TMP/filter"; shift; done
    echo '[TestResultCollector] Run started: 2 test(s)' >>"$LOG"
    echo '{"data":{"jobId":"j1"}}';;
  "job status") echo '{"data":{"state":"completed"}}';;
  "job wait")
    echo '{"data":{"result":{"FilterApplied":"testName: '"\$(cat "$TMP/filter")"'","Summary":{"Total":2,"Passed":1,"Failed":1,"Skipped":0},"Results":[{"FullName":"N.FooTests.A","Status":"Passed"},{"FullName":"N.FooTests.B","Status":"Failed","Message":"boom"}]}}}';;
  "test "*)
    echo test >>"$TMP/calls"
    while [[ \$# -gt 0 ]]; do [[ \$1 == --output ]] && out=\$2; shift; done
    echo '<test-run total="3" passed="3" failed="0" skipped="0"/>' >"\$out";;
  *) echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/scripts/unity-editor" "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <stub> <want-path live|batch> <want-count-line> <args...>
  local stub=$1 path=$2 count=$3; shift 3
  local report="$TMP/out/$stub/report.xml" out code got
  rm -f "$TMP/calls" "$TMP/editor-calls"
  printf 'header\n%s\n' "$PROJ" >"$LOG"
  [[ $stub == played ]] && echo 'Entering Playmode with Reload Domain disabled.' >>"$LOG"
  out=$(STUB=$stub HOME="$TMP/home" UNITY_WAIT_SETTLE=10 "$TMP/scripts/unity-suite" "$PROJ" --output "$report" "$@" 2>&1); code=$?
  got=$(grep -q run_tests "$TMP/calls" 2>/dev/null && echo live || echo batch)
  [[ $path == live ]] && grep -q down "$TMP/editor-calls" 2>/dev/null && got="live+closed"
  if [[ $got == "$path" && $out == *"$count"* && $out == *"report: $report"* && -s $report ]]; then echo "ok   $stub"
  else echo "FAIL $stub (path $got, exit $code): $out"; fail=1; fi
}
check live        live  "1/2 passed, 1 failed" --filter FooTests --category '!Integration'
check live-dedupe live  "1/2 passed, 1 failed" --filter 'FooTests|N.Foo' --category '!Integration'
check full        batch "3/3 passed"           --category '!Integration'
check playmode    batch "3/3 passed"           --filter FooTests --mode PlayMode
check played      batch "3/3 passed"           --filter FooTests --category '!Integration'
check excluded    batch "3/3 passed"           --filter FooTests --category '!Integration'
check closed      batch "3/3 passed"           --filter FooTests
exit $fail
