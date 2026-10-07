#!/usr/bin/env bash
# Offline test for `unity-suite --shards`: a stub editor binary stands in for the shard runner. A
# missing shard is seeded as a git checkout with the runner installed; the shard reports and the
# explicit tests merge into one report, which also becomes the next run's -timings. A duplicate
# test, a shard without a report, shards listing different tests, a crashed or hung shard editor, a
# failed suite and an occupied shard fail the run; stopping the run stops its editors.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/unity-suite"
TMP=$(mktemp -d); trap 'pkill -KILL -f "$TMP/" 2>/dev/null; rm -rf "$TMP"' EXIT
SRC="$TMP/src/GameCore"; ROOT="$TMP/shards (1)+"
mkdir -p "$SRC/ProjectSettings" "$SRC/Assets/Editor" "$SRC/Packages" "$SRC/Library" "$TMP/home/.unity/bin" "$TMP/Unity.app/Contents/MacOS"
echo "m_EditorVersion: 1.0f1" >"$SRC/ProjectSettings/ProjectVersion.txt"
touch "$SRC/Assets/Editor/Tool.cs" "$SRC/Packages/manifest.json" "$SRC/Library/warm"

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
echo '{"data":[{"version":"1.0f1","location":"$TMP/Unity.app"}]}'
EOF
# The stub runner: shard 1 runs A.a, shard 2 runs B.b. STUB picks shard 2's misbehaviour: dup also
# runs A.a, none writes nothing, drift lists and runs C.c in place of B.b, unplanned runs X.y in
# place of B.b, crash and exit2 exit 3 and 2 after a passing report, hang never ends and ignores
# SIGTERM; suitefail fails shard 1's suite in its teardown; dupexplicit lists E.x twice.
cat >"$TMP/Unity.app/Contents/MacOS/Unity" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${STUB_ARGS:?}"
while [[ $# -gt 0 ]]; do case $1 in -shard) k=${2%/*}; shift 2;; -shardOut) out=$2; shift 2;; *) shift;; esac; done
if [[ $k == 2 ]]; then
  case $STUB in
    none) exit 3;;
    hang) trap '' TERM; while :; do sleep 1; done;;
  esac
fi
tests=$([[ $k == 1 ]] && echo A.a || echo B.b); all='"A.a","B.b","E.x"' explicit='"E.x"' total=3
[[ $k == 2 && $STUB == dup ]] && tests="B.b A.a"
[[ $k == 2 && $STUB == drift ]] && { tests=C.c; all='"A.a","C.c","E.x"'; }
[[ $STUB == dupexplicit ]] && { all='"A.a","B.b","E.x","E.x"' explicit='"E.x","E.x"' total=4; }
echo "{\"total\":$total,\"allTests\":[$all],\"explicitTests\":[$explicit],\"tests\":[\"${tests// /\",\"}\"]}" >"$out.plan.json"
[[ $k == 2 && $STUB == unplanned ]] && tests=X.y
suite=Passed; [[ $k == 1 && $STUB == suitefail ]] && suite='Failed" site="TearDown'
{ echo "<test-run duration=\"1\"><test-suite fullname=\"S$k\" result=\"$suite\"><failure><message>teardown threw</message></failure>"
  for t in $tests; do echo "<test-case fullname=\"$t\" result=\"Passed\" duration=\"0.5\"/>"; done
  echo '</test-suite></test-run>'; } >"$out"
[[ $k == 2 && $STUB == crash ]] && exit 3
[[ $k == 2 && $STUB == exit2 ]] && exit 2
exit 0
EOF
chmod +x "$TMP/home/.unity/bin/unity" "$TMP/Unity.app/Contents/MacOS/Unity"

run() { HOME="$TMP/home" STUB_ARGS="$TMP/args" STUB=$1 exec "$SCRIPT" "$SRC" --shards 2 --shard-root "$ROOT" --output "$TMP/report.xml" "${@:2}"; }
suite() { run "$@" 2>&1; }
editors() { pgrep -f "$TMP/Unity.app" >/dev/null; }
fail() { echo "FAIL $1"; printf '%s\n' "$out"; exit 1; }

