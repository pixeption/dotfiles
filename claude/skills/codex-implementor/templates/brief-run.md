# <unit> — run: <one line: what the run proves>

## Objective
<unit>: <why the run — the acceptance, baseline, gate or render batch it supplies evidence for>.

## Where it runs
You hold <the claimed resource: a lane, the gate's worktree, the test shards>, claimed for you.
Off-limits: <every other slot, e.g. lane-2 and integration>.

## Commands — run verbatim, in this order
<each command on its own line, exactly as it must run; full suites included, since the implementor
filter rule does not apply to a run>

## Editor-drive contract
<`cat` templates/editor-card.md here and fill <project>, or "none: no Unity">

## Rules
- Never edit, stage, commit or revert anything: you run, you do not fix.
- A failing command is recorded and the next one runs; it is not fixed or rerun.
- A held project or a missing resource stops the run: report it as `Blocked`.
- No retry or polling loops. No command blocks the round past its own timeout.

## Return
Per command: the command verbatim, its exit code, and unity-suite's count line with its
`report: <path> · finished <HH:MM>` line, or the XML path(s) it wrote.
Then `Outcome: Done | Blocked` with one clause of substance. Your last line is exactly:
BEES: results=<unit>:<done|blocked>:-
