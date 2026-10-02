# <unit> — <one-line objective>

## Objective and acceptance
<what to build or change>. Done when: <the suite filter that proves it> reaches <count>.
Touch: <files>. Do not touch: <files>.

## Where it runs
<worktree: you cannot run Unity here; report exactly what you could not verify.>
<in place: you alone drive <project>. Do not run or edit anything against <sibling projects>.
The project compiles at the start.>
Read first: <sibling-repo CLAUDE.md files the unit touches, by absolute path>.

## Editor-drive contract (in place only)
Read ~/.claude/skills/unity-cli/SKILL.md and <project>/.claude/skills/unity-ui*/SKILL.md. The
helpers are not on PATH: run them by absolute path from ~/.claude/skills/unity-cli/scripts/
(unity-editor, unity-wait, unity-test, unity-suite). Batch `unity test` takes an absolute
`--output` before any `--`; parse the XML, ignore stdout and the exit code. Live editor via
`unity-editor up` / `unity command …`. `unity close` before reporting; never kill the editor.

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
