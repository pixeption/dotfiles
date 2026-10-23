# Watching rounds and terminations

Read when `bees-watch` flags a round or a round terminates; launching, naming and the `bees-watch`
commands are SKILL.md "Watching rounds"'s.

## `bees-watch` flags

`--dir` lists running or flagged rounds, `--all` every one.

One line per round — running/finished, minutes since the log last grew, BUSY/idle, context
tokens, session id — and a flag, exit 1, when something needs you. BUSY is the server's status for
the round's directory (`/session/status` is scoped per directory) or a live wrapper mid-step.

| flag | meaning | do |
|---|---|---|
| `ASK WAITING` | a permission ask nobody headless can answer | answer it through the attach TUI if the pattern is inside the fence's allowlist, else kill the run and re-brief; then fix the cause — the server predates the fence (plan-lifecycle "Preflight"), or the session was resumed for a directory it is not pinned to |
| `STALE` | no log growth in 20 minutes and not BUSY: the run died | check the editor, re-run |
| `quiet but BUSY (tool running)` | a long tool call — a Unity suite can be silent for 20 minutes | leave it |
| `quiet but BUSY (model stream …)` | a provider holding a stream open with no output | leave it: `opencode-round` fails the round itself (`Blocked: the model stream stalled`) after `OPENCODE_ROUND_STALL_MIN` (15) minutes unchanged; resume with `-s` and the same prompt |
| `ACTIVITY UNKNOWN` | the server did not answer for the session | check the server |
| `failed (…)` | the wrapper finished but the out-file is empty or carries its `Blocked:` line (an `error` event, a rejected ask, a non-zero `opencode run` exit, no final message, an unfinished final step, a review without a verdict); the wrapper exited 1 | read the out-file, decide |
| `DEAD` | the wrapper's PID (`.pid`) is gone and it never wrote `.usage` | check what it left, re-run |

Under `--dir`, `failed` and `DEAD` show as `history`, not flagged, once the unit has a newer round
of that role or a `[<unit>] accept:` line in `<plan>.log.md`. Then check the editor's state if the
unit held a project. A stuck round's one-line owner report (SKILL.md "Watching rounds") quotes what
`bees-watch` printed.

## After a termination

On any termination notice (`failed`, cut-off, no report), verify what the agent may have left
before handing the project on, and say so in the next brief:

- Play mode, data isolation (`data_restore`);
- stray `unity test` loops (`pkill -f 'unity test'`);
- a hung reviewer: `codex-round stop <out-file>` (either channel) — the session
  survives either way.
