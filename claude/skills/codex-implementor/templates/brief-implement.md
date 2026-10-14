# <unit> — <one-line objective>

## Specification
<under bees, keep this block and drop the ad-hoc one:>
Read your unit's section of <plan path> and follow it as written: start from the files and symbols
its Today and Approach name, and run the `--filter` its Tests field names, narrowed to your piece
when this brief names one:
  sed -En '/^### <unit> ·/,/^#{1,3} /p' <plan path>
<only when they apply, one line each:>
Piece: <piece> — this piece only.
Decision since the plan: <decision or override, with why>.
Conflict: <another unit touching the same files, and how to stay clear of it>.

<ad hoc, without a plan:>
Objective and acceptance: <what to build or change>. Done when: <the suite filter that proves it>
reaches <count>. Touch: <files, with line ranges where the change is local>. Do not touch: <files>.
Context: <a contract quoted, or cited as `path:start-end`; no whole documents>.

## Where it runs
You hold <lane> (its Game/ and GameCore/), claimed for you. Off-limits: <the other slots, e.g.
lane-2 and integration>. The projects compile at the start.
Read first: <the CLAUDE.md of the one game-core package the unit edits, by absolute path, or "nothing">.

## Editor-drive contract
<`cat` templates/editor-card.md here and fill <project>. A `ui_*` unit adds the one skill section
it needs as `path:start-end`.>

## Owner WIP — never stage, edit or revert
<paths, verbatim, or "none">

<`cat` ~/.claude/skills/bees/templates/standing-rules-implementor.txt here, then
~/.claude/skills/bees/templates/return-implementor.txt with <report> filled as
$W/report-<unit>-impl-r<N>.md; each once, never retyped.>
