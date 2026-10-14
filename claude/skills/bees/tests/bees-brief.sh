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

PAUSE="When the context hook tells you to pause"
BUDGET="budgets.md"
PLAN="$TMP/plan.md"
printf '# Plan\n\n### U-01 · first\n\nx\n\n### U-02 · second\n\ny\n\n### U-03 · unrelated\n\nz\n' > "$PLAN"
round=0
brief() { # brief <args…>: builds a fresh round and prints the brief's path
  round=$((round + 1))
  echo "Objective: test." | "$SCRIPT" "$@" --round "$round" | head -1 | sed 's/ · .*//'
}
count() { tr '\n' ' ' < "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
has() { if [ "$(count "$2" "$3")" == "$4" ]; then ok "$1"; else bad "$1: want $4 of [$3] got $(count "$2" "$3")"; fi; }
expect_rules() { # expect_rules <name> <brief> <want-skill> <want-section> <want-saved> <want-filter>
  local got="$(count "$2" "$SKILL") $(count "$2" "$SECTION") $(count "$2" "$SAVED") $(count "$2" "$FILTER")"
  if [ "$got" == "$3 $4 $5 $6" ]; then ok "$1"; else bad "$1: hygiene rule counts want [$3 $4 $5 $6] got [$got]"; fi
}
expect_pause() { # expect_pause <kind> <brief>: pauses when the hook says, once, citing no threshold or budgets.md
  has "$1 rules pause when the hook says" "$2" "$PAUSE" 1
  has "$1 rules cite no budgets.md" "$2" "$BUDGET" 0
  has "$1 rules name no 250k" "$2" "250k" 0
}

for kind in impl fix; do
  expect_rules "$kind gets the four hygiene rules" "$(brief --plan "$PLAN" --units U-01 --kind $kind)" 1 1 1 1
done
b=$(brief --plan "$PLAN" --units GATE-1 --kind gate); expect_rules "gate gets the four hygiene rules" "$b" 1 1 1 1; if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "plan-mode gate has no section pointer"; else bad "plan-mode gate: brief [$b]"; fi
for kind in review recheck; do
  b=$(brief --plan "$PLAN" --units U-01 --kind $kind)
  expect_rules "$kind gets the first three" "$b" 1 1 1 0
  expect_pause "$kind" "$b"
  has "$kind pause returns the unreviewed rest" "$b" "\`Paused: <files and Tests not yet reviewed>\`, verdict \`CHANGES_REQUIRED\`" 1
done

b=$(brief --plan "$PLAN" --units U-02,U-01 --kind impl)
got=$(grep -oE "sed -En '/\^### U-0[0-9] ·" "$b" | grep -oE 'U-0[0-9]' | tr '\n' ' ')
if [ "$got" == "U-02 U-01 " ]; then ok "plan mode points at each named unit only"; else bad "plan mode pointers: [$got]"; fi

b=$(brief --work "$TMP/work" --units GATE-1 --kind gate)
if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "light-mode gate has no section pointer"; else bad "light-mode gate: brief [$b]"; fi

ESTIMATE="The item's score is an estimate: more files or work than expected is not a reason to stop."
b=$(brief --plan "$PLAN" --units U-03 --kind impl)
has "impl rules treat the score as an estimate" "$b" "$ESTIMATE" 1
expect_pause impl "$b"
has "impl rules stop only to the advisors" "$b" "report \`Outcome: Needs decision\` (\`Blocked\` after two attempts)" 1
has "impl return vocabulary has no replan" "$b" "<done|blocked|paused|needs-decision>" 2
has "impl brief has no Sizing field" "$b" "Sizing" 0
has "impl brief derives start and filter from the section" "$b" "start from the files and symbols its Today and Approach name" 1
has "impl brief carries no Start at" "$b" "Start at" 0
has "impl brief carries no Test filter" "$b" "Test filter" 0
if printf 'Piece: U-01 — this piece only\nConflicts: X belongs to another unit\n' | "$SCRIPT" --plan "$PLAN" --units U-01 --kind impl --round 96 >/dev/null; then ok "piece and conflicts alone build a brief"; else bad "piece and conflicts brief failed"; fi
if out=$(printf '' | "$SCRIPT" --plan "$PLAN" --units U-01 --kind impl --round 97 2>&1); then bad "empty stdin accepted"; elif [[ "$out" == *"piece, decisions, conflicts"* ]]; then ok "empty stdin fails naming piece, decisions, conflicts"; else bad "empty stdin: [$out]"; fi
b=$(brief --plan "$PLAN" --units U-01 --kind advise)
expect_rules "advise gets the first three" "$b" 1 1 1 0
has "advise is limited to the approved brief and the owner's rules" "$b" "Decide only within the approved brief and the owner's rules" 1
has "advise has no BEES line" "$b" "BEES: results" 0
expect_pause advise "$b"
has "advise pause returns what is established" "$b" "write \`Decision: Paused\`, what you established" 1

BRIEF_BLOCK="Brief draft (\`plan\` skill"
EXPAND_BLOCK="Expand (\`plan\` skill"
b=$(brief --plan "$PLAN" --units U-01 --kind plan-expand)
expect_rules "plan-expand gets the four hygiene rules" "$b" 1 1 1 1
has "plan-expand carries the expand block" "$b" "$EXPAND_BLOCK" 1
has "plan-expand keeps the brief read-only" "$b" "The brief is read-only" 1
expect_pause plan-expand "$b"
has "plan-expand pause returns the rest as to expand" "$b" "then return the items done and the rest under \`To expand\`" 1
has "plan-expand asks for Today, Approach and Tests" "$b" "Append below the brief fields: Today" 1
has "plan-expand bans report pointers" "$b" "never \"detail in report-…\"" 1
has "plan-expand gives one judged score" "$b" "one judged score for how" 1
has "plan-expand splits an 8 or 13 at planning" "$b" "you would score 8 or 13 is split here into items scored 5 or less" 1
has "plan-expand return names the items to expand" "$b" "To expand:" 1
has "plan-expand sends a brief change to the owner" "$b" "Back to owner" 2
has "plan-expand brief points at the unit section" "$b" "sed -En '/^### U-01 ·" 1
has "plan-expand brief carries no implementor estimate rule" "$b" "$ESTIMATE" 0
has "plan-expand brief carries no brief block" "$b" "$BRIEF_BLOCK" 0

b=$(brief --plan "$PLAN" --units U-02 --kind plan-brief)
expect_rules "plan-brief gets the four hygiene rules" "$b" 1 1 1 1
has "plan-brief carries the brief block" "$b" "$BRIEF_BLOCK" 1
has "plan-brief names the brief fields" "$b" "with Outcome (what the result looks like" 1
has "plan-brief asks for usage and architecture" "$b" "architecture note of a few lines" 1
has "plan-brief carries no expand block" "$b" "$EXPAND_BLOCK" 0
has "plan-brief brief points at the unit section" "$b" "sed -En '/^### U-02 ·" 1
expect_pause plan-brief "$b"
b=$(brief --work "$TMP/work" --units Q-03 --kind plan-brief)
if [ -f "$b" ] && ! grep -q "sed -En" "$b" && [ "$(count "$b" "$BRIEF_BLOCK")" == 1 ]; then ok "plan-brief from a queue row needs no plan"; else bad "plan-brief --work: brief [$b]"; fi
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind plan-ac --round 98 >/dev/null 2>&1; then bad "kind plan-ac is gone"; else ok "kind plan-ac is gone"; fi
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind plan --round 99 >/dev/null 2>&1; then bad "kind plan is gone"; else ok "kind plan is gone"; fi
names() { # names <kind> <units>: the brief is brief-<units>-<kind>-r<N>.txt and its last Report line names report-<units>-<kind>-r<N>.md beside it
  local b n; b=$(brief --plan "$PLAN" --units "$2" --kind "$1"); n=$(basename "$b")
  if [[ "$n" =~ ^brief-${2//,/_}-$1-r[0-9]+\.txt$ ]] && grep -qF "Report: $(dirname "$b")/$(sed 's/^brief-/report-/; s/\.txt$/.md/' <<<"$n")" "$b"; then ok "$1 brief and report are named by unit, kind and round"; else bad "$1 names: [$n]"; fi
}
names plan-brief U-01
names plan-expand U-02,U-03
for kind in plan-brief plan-expand impl; do
  if out=$(echo x | "$SCRIPT" --plan "$PLAN" --units U-09 --kind "$kind" --round 99 2>&1); then
    bad "$kind accepted a unit without a plan section: [$out]"
  elif [[ "$out" == *"no '### <ID> · ' section for U-09"* ]]; then
    ok "$kind rejects a unit without a plan section"
  else
    bad "$kind missing section: [$out]"
  fi
done
exit $fail
