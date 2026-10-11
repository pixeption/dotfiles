#!/usr/bin/env bash
# Offline test for bees-report: runs the CLI on the report shapes under fixtures/ (a Claude review,
# a codex review, a codex implementation out-file with its .usage) and on a throwaway git lane, and
# asserts the lines it must and must not print and its exit code.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bees-report"
FIX="$here/fixtures"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

check() { # check <name> <want-exit> <must-grep> <must-not-grep|-> -- <args>...; must-not reads only the
            # --finding blocks when there are any, so the digest's own lines cannot trip it
  local name=$1 want=$2 must=$3 mustnot=$4 out code; shift 5
  out=$("$SCRIPT" "$@" 2>&1); code=$?
  blocks=$(awk 'f; /^-- findings$/ {f=1}' <<<"$out"); blocks=${blocks:-$out}
  if [[ $code == "$want" ]] && grep -qE -- "$must" <<<"$out" && { [[ $mustnot == - ]] || ! grep -qE -- "$mustnot" <<<"$blocks"; }
  then echo "ok   $name"
  else echo "FAIL $name (exit $code, want $want; must /$must/, not /$mustnot/):"; sed 's/^/     /' <<<"$out"; fail=1; fi
}

check claude-finding-fix 0 'var key = \$"\{view\}/\{theme\}";' 'AC-1 holds' -- --finding MAJ-02 "$FIX/report-claude-review.md"
check claude-finding-stops-at-next 0 'Fix:' 'Delete the comment' -- --finding MAJ-02 "$FIX/report-claude-review.md"
check codex-finding-fix 0 'case \$code in 5\?\?\) retry' 'Print `\$url`' -- --finding F1 "$FIX/review-codex.txt"
check codex-last-finding-stops-at-verdict 0 'Print `\$url` in the failure line\.' 'BEES|CHANGES_REQUIRED' -- --finding F3 "$FIX/review-codex.txt"
check claude-plain-finding-fix 0 'and size the slot, not the root\.' 'MIN-02' -- --finding MAJ-01 "$FIX/report-claude-plain.md"
check claude-plain-finding-code 0 "root\.replaceWith\(slot\); slot\.append\(root\);" - -- --finding MAJ-01 "$FIX/report-claude-plain.md"
check codex-bold-finding-fix 0 'capture\(cell\);' 'F2|Drop the hint' -- --finding F1 "$FIX/review-codex-bold.txt"
check codex-bulleted-finding 0 'Drop the hint for stretch profiles\.' 'BEES|capture\(cell' -- --finding F2 "$FIX/review-codex-bold.txt"
check several-ids 0 'F3 — Low' - -- --finding F1,F3 "$FIX/review-codex.txt"
check missing-id-named 1 'MISSING: F2 not in' - -- --finding F1,F2 "$FIX/review-codex.txt"
check digest-unchanged-without-flags 0 '^### MAJ-02 — Major' 'var key' -- "$FIX/report-claude-review.md"
check digest-sizing 0 '^S: two files changed' - -- "$FIX/impl-codex.txt"
check digest-need-in-combined-heading 0 'keep the 30 s timeout' - -- "$FIX/impl-codex.txt"
check digest-usage-context 0 '^Context: 74,291 tokens' - -- "$FIX/impl-codex.txt"

git -C "$TMP" init -q lane && cd "$TMP/lane" && git config user.email t@t && git config user.name t
echo a > a && git add a && git commit -qm "base" && base=$(git rev-parse HEAD)
echo b > b && git add b && git commit -qm "feat(x): FETCH-01 add b" && echo dirty > a && echo new > c
check lane-commits 0 '^[0-9a-f]+ feat\(x\): FETCH-01 add b$' ' base$' -- --lane "$TMP/lane" --since "$base" "$FIX/impl-codex.txt"
check lane-dirty 0 'dirty: 2 files' - -- --lane "$TMP/lane" --since "$base" "$FIX/impl-codex.txt"
check lane-bad-sha 1 '== lane .*' - -- --lane "$TMP/lane" --since deadbeef "$FIX/impl-codex.txt"
check lane-since-option-refused 1 '== lane ' 'INJECTED' -- --lane "$TMP/lane" --since=--format=format:INJECTED "$FIX/impl-codex.txt"
check lane-needs-since 2 'go together' - -- --lane "$TMP/lane" "$FIX/impl-codex.txt"

exit $fail
