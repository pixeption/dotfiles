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
printf '# Plan\n\n### U-01 · first\n\nSECTION-BODY Tests: --filter SectionTests\n\n### U-02 · second\n\ny\n\n### U-03 · unrelated\n\nz\n\n### U-04 · item\n\nshared\n\n#### U-04.1 · sub\n\nw\n' > "$PLAN"
round=0
IN="Objective: test."
brief() { # brief <args…>: builds a fresh round from $IN and prints the brief's path
  round=$((round + 1))
  printf '%s\n' "$IN" | "$SCRIPT" "$@" --round "$round" | head -1 | sed 's/ · .*//'
}
W="$TMP/work"
REVIEW_FIX=$'Fixes: MAJ-01 — guard the empty list — a.py:3\nReview: /r/review-U-01-r1.txt, ids MAJ-01\nFilter: --filter SectionTests'
GATE_FIX=$'Fixes: restore the shard count\nGate: /r/gate-1.txt, tested 0123abcd, failing ShardTests.Count\nFilter: --filter ShardTests'
fixbrief() { IN="$REVIEW_FIX" brief "$@"; }
RUN="Run exactly the named commands"
RETURN="Then hand back only these lines"
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

T="$here/../templates"
expect_rules "the reading template holds the shared paragraph" "$T/standing-rules-reading.txt" 1 1 1 1
for role in implementor planner advisor reviewer; do has "$role template has no reading copy" "$T/standing-rules-$role.txt" "Invoke a skill's entry point" 0; done
SCOUT="Send every other lookup"
for role in implementor planner advisor reviewer; do has "$role template has no scout rule of its own" "$T/standing-rules-$role.txt" "sub-agent" 0; done
for kind in impl advise review plan-expand; do has "$kind brief carries the scout rule once" "$(brief --plan "$PLAN" --units U-02 --kind $kind)" "$SCOUT" 1; done
expect_rules "fix gets the four hygiene rules" "$(fixbrief --work "$W" --units U-01-fix1 --kind fix)" 1 1 1 1
for mode in "--plan $PLAN" "--work $W"; do
  b=$(brief $mode --units GATE-1 --kind run)
  if [ -f "$b" ] && ! grep -q "sed -En" "$b"; then ok "run ($mode) has no section pointer"; else bad "run ($mode): brief [$b]"; fi
  has "run ($mode) has no implementor rules" "$b" "Standing rules:" 0
  has "run ($mode) carries the run contract once" "$b" "$RUN" 1
  has "run ($mode) carries the run return once" "$b" "BEES: results=<unit>:<done|blocked>:-" 1
done
for kind in review recheck; do
  if [ $kind == review ]; then b=$(brief --plan "$PLAN" --units U-01 --kind $kind); else b=$(brief --work "$W" --units U-01-fix1 --kind $kind); fi
  expect_rules "$kind gets the first three" "$b" 1 1 1 0
  expect_pause "$kind" "$b"
  has "$kind pause returns the unreviewed rest" "$b" "\`Paused: <files and Tests not yet reviewed>\`, verdict \`CHANGES_REQUIRED\`" 1
done

b=$(brief --plan "$PLAN" --units U-02,U-01 --kind impl)
got=$(grep -oE "sed -En '/\^### U-0[0-9] ·" "$b" | grep -oE 'U-0[0-9]' | tr '\n' ' ')
if [ "$got" == "U-02 U-01 " ]; then ok "plan mode points at each named unit only"; else bad "plan mode pointers: [$got]"; fi

b=$(brief --plan "$PLAN" --units U-04.1 --kind impl)
has "a sub-item points at its item's shared context" "$b" "sed -En '/^### U-04 ·" 1
has "a sub-item points at its own section" "$b" "sed -En '/^#### U-04.1 ·" 1

b=$(brief --plan "$PLAN" --units U-01 --kind impl)
expect_rules "impl gets the four hygiene rules" "$b" 1 1 1 1
has "impl points at the section without copying it" "$b" "SECTION-BODY" 0
has "impl copies no section filter" "$b" "SectionTests" 0
has "impl carries its return contract once" "$b" "$RETURN" 1
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind gate --round 95 >/dev/null 2>&1; then bad "kind gate is gone"; else ok "kind gate is gone"; fi
for kind in fix recheck; do
  if out=$(printf '%s\n' "$REVIEW_FIX" | "$SCRIPT" --plan "$PLAN" --units U-01 --kind $kind --round 94 2>&1); then bad "$kind accepted --plan"
  elif [[ "$out" == *"takes --work"* ]]; then ok "$kind refuses --plan"; else bad "$kind --plan: [$out]"; fi
