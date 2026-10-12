# <unit> — <one-line objective>

## Objective and acceptance
<what to build or change>. Done when: <the suite filter that proves it> reaches <count>.
Run only that filter and the red runs the Style section requires, never a full suite or
another item's filter: the post-integrate check reruns the filter and the plan's gates run the full
suites.
Touch: <files, with line ranges where the change is local>. Do not touch: <files>.

## Context
<the plan section, pasted here — never "read section X". A contract from a spec or doc is quoted,
or cited as `path:start-end`. No whole documents.>

## Where it runs
<blind worktree: you cannot run Unity here; report exactly what you could not verify.>
<in place: you hold <lane> (its Game/ and GameCore/), claimed for you. Do not run or edit anything
in <the other slots, e.g. lane-2 and integration>. The projects compile at the start.>
Read first: <the CLAUDE.md of the one game-core package the unit edits, by absolute path, or "nothing">.

## Editor-drive contract (in place only)
<`cat` templates/editor-card.md here and fill <project>. A `ui_*` unit adds the one skill section
it needs as `path:start-end`.>

## When to stop
The item's score is an estimate: more files or work than expected is not a reason to stop.
Stop only when the approach does not work or the work needs something the brief rules out, and
report `Outcome: Needs decision` (`Blocked` after two attempts), which goes to the advisors.
Start at: <the files and symbols the item's Today and Approach name, or "none"> — a reference, not a limit.

## Commit gate
When the required verification includes a Unity test run and no suite XML was produced in this
session → no commit: leave the tree dirty and report `Blocked`. Verification that is not a Unity run
records each command, its exit status and result in the report instead.
Stage by explicit path only. Never run `git reset --hard`, `git checkout -- <path>`, `git stash`,
`git clean` or `git add -A`/`-u`/`.`.

## Owner WIP — never stage, edit or revert
<paths, verbatim, or "none">

## Blockers
At most two materially different attempts at a blocker. After the second, STOP and report:
`STOP. Goal / Discovered / Blocker / Tried (both) / Options / Need from orchestrator`. Stop at once,
before any attempt, on a held resource or a missing decision. No retry or polling loops.

## Style
Short and obviously correct; no restating comments; no unrelated refactors. Classify every failure
as introduced / pre-existing (with evidence) / unknown. New tests are plain by default: write an
Integration test (AssetDatabase, prefabs, scenes, rendering, Play Mode) only when
a plain test cannot observe the behavior, because Integration tests dominate suite time.
Add a test only for observable behavior, an invariant, a boundary or a bug that reached an
integrated target, when no existing test covers it, preferring a new case in an existing test.
Run a new test red against the old code only for such a bug or a test outside Unity; otherwise
state why it would fail there (`asserts X; the old code yields Y at file:line`).

## Return
Outcome / Findings / Changes / Verification (commands verbatim + parsed counts) / Resources
(editor state before/after) / Cost / Concerns / Need from orchestrator. Every commit subject names
<unit>. Your final message's last line is exactly
`BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->`
