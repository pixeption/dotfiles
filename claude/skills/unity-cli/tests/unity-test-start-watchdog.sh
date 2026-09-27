#!/usr/bin/env bash
# Offline test for unity-test's start watchdog: a stub `unity` stands in for the editor.
#   stuck  - run_tests is accepted, the job sits `queued`, no "Run started" is ever logged: must fail fast, exit 2.
#   normal - the run starts and completes: must print the summary, exit 0.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/unity-test"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; mkdir -p "$PROJ/ProjectSettings" "$PROJ/Logs" "$TMP/home/.unity/bin"
touch "$PROJ/ProjectSettings/ProjectVersion.txt" "$PROJ/Logs/Editor.log"
PROJ=$(cd "$PROJ" && pwd)

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "status "*)             echo '{"data":{"instances":[{"project":"$PROJ"}]}}';;
  "command editor_status") echo '{"data":{"result":{"playMode":"stopped"}}}';;
  "command run_tests")
    [[ \$STUB == normal ]] && echo '[TestResultCollector] Run started: 3 test(s)' >>"$PROJ/Logs/Editor.log"
    echo '{"data":{"jobId":"j1"}}';;
  "job status")           echo '{"data":{"state":"queued"}}';;
  "job wait")             echo '{"data":{"result":{"FilterApplied":"testName: X","Summary":{"Total":3,"Passed":3,"Failed":0,"Skipped":0}}}}';;
  *)                      echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/home/.unity/bin/unity"

fail=0
check() { # check <name> <want-exit> <want-output-regex> <max-seconds> <args...>
  local name=$1 want=$2 re=$3 max=$4; shift 4
  local start=$SECONDS out code
  out=$(STUB=$name HOME="$TMP/home" "$SCRIPT" X --project-path "$PROJ" "$@" 2>&1); code=$?
  if [[ $code == "$want" && $out =~ $re && $((SECONDS - start)) -le $max ]]; then echo "ok   $name"
  else echo "FAIL $name (exit $code, $((SECONDS - start))s): $out"; fail=1; fi
}
check stuck  2 "within 4s; cancellation requested" 12 --start-deadline 4
check normal 0 "3/3 passed"                    5  --start-deadline 4
exit $fail