out=$(suite ok); code=$?
[[ $code == 0 && $out == *"2/3 passed, 0 failed, 1 skipped"* ]] || fail "merged run (exit $code)"
grep -q 'fullname="E.x" name="E.x" result="Skipped" label="Explicit"' "$TMP/report.xml" || fail "explicit test in the report"
echo "ok   two shards and an explicit test merge into one report"
[[ -d "$ROOT/shard-2/.git" && -f "$ROOT/shard-2/GameCore/Library/warm" && -f "$ROOT/shard-2/GameCore/Assets/Editor/Tool.cs" \
   && -f "$ROOT/shard-2/GameCore/Assets/Editor/ShardRunner/ShardRunner.cs" ]] || fail "seeded shard layout"
echo "ok   a missing shard is seeded: git checkout, cloned Library, synced sources, runner installed"
grep -q -- '-timings' "$TMP/args" && fail "first run passed -timings"
rm "$TMP/args" "$SRC/Assets/Editor/Tool.cs"
out=$(suite ok) || fail "second run"
grep -q -- "-timings $ROOT/timings.xml" "$TMP/args" || fail "second run did not time from the last report"
[[ ! -e "$ROOT/shard-1/GameCore/Assets/Editor/Tool.cs" && -f "$ROOT/shard-1/GameCore/Assets/Editor/ShardRunner/ShardRunner.cs" ]] \
  || fail "resync deletes removed sources and keeps the runner"
echo "ok   the next run times its split from the last report, and resync keeps the runner"

out=$(suite dup); code=$?
[[ $code == 2 && $out == *"duplicate: A.a in shards 1 and 2"* ]] || fail "duplicate (exit $code)"
echo "ok   a test run by two shards fails the run"
out=$(suite none); code=$?
[[ $code == 2 && $out == *"shard 2 wrote no report"* ]] || fail "missing report (exit $code)"
echo "ok   a shard without a report fails the run"

out=$(suite drift); code=$?
[[ $code == 2 && $out == *"shard 2: its test list differs from shard 1's"* ]] || fail "same-count test list drift (exit $code)"
echo "ok   shards that list different tests of the same count fail the run"
out=$(suite unplanned); code=$?
[[ $code == 2 && $out == *"unplanned tests ran: ['X.y']"* ]] || fail "unplanned test (exit $code)"
echo "ok   a shard that ran a test it did not plan fails the run"
out=$(suite dupexplicit); code=$?
[[ $code == 2 && $out == *"shard 1: invalid or duplicate test inventory"* ]] || fail "duplicate explicit test (exit $code)"
echo "ok   a test listed twice fails the run, even an explicit one"
out=$(suite exit2); code=$?
[[ $code == 1 ]] || fail "test-failure exit with a passing report (exit $code)"
echo "ok   a shard editor reporting a test failure fails the run, though its report passed"
out=$(suite crash); code=$?
[[ $code == 2 && $out == *"crashed or timed out"* ]] || fail "crash after the report (exit $code)"
echo "ok   a shard editor that crashes after writing its report fails the run"
start=$SECONDS; out=$(suite hang --timeout 2); code=$?
[[ $code == 2 && $out == *"shard 2 timed out after 2s"* ]] && (( SECONDS - start < 8 )) && ! editors \
  || fail "hung editor that ignores SIGTERM (exit $code, $((SECONDS - start)) s)"
echo "ok   a hung shard editor is killed at the timeout and fails the run"
out=$(suite suitefail); code=$?
[[ $code == 1 && $out == *"FAIL S1"* && $out == *"teardown threw"* ]] || fail "suite-only failure (exit $code)"
echo "ok   a suite that fails in its teardown fails the run, though its tests passed"

run hang >/dev/null 2>&1 & pid=$!
for _ in {1..50}; do editors && break; sleep 0.1; done
kill -TERM "$pid"; wait "$pid"; sleep 1
editors && { out="editor still running after the run was stopped"; fail "termination cleanup"; }
echo "ok   stopping the run stops its shard editors"

mkdir -p "$TMP/held"; printf '#!/usr/bin/env bash\nsleep 30\n' >"$TMP/held/Unity"; chmod +x "$TMP/held/Unity"
"$TMP/held/Unity" -batchmode -projectPath "$ROOT/shard-1/GameCore" -logFile x & held=$!
out=$(suite ok); code=$?; kill "$held"
[[ $code != 0 && $out == *"shard-1/GameCore is held by a running editor"* ]] || fail "occupied shard (exit $code)"
echo "ok   a shard held by a batch editor is refused, its path read literally, not as a regex"
