#!/usr/bin/env bash
# Offline test for unity-suite choosing between the open editor and a batch editor, and for
# --output on both paths. Stubs stand in for `unity` and `unity-editor`; unity-test and unity-wait
# are the real scripts. A live run must never touch the editor's lifecycle (no down/up/restart).
#   live      - one term, clean open editor: runs there.
#   union     - two distinct terms: both run, their tests add up.
#   overlap   - a test fails under one term and passes under another: counted once, still failed.
#   clean     - a passing live run exits 0.
#   infra     - a term's job result cannot be read, a stale result from an aborted run lies
#               beside the report: exit 2, editor left open.
#   hang      - a term's run never starts: exit 2, editor neither restarted nor closed.
#   taint     - the first term enters Play: the second never starts, exit 2.
#   nolist    - list_tests does not answer while checking --category: exit 2, nothing runs.
#   full      - no filter: batch.
#   playmode  - --mode PlayMode: batch.
#   played    - the editor's log shows it entered Play this session: batch.
#   foreign   - the editor's log is not provably its own: batch.
#   excluded  - the filter matches a test in the excluded category: batch.
#   closed    - no open editor: batch, nothing to close.
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
    [[ \$STUB == nolist ]] && { echo '{"data":{}}'; exit 0; }
    cat='[]'; [[ \$STUB == excluded ]] && cat='["Integration"]'
    echo '{"data":{"result":{"Tests":[{"FullName":"N.FooTests.A","Categories":[]},{"FullName":"N.FooTests.B","Categories":'"\$cat"'},{"FullName":"N.BarTests.C","Categories":[]},{"FullName":"N.BazTests.D","Categories":["Integration"]}]}}}';;
  "command run_tests")
    while [[ \$# -gt 0 ]]; do [[ \$1 == --filter ]] && echo "\$2" >"$TMP/filter"; shift; done
    echo "run_tests \$(cat "$TMP/filter")" >>"$TMP/calls"
    echo '[PipelineTestRunner] Running 2 tests' >>"$LOG"
    [[ \$STUB == hang ]] || echo '[TestResultCollector] Run started: 2 test(s)' >>"$LOG"
    [[ \$STUB == taint ]] && echo 'Entering Playmode with Reload Domain disabled.' >>"$LOG"
    echo '{"data":{"jobId":"j1"}}';;
  "job status") [[ \$STUB == hang ]] && echo '{"data":{"state":"running"}}' || echo '{"data":{"state":"completed"}}';;
  "job wait")
    [[ \$STUB == infra ]] && { echo '{"data":{}}'; exit 0; }
    f=\$(cat "$TMP/filter")
    case \$f in
      FooTests) r='{"FullName":"N.FooTests.A","Status":"Passed"},{"FullName":"N.FooTests.B","Status":"Failed","Message":"boom"}';;
      N.Foo)    r='{"FullName":"N.FooTests.A","Status":"Passed"},{"FullName":"N.FooTests.B","Status":"Passed"}';;
      BarTests) r='{"FullName":"N.BarTests.C","Status":"Passed"}';;
    esac
    echo '{"data":{"result":{"FilterApplied":"testName: '"\$f"'","Summary":{"Total":1},"Results":['"\$r"']}}}';;
  "test "*)
    echo test >>"$TMP/calls"
    while [[ \$# -gt 0 ]]; do [[ \$1 == --output ]] && out=\$2; shift; done
    echo '<test-run total="3" passed="3" failed="0" skipped="0"/>' >"\$out";;
  *) echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/scripts/unity-editor" "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <stub> <want-path live|batch> <want-exit> <want-live-runs> <want-count-line or ""> <args...>
  local stub=$1 path=$2 exit=$3 runs=$4 count=$5; shift 5
  local report="$TMP/out/$stub/report.xml" out code got ran
  rm -f "$TMP/calls" "$TMP/editor-calls"
  if [[ $stub == foreign ]]; then printf 'header\n/elsewhere\n' >"$LOG"; else printf 'header\n%s\n' "$PROJ" >"$LOG"; fi
  [[ $stub == played ]] && echo 'Entering Playmode with Reload Domain disabled.' >>"$LOG"
  mkdir -p "$(dirname "$report")"
  [[ $stub == infra ]] && echo '{"Results":[{"FullName":"N.BarTests.C","Status":"Passed"}]}' >"$report.0.json"
  out=$(STUB=$stub HOME="$TMP/home" UNITY_WAIT_SETTLE=10 UNITY_TEST_START_DEADLINE=3 \
        "$TMP/scripts/unity-suite" "$PROJ" --output "$report" "$@" 2>&1); code=$?
  got=$(grep -q '^test$' "$TMP/calls" 2>/dev/null && echo batch || echo live)
  [[ $got == live && -s $TMP/editor-calls ]] && got="live+lifecycle($(tr '\n' ' ' <"$TMP/editor-calls"))"
  ran=$(grep -c '^run_tests' "$TMP/calls" 2>/dev/null); ran=${ran:-0}
  if [[ $got == "$path" && $code == "$exit" && ( $path == batch || $ran == "$runs" ) \
        && ( -z $count || ( $out == *"$count"* && $out == *"report: $report"* && -s $report ) ) ]]; then echo "ok   $stub"
  else echo "FAIL $stub (path $got, exit $code, $ran live runs): $out"; fail=1; fi
}
check live     live  1 1 "1/2 passed, 1 failed" --filter FooTests --category '!Integration'
check union    live  1 2 "2/3 passed, 1 failed" --filter 'FooTests|BarTests' --category '!Integration'
check overlap  live  1 2 "1/2 passed, 1 failed" --filter 'FooTests|N.Foo' --category '!Integration'
check clean    live  0 1 "1/1 passed, 0 failed" --filter BarTests
check infra    live  2 1 ""                     --filter BarTests
check hang     live  2 1 ""                     --filter BarTests
check taint    live  2 1 ""                     --filter 'FooTests|BarTests'
check nolist   live  2 0 ""                     --filter FooTests --category '!Integration'
check full     batch 0 0 "3/3 passed"           --category '!Integration'
check playmode batch 0 0 "3/3 passed"           --filter FooTests --mode PlayMode
check played   batch 0 0 "3/3 passed"           --filter FooTests --category '!Integration'
check foreign  batch 0 0 "3/3 passed"           --filter FooTests
check excluded batch 0 0 "3/3 passed"           --filter FooTests --category '!Integration'
check closed   batch 0 0 "3/3 passed"           --filter FooTests
exit $fail
