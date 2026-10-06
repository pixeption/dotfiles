#!/usr/bin/env bash
# Offline test for bees-split-check: each case writes a plan log in the real line shape
# (`- <date> <time> [<units>] <kind>: …, ctx <n>k`) and asserts the CLI's verdict and exit code.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bees-split-check"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

check() { # check <name> <like> <want-verdict> <want-exit>; the log is stdin
  local log="$TMP/$1.log.md" out code
  cat > "$log"
  out=$("$SCRIPT" --log "$log" --like "$2" 2>&1); code=$?
  if [[ $code == "$4" && $(head -1 <<<"$out") == "$3"* ]]; then echo "ok   $1"
  else echo "FAIL $1 (exit $code, want $4 $3): $out"; fail=1; fi
}
line() { echo "- 2026-10-06 16:00 [$1] $2"; }

check below-line STEP-01 ok 0 < <(line STEP-01 "round: impl r1 bee-opus-medium, done ab12cd34, 20/20, ctx 199,999")
check at-line STEP-01 split 1 < <(line STEP-01 "round: impl r1 bee-opus-medium, done ab12cd34, 20/20, ctx 200k")
check paused-150k STEP-01 split 1 < <(line STEP-01 "round: impl r1 bee-opus-high, paused, 12/30 green, ctx 150k")
check paused-no-ctx STEP-01 split 1 < <(line STEP-01 "accept: Outcome: Paused, successor finished it")
check done-150k STEP-01 ok 0 < <(line STEP-01 "round: impl r1 bee-opus-low, done ab12cd34, ctx 150k")
check unlisted-ignored STEP-01 ok 0 < <({ line STEP-01 "round: impl r1 bee-opus-low, done, ctx 90k"; line STEP-09 "round: impl r1 bee-opus-high, done, ctx 300k"; })
check listed-no-ctx STEP-01,STEP-02 unknown 2 < <({ line STEP-01 "round: impl r1 bee-opus-low, done, ctx 90k"; line STEP-02 "round: impl r1 bee-opus-low, done"; line STEP-02 "accept: 5/5, codex APPROVE"; })
check trigger-beats-missing STEP-02,STEP-01 split 1 < <({ line STEP-01 "round: impl r1 bee-opus-high, done, ctx 268k (retired)"; line STEP-02 "accept: 5/5"; })
check several-below STEP-01,STEP-03 ok 0 < <({ line STEP-01 "round: impl r1 bee-opus-low, done, ctx 44k"; line STEP-02a,STEP-03 "round: impl r1 bee-opus-medium, done, ctx 120k";
  line STEP-03 "review: r1 codex sol, ctx 250k"; line STEP-03 "accept: 9/9, ctx 130k"; })
check only-malformed STEP-01 unknown 2 < <(printf '%s\n' "STEP-01 round ctx 300k" "- [STEP-01 round: paused" "garbage")

exit $fail
