#!/usr/bin/env bash
# Offline test for bees-brief: builds briefs through its CLI from a throwaway plan (plan mode) or a
# work dir (light mode, --work) and asserts the standing rules each role receives, by one stable key
# phrase per read-hygiene rule (counted once each, line wraps ignored), and the plan-section pointers.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bees-brief"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

SKILL="Invoke a skill's entry point once with the Skill tool"
SECTION="Start from the unit-section pointer in the brief"
SAVED="Inspect a truncated output's saved file by search or bounded ranges"
FILTER="Filter long command output to the actionable lines"

PLAN="$TMP/plan.md"
printf '# Plan\n\n### U-01 · first\n\nx\n\n### U-02 · second\n\ny\n\n### U-03 · unrelated\n\nz\n' > "$PLAN"
round=0
brief() { # brief <args…>: builds a fresh round and prints the brief's path
  round=$((round + 1))
  echo "Objective: test." | "$SCRIPT" "$@" --round "$round" | head -1 | sed 's/ · .*//'
}
count() { tr '\n' ' ' < "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
expect_rules() { # expect_rules <name> <brief> <want-skill> <want-section> <want-saved> <want-filter>
  local got="$(count "$2" "$SKILL") $(count "$2" "$SECTION") $(count "$2" "$SAVED") $(count "$2" "$FILTER")"
  if [ "$got" == "$3 $4 $5 $6" ]; then ok "$1"; else bad "$1: hygiene rule counts want [$3 $4 $5 $6] got [$got]"; fi
}

for kind in impl fix; do
  expect_rules "$kind gets the four hygiene rules" "$(brief --plan "$PLAN" --units U-01 --kind $kind)" 1 1 1 1
done
expect_rules "gate gets the four hygiene rules" "$(brief --plan "$PLAN" --units GATE-1 --kind gate)" 1 1 1 1
for kind in review recheck; do
  expect_rules "$kind gets the first three" "$(brief --plan "$PLAN" --units U-01 --kind $kind)" 1 1 1 0
done
expect_rules "consult gets the first three" "$(brief --plan "$PLAN" --units U-01 --kind consult)" 1 1 1 0

b=$(brief --plan "$PLAN" --units U-02,U-01 --kind impl)
got=$(grep -oE "sed -En '/\^### U-0[0-9] ·" "$b" | grep -oE 'U-0[0-9]' | tr '\n' ' ')
if [ "$got" == "U-02 U-01 " ]; then ok "plan mode points at each named unit only"; else bad "plan mode pointers: [$got]"; fi

b=$(brief --work "$TMP/work" --units GATE-1 --kind gate)
if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "light-mode gate has no section pointer"; else bad "light-mode gate: brief [$b]"; fi
exit $fail
