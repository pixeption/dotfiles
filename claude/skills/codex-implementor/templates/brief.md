# <unit> — <one-line objective>

## Objective and acceptance
<what to build or change>. Done when: <the suite filter that proves it> reaches <count>.
Touch: <files, with line ranges where the change is local>. Do not touch: <files>.

## Context
<the plan section, pasted here — never "read section X". A contract from a spec or doc is quoted,
or cited as `path:start-end`. No whole documents.>

## Where it runs
<worktree: you cannot run Unity here; report exactly what you could not verify.>
<in place: you alone drive <project>. Do not run or edit anything against <sibling projects>.
The project compiles at the start.>
Read first: <the CLAUDE.md of the one sibling package the unit edits, by absolute path, or "nothing">.

## Editor-drive contract (in place only)
<`cat` templates/editor-card.md here and fill <project>. A `ui_*` unit adds the one skill section
it needs as `path:start-end`.>

## Commit gate
No suite XML produced in this session → no commit: leave the tree dirty and report `Blocked`.
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
as introduced / pre-existing (with evidence) / unknown.

## Return
Outcome / Findings / Changes / Verification (commands verbatim + parsed counts) / Resources
(editor state before/after) / Cost / Concerns / Need from orchestrator. Every commit subject names
<unit>. Your final message's last line is exactly
`BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->`
