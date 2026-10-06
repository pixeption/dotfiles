#!/usr/bin/env bash
# Offline test for unity-test's start watchdog: a stub `unity` stands in for the editor.
#   stuck      - the job is `running` and logs "Running N tests" but never "Run started" (the confirmed
#                hang): must restart the editor once, then fail fast, exit 2; with --no-restart, exit 2
#                without restarting.
#   retry      - stuck until the editor restarts once, then the run starts: must restart, retry, exit 0.
#   transition - like retry, but the editor writes the global log until the restart and its project
#                log after it: the retry must read the new log, exit 0.
#   queued     - the job sits `queued` and never starts: must not restart, exit 2.
#   unreadable - the job status cannot be read: must not restart, exit 2.
#   normal - the run starts and completes: must print the summary, exit 0.
#   retry-big, normal-big - as retry and normal, with ~1 MB of editor output after the markers, which a
#                grep -q under pipefail would misread as no match (SIGPIPE in tail).
#   untitled   - the active untitled scene is dirty, so the framework's save prompt would cancel the run:
#                it must be replaced by an empty scene first, then the run starts, exit 0.
#   titled     - a titled scene is dirty: it must be left alone (no eval), and the hang names the
#                cancelled dialog, the scene and unity-editor ensure, without restarting, exit 2.
#   other      - as untitled, with a saved scene also open: it must stay open, exit 0.
#   race       - a saved scene becomes the dirty active scene between the check and the replacement:
#                its changes must survive, exit 2 before any run.
#   evalfail   - the replacement fails: exit 2 before any run.
#   noscenes   - the open scenes cannot be read: exit 2 before any run.
#   verifyfail - the open scenes cannot be read after the replacement: exit 2 before any run.
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
S=\${STUB%-big}
dirty() { python3 "$TMP/scenes.py" dirty; }
case "\$1 \$2" in
  "command list_open_scenes") python3 "$TMP/scenes.py" list;;
  "command eval") echo eval >>"$TMP/evals"; while [[ \$1 != --code ]]; do shift; done; python3 "$TMP/scenes.py" eval "\$2";;
  "status "*)             echo '{"data":{"instances":[{"project":"$PROJ"}]}}';;
  "command editor_status") echo '{"data":{"result":{"playMode":"stopped"}}}';;
  "command run_tests")
    log="$PROJ/Logs/Editor.log"; [[ -f \$log ]] || log="$TMP/home/Library/Logs/Unity/Editor.log"
    echo '[PipelineTestRunner] Running 3 tests' >>"\$log"
    if dirty; then echo 'Canceling DisplayDialog: Scene(s) Have Been Modified Do you want to save the changes' >>"\$log"
    elif [[ \$S =~ ^(normal|untitled|other)\$ || ( \$S != stuck && -s "$TMP/restarts" ) ]]; then
      echo '[TestResultCollector] Run started: 3 test(s)' >>"\$log"
    fi
    [[ \$STUB == *-big ]] && head -c 1000000 /dev/zero | tr '\\0' x >>"\$log"
    [[ -s "$TMP/restarts" ]] && echo '{"data":{"jobId":"j2"}}' || echo '{"data":{"jobId":"j1"}}';;
  "job status")
    case \$S in queued) echo '{"data":{"state":"queued"}}';; unreadable) echo 'timeout';; *) echo '{"data":{"state":"running"}}';; esac;;
  "job wait")             [[ -s "$TMP/restarts" && \$3 != j2 ]] && { echo '{"data":{}}'; exit 0; }
                          echo '{"data":{"result":{"FilterApplied":"testName: X","Summary":{"Total":3,"Passed":3,"Failed":0,"Skipped":0}}}}';;
  *)                      echo '{"data":{}}';;
esac
EOF
chmod +x "$TMP/home/.unity/bin/unity"

# The editor's open scenes, kept in $TMP/scenes.json. `eval` models the C# it is sent: NewScene
# Single closes every open scene, Additive plus CloseScene only the old active one, and the
# untitled-path guard throws (exit 1) when the active scene is no longer an untitled dirty one.
cat >"$TMP/scenes.py" <<'PY'
import json, os, sys
stub, tmp = os.environ["STUB"], os.path.dirname(os.path.abspath(__file__))
path = os.path.join(tmp, "scenes.json")
scenes = json.load(open(path))
save = lambda: json.dump(scenes, open(path, "w"))
active = lambda: next(s for s in scenes if s["isActive"])
cmd = sys.argv[1]
if cmd == "dirty": sys.exit(0 if any(s["isDirty"] for s in scenes) else 1)
if cmd == "list":
    unreadable = stub == "noscenes" or (stub == "verifyfail" and os.path.exists(os.path.join(tmp, "evals-done")))
    print('{"data":{}}' if unreadable else json.dumps({"data": {"result": {"scenes": scenes}}})); sys.exit()
