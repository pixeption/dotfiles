#!/usr/bin/env bash
# Offline test for bees-watch --dir history: a failed round of an accepted unit is flagged or hidden
# by its role — an impl round once the log has `[<unit>] accept:`, a review round only once it has
# `[<unit>] review:`, since the review starts after accept. --url points at a closed port, so no
# server is read.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bees-watch"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
W="$TMP/p.work"; LOG="$TMP/p.log.md"; mkdir "$W"
fail=0

failed_round() { : > "$W/$1"; echo '{}' > "$W/$1.usage"; : > "$W/$1.log"; }
check() { # check <name> <want-exit> <must-grep> <log line>...
  local name=$1 want=$2 must=$3 out code; shift 3
  printf '%s\n' "$@" > "$LOG"
  out=$("$SCRIPT" --dir "$W" --url http://127.0.0.1:9 2>&1); code=$?
  if [[ $code == "$want" ]] && grep -qE -- "$must" <<<"$out"
  then echo "ok   $name"
  else echo "FAIL $name (exit $code, want $want; must /$must/):"; sed 's/^/     /' <<<"$out"; fail=1; fi
}

failed_round review-X-r1.txt
check review-flagged-after-accept 1 '^review-X-r1\.txt: failed' '- [X] accept: 3 green'
check review-hidden-after-review-line 0 'hidden' '- [X] accept: 3 green' '- [X] review: abc123 clean (review-X-r1.txt)'

rm "$W"/review-X-r1.txt*; failed_round impl-X-r1.txt
check impl-hidden-after-accept 0 'hidden' '- [X] accept: 3 green'
check impl-flagged-without-accept 1 '^impl-X-r1\.txt: failed' '- [X] decision: none'

exit $fail