done
fix_refused() { # fix_refused <name> <stdin> <want-in-error>
  local out
  if out=$(printf '%s\n' "$2" | "$SCRIPT" --work "$W" --units U-07-fix1 --kind fix 2>&1); then bad "$1 accepted"
  elif [[ "$out" == *"needs $3 on stdin"* ]]; then ok "$1 fails naming $3"; else bad "$1: [$out]"; fi
}
fix_refused "fix without Fixes" $'Review: r\nFilter: f' "Fixes:"
fix_refused "fix without Filter" $'Fixes: x\nGate: g' "Filter:"
fix_refused "fix without Review or Gate" $'Fixes: x\nFilter: f' "Review: or Gate:"
b=$(fixbrief --work "$W" --units U-01-fix2 --kind fix)
while IFS= read -r line; do has "review fix carries [${line%% *}] exactly" "$b" "$line" 1; done <<<"$REVIEW_FIX"
has "review fix carries its return contract once" "$b" "$RETURN" 1
g=$(IN="$GATE_FIX" brief --work "$W" --units GATE-1-fix1 --kind fix)
r=$(IN="$GATE_FIX" brief --work "$W" --units GATE-1-fix1 --kind recheck)
while IFS= read -r line; do
  has "gate repair carries [${line%% *}]" "$g" "$line" 1; has "its recheck carries [${line%% *}]" "$r" "$line" 1
done <<<"$GATE_FIX"
has "gate repair carries its return contract once" "$g" "$RETURN" 1
has "gate repair is diagnosed first when its cause is unknown" "$g" "A gate repair whose cause is unknown requires a codex diagnosis first" 1

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
has "plan-expand breaks an 8 or 13 into sub-items" "$b" "13 keeps its score and is broken here into sub-items scored 5 or less" 1
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
if [ -f "$b" ] && ! grep -q "sed -En" "$b" && [ "$(count "$b" "$BRIEF_BLOCK")" == 1 ]; then ok "plan-brief needs no plan file"; else bad "plan-brief --work: brief [$b]"; fi
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind plan-ac --round 98 >/dev/null 2>&1; then bad "kind plan-ac is gone"; else ok "kind plan-ac is gone"; fi
if echo x | "$SCRIPT" --plan "$PLAN" --units U-01 --kind plan --round 99 >/dev/null 2>&1; then bad "kind plan is gone"; else ok "kind plan is gone"; fi
names() { # names <kind> <units>: the brief is brief-<units>-<kind>-r<N>.txt and its last Report line names report-<units>-<kind>-r<N>.md beside it
  local b n; b=$(brief --plan "$PLAN" --units "$2" --kind "$1"); n=$(basename "$b")
  if [[ "$n" =~ ^brief-${2//,/_}-$1-r[0-9]+\.txt$ ]] && grep -qF "Report: $(dirname "$b")/$(sed 's/^brief-/report-/; s/\.txt$/.md/' <<<"$n")" "$b"; then ok "$1 brief and report are named by unit, kind and round"; else bad "$1 names: [$n]"; fi
}
names plan-brief U-01
names plan-expand U-02,U-03
touch "$W/report-U-04-review-r1.md"
if out=$(echo x | "$SCRIPT" --work "$W" --units U-04 --kind review 2>&1); then bad "an existing report path was accepted"
elif [[ "$out" == *"report-U-04-review-r1.md exists"* ]] && [ ! -f "$W/brief-U-04-review-r1.txt" ]; then ok "an existing report path is refused naming it, writing no brief"
else bad "existing report: [$out]"; fi
r1=$(grep -o 'Report: .*' "$(brief --work "$W" --units U-05.1 --kind review)" | tail -1)
r2=$(grep -o 'Report: .*' "$(brief --work "$W" --units U-05.2 --kind review)" | tail -1)
if [ -n "$r1" ] && [ "$r1" != "$r2" ]; then ok "reviews of two fix units of one item get distinct reports"; else bad "fix-unit reports: [$r1] [$r2]"; fi
for kind in plan-brief plan-expand impl; do
  if out=$(echo x | "$SCRIPT" --plan "$PLAN" --units U-09 --kind "$kind" --round 99 2>&1); then
    bad "$kind accepted a unit without a plan section: [$out]"
  elif [[ "$out" == *"section for U-09"* ]]; then
    ok "$kind rejects a unit without a plan section"
  else
    bad "$kind missing section: [$out]"
  fi
done
exit $fail
