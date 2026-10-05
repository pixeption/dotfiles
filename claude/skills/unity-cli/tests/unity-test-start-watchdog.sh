#!/usr/bin/env bash
# Offline test for unity-test's start watchdog: a stub `unity` stands in for the editor.
#   stuck      - the job is `running` and logs "Running N tests" but never "Run started" (the confirmed
#                hang): must restart the editor once, then fail fast, exit 2.
#   retry      - stuck until the editor restarts once, then the run starts: must restart, retry, exit 0.
#   transition - like retry, but the editor writes the global log until the restart and its project
#                log after it: the retry must read the new log, exit 0.
#   queued     - the job sits `queued` and never starts: must not restart, exit 2.
#   unreadable - the job status cannot be read: must not restart, exit 2.
#   normal - the run starts and completes: must print the summary, exit 0.
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -R "$(cd "$(dirname "$0")/.." && pwd)/scripts" "$TMP/scripts"
SCRIPT="$TMP/scripts/unity-test"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/restarts"; touch "%s/Logs/Editor.log"\n' "$TMP" "$TMP/proj" >"$TMP/scripts/unity-editor"
chmod +x "$TMP/scripts/unity-editor"
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$PROJ/Logs" "$TMP/home/.unity/bin" "$TMP/home/Library/Logs/Unity"
touch "$PROJ/ProjectSettings/ProjectVersion.txt" "$PROJ/Logs/Editor.log" "$TMP/home/Library/Logs/Unity/Editor.log"
PROJ=$(cd "$PROJ" && pwd)

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "status "*)             echo '{"data":{"instances":[{"project":"$PROJ"}]}}';;
  "command editor_status") echo '{"data":{"result":{"playMode":"stopped"}}}';;
  "command run_tests")
    log="$PROJ/Logs/Editor.log"; [[ -f \$log ]] || log="$TMP/home/Library/Logs/Unity/Editor.log"
    echo '[PipelineTestRunner] Running 3 tests' >>"\$log"
    [[ \$STUB == normal || ( \$STUB != stuck && -s "$TMP/restarts" ) ]] && echo '[TestResultCollector] Run started: 3 test(s)' >>"\$log"
    echo '{"data":{"jobId":"j1"}}';;
  "job status")
    case \$STUB in queued) echo '{"data":{"state":"queued"}}';; unreadable) echo 'timeout';; *) echo '{"data":{"state":"running"}}';; esac;;
  "job wait")             echo '{"data":{"result":{"FilterApplied":"testName: X","Summary":{"Total":3,"Passed":3,"Failed":0,"Skipped":0}}}}';;
  *)                      echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <name> <want-exit> <want-output-regex> <max-seconds> <want-restarts> <args...>
  local name=$1 want=$2 re=$3 max=$4 restarts_want=$5; shift 5
  local start=$SECONDS out code
  rm -f "$TMP/restarts"
  [[ $name == transition ]] && rm "$PROJ/Logs/Editor.log"
  out=$(STUB=$name HOME="$TMP/home" "$SCRIPT" X --project-path "$PROJ" "$@" 2>&1); code=$?
  local restarts=$(cat "$TMP/restarts" 2>/dev/null | wc -l)
  if [[ $code == "$want" && $out =~ $re && $((SECONDS - start)) -le $max && $restarts -eq $restarts_want ]]; then echo "ok   $name"
  else echo "FAIL $name (exit $code, $((SECONDS - start))s, $restarts restarts): $out"; fail=1; fi
}
check stuck  2 "within 4s; cancellation requested" 20 1 --start-deadline 4
check retry  0 "3/3 passed"                        14 1 --start-deadline 4
check transition 0 "3/3 passed"                    14 1 --start-deadline 4
check queued     2 "within 4s; cancellation requested" 10 0 --start-deadline 4
check unreadable 2 "within 4s; cancellation requested" 10 0 --start-deadline 4
check normal 0 "3/3 passed"                        5  0 --start-deadline 4
exit $fail
