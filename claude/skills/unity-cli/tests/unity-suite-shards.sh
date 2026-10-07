#!/usr/bin/env bash
# Offline test for `unity-suite --shards`: a stub editor binary stands in for the shard runner. A
# missing shard is seeded as a git checkout with the runner installed; the shard reports and the
# explicit tests merge into one report, which also becomes the next run's -timings; a duplicate test
# or a shard without a report fails the run.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/unity-suite"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/src/GameCore"; ROOT="$TMP/shards"
mkdir -p "$SRC/ProjectSettings" "$SRC/Assets/Editor" "$SRC/Packages" "$SRC/Library" "$TMP/home/.unity/bin" "$TMP/Unity.app/Contents/MacOS"
echo "m_EditorVersion: 1.0f1" >"$SRC/ProjectSettings/ProjectVersion.txt"
touch "$SRC/Assets/Editor/Tool.cs" "$SRC/Packages/manifest.json" "$SRC/Library/warm"

cat >"$TMP/home/.unity/bin/unity" <<EOF
#!/usr/bin/env bash
echo '{"data":[{"version":"1.0f1","location":"$TMP/Unity.app"}]}'
EOF
# The stub runner: shard 1 runs A.a, shard 2 runs B.b (A.a too with STUB=dup, nothing with STUB=none).
cat >"$TMP/Unity.app/Contents/MacOS/Unity" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${STUB_ARGS:?}"
while [[ $# -gt 0 ]]; do case $1 in -shard) k=${2%/*}; shift 2;; -shardOut) out=$2; shift 2;; *) shift;; esac; done
[[ $k == 2 && $STUB == none ]] && exit 3
tests=$([[ $k == 1 ]] && echo A.a || echo B.b); [[ $k == 2 && $STUB == dup ]] && tests="B.b A.a"
echo "{\"total\":3,\"explicitTests\":[\"E.x\"],\"tests\":[\"${tests// /\",\"}\"]}" >"$out.plan.json"
{ echo '<test-run duration="1">'; for t in $tests; do echo "<test-case fullname=\"$t\" result=\"Passed\" duration=\"0.5\"/>"; done; echo '</test-run>'; } >"$out"
EOF
chmod +x "$TMP/home/.unity/bin/unity" "$TMP/Unity.app/Contents/MacOS/Unity"

suite() { HOME="$TMP/home" STUB_ARGS="$TMP/args" STUB=$1 "$SCRIPT" "$SRC" --shards 2 --shard-root "$ROOT" --output "$TMP/report.xml" 2>&1; }
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
