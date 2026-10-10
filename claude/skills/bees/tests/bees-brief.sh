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
b=$(brief --plan "$PLAN" --units GATE-1 --kind gate); expect_rules "gate gets the four hygiene rules" "$b" 1 1 1 1; if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "plan-mode gate has no section pointer"; else bad "plan-mode gate: brief [$b]"; fi
for kind in review recheck; do
  expect_rules "$kind gets the first three" "$(brief --plan "$PLAN" --units U-01 --kind $kind)" 1 1 1 0
done
expect_rules "consult gets the first three" "$(brief --plan "$PLAN" --units U-01 --kind consult)" 1 1 1 0

b=$(brief --plan "$PLAN" --units U-02,U-01 --kind impl)
got=$(grep -oE "sed -En '/\^### U-0[0-9] ·" "$b" | grep -oE 'U-0[0-9]' | tr '\n' ' ')
if [ "$got" == "U-02 U-01 " ]; then ok "plan mode points at each named unit only"; else bad "plan mode pointers: [$got]"; fi

b=$(brief --work "$TMP/work" --units GATE-1 --kind gate)
if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "light-mode gate has no section pointer"; else bad "light-mode gate: brief [$b]"; fi

SIZE="On first read, before editing, compare the code with the item's Reach and Sizing"
REPLAN="BEES: results=<unit>:replan:-"
has() { if [ "$(count "$2" "$3")" == "$4" ]; then ok "$1"; else bad "$1: want $4 of [$3] got $(count "$2" "$3")"; fi; }
b=$(brief --plan "$PLAN" --units U-03 --kind impl)
has "impl rules carry the first-read size check" "$b" "$SIZE" 1
has "impl rules carry the Re-plan return" "$b" "$REPLAN" 1
has "impl return vocabulary lists replan" "$b" "<done|blocked|paused|needs-decision|replan>" 2

AC_BLOCK="Stage 1, AC draft"
EXPAND_BLOCK="Stage 2, expand"
b=$(brief --plan "$PLAN" --units U-01 --kind plan-expand)
expect_rules "plan-expand gets the four hygiene rules" "$b" 1 1 1 1
has "plan-expand carries the stage-2 block" "$b" "$EXPAND_BLOCK" 1
has "plan-expand keeps AC read-only" "$b" "AC is read-only" 1
has "plan-expand rules stop at 120k and return the rest as to expand" "$b" "Stop at 120k context" 1
has "plan-expand rules never default to M" "$b" "\`unknown\`, never M" 1
has "plan-expand return names the items to expand" "$b" "To expand:" 1
has "plan-expand return sends an impossible AC to the owner" "$b" "AC back to owner" 2
has "plan-expand brief points at the unit section" "$b" "sed -En '/^### U-01 ·" 1
has "plan-expand brief carries no implementor size check" "$b" "$SIZE" 0
has "plan-expand brief carries no stage-1 block" "$b" "$AC_BLOCK" 0

b=$(brief --plan "$PLAN" --units U-02 --kind plan-ac)
expect_rules "plan-ac gets the four hygiene rules" "$b" 1 1 1 1
has "plan-ac carries the stage-1 block" "$b" "$AC_BLOCK" 1
has "plan-ac names the stage-1 fields" "$b" "Outcome, AC (numbered" 1
has "plan-ac carries no stage-2 block" "$b" "$EXPAND_BLOCK" 0
has "plan-ac brief points at the unit section" "$b" "sed -En '/^### U-02 ·" 1
has "plan-ac rules stop at 120k" "$b" "Stop at 120k context" 1
b=$(brief --work "$TMP/work" --units Q-03 --kind plan-ac)
if [ -f "$b" ] && ! grep -q "sed -En" "$b" && [ "$(count "$b" "$AC_BLOCK")" == 1 ]; then ok "plan-ac from a queue row needs no plan"; else bad "plan-ac --work: brief [$b]"; fi
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind plan --round 99 >/dev/null 2>&1; then bad "kind plan is gone"; else ok "kind plan is gone"; fi
names() { # names <kind> <units>: the brief is brief-<units>-<kind>-r<N>.txt and its last Report line names report-<units>-<kind>-r<N>.md beside it
  local b n; b=$(brief --plan "$PLAN" --units "$2" --kind "$1"); n=$(basename "$b")
  if [[ "$n" =~ ^brief-${2//,/_}-$1-r[0-9]+\.txt$ ]] && grep -qF "Report: $(dirname "$b")/$(sed 's/^brief-/report-/; s/\.txt$/.md/' <<<"$n")" "$b"; then ok "$1 brief and report are named by unit, kind and round"; else bad "$1 names: [$n]"; fi
}
names plan-ac U-01
names plan-expand U-02,U-03
for kind in plan-ac plan-expand impl; do
  if out=$(echo x | "$SCRIPT" --plan "$PLAN" --units U-09 --kind "$kind" --round 99 2>&1); then
    bad "$kind accepted a unit without a plan section: [$out]"
  elif [[ "$out" == *"no '### <ID> · ' section for U-09"* ]]; then
    ok "$kind rejects a unit without a plan section"
  else
    bad "$kind missing section: [$out]"
  fi
done
exit $fail
