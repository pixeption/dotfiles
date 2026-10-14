## Rules
- Run exactly the named commands, in order; full suites are allowed, since the implementor
  filter rule does not apply to a run.
- Never edit, stage, commit or revert anything: you run, you do not fix.
- A failing command is recorded and the next one runs; it is not fixed or rerun.
- A held project or a missing resource stops the run: report it as `Blocked`.
- No retry or polling loops. No command blocks the round past its own timeout.

## Return
Per command: the command verbatim, its exit code, and unity-suite's count line with its
`report: <path> · finished <HH:MM>` line, or the XML path(s) it wrote.
Then `Outcome: Done | Blocked` with one clause of substance. Your last line is exactly:
BEES: results=<unit>:<done|blocked>:-