code = sys.argv[2]
if stub == "evalfail": sys.exit(1)
if stub == "race":
    scenes[:] = [{"path": "Assets/Scenes/Work.unity", "isActive": True, "isDirty": True}]
if "string.IsNullOrEmpty(scene.path)" in code and (active()["path"] or not active()["isDirty"]): sys.exit(1)
lost = [s["path"] for s in scenes if s["isDirty"] and s["path"]]
if "NewSceneMode.Single" in code:
    open(os.path.join(tmp, "lost"), "a").write(" ".join(lost))
    scenes[:] = []
else:
    scenes.remove(active())
    for s in scenes: s["isActive"] = False
scenes.append({"path": "", "isActive": True, "isDirty": False})
open(os.path.join(tmp, "evals-done"), "w").close()
save()
print('{"data":{"result":null}}')
PY
scenes_for() {
  local scenes='{"path":"","isActive":true,"isDirty":false}'
  case $1 in
    untitled|race|evalfail|verifyfail) scenes='{"path":"","isActive":true,"isDirty":true}';;
    titled) scenes='{"path":"Assets/Scenes/Work.unity","isActive":true,"isDirty":true}';;
    other) scenes='{"path":"","isActive":true,"isDirty":true},{"path":"Assets/Scenes/Menu.unity","isActive":false,"isDirty":false}';;
  esac
  echo "[$scenes]"
}

fail=0
check() { # check <name> <want-exit> <want-output-regex> <max-seconds> <want-restarts> <args...>
  local name=$1 want=$2 re=$3 max=$4 restarts_want=$5; shift 5
  local start=$SECONDS out code
  rm -f "$TMP/restarts" "$TMP/evals" "$TMP/evals-done" "$TMP/lost"
  scenes_for "${name%-big}" >"$TMP/scenes.json"
  [[ $name == transition ]] && rm "$PROJ/Logs/Editor.log"
  out=$(STUB=$name HOME="$TMP/home" "$SCRIPT" X --project-path "$PROJ" "$@" 2>&1); code=$?
  local restarts=$(cat "$TMP/restarts" 2>/dev/null | wc -l)
  if [[ $code == "$want" && $out =~ $re && $((SECONDS - start)) -le $max && $restarts -eq $restarts_want ]]; then echo "ok   $name"
  else echo "FAIL $name (exit $code, $((SECONDS - start))s, $restarts restarts): $out"; fail=1; fi
}
check stuck  2 "within 4s; cancellation requested" 20 1 --start-deadline 4
check retry  0 "3/3 passed"                        14 1 --start-deadline 4
check transition 0 "3/3 passed"                    14 1 --start-deadline 4
check stuck  2 "editor left alone .--no-restart."  10 0 --start-deadline 4 --no-restart
check queued     2 "within 4s; cancellation requested" 10 0 --start-deadline 4
check unreadable 2 "within 4s; cancellation requested" 10 0 --start-deadline 4
check normal 0 "3/3 passed"                        5  0 --start-deadline 4
check retry-big  0 "3/3 passed"                    14 1 --start-deadline 4
check normal-big 0 "3/3 passed"                    5  0 --start-deadline 4
check untitled   0 "3/3 passed"                    5  0 --start-deadline 4
check titled 2 "'Scene.s. Have Been Modified' dialog.*Assets/Scenes/Work.unity has unsaved changes.*unity-editor ensure" 10 0 --start-deadline 4
[[ -e $TMP/evals ]] && { echo "FAIL titled: the user's dirty titled scene was replaced"; fail=1; }
check other      0 "3/3 passed"                    5  0 --start-deadline 4
grep -q Menu.unity "$TMP/scenes.json" || { echo "FAIL other: the saved scene was closed"; fail=1; }
check race       2 "could not safely replace"      5  0 --start-deadline 4
[[ -s $TMP/lost ]] && { echo "FAIL race: discarded $(cat "$TMP/lost")"; fail=1; }
check evalfail   2 "could not safely replace"      5  0 --start-deadline 4
check noscenes   2 "could not inspect open scenes" 5  0 --start-deadline 4
check verifyfail 2 "could not inspect open scenes" 5  0 --start-deadline 4
exit $fail
