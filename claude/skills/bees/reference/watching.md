# Launching, watching and ending rounds

## Contents

- Naming and launching a codex round
- Watching: `bees-watch` states
- After a termination
- Worktrees, pausing, idle reviewers

## Naming and launching a codex round

Read when `bees-watch` flags a round, a round terminates, or you set up a worktree or pause an
agent; launching, naming and the `bees-watch` commands are SKILL.md "Watching rounds"'s.

- **Naming.** The wrappers take `-o` verbatim, and `bees-watch --dir` reads only files named as
  SKILL.md says. A Sol advisor is `review-<unit>-advice-r<N>.txt`.
- **Launching.** `run_in_background: true` covers every `codex-round` job
  (`implement`, `run`, `review`, `advise`), on either channel: the harness re-invokes you when the
  round exits.
- Batch Unity brief instructions are SKILL.md "Briefing an agent"'s.

## Watching: `bees-watch` states

The wrapper's `.log` stays in your context every later turn, hence `bees-watch` (SKILL.md "Watching
rounds"); `--dir` lists running or flagged rounds, `--all` every one.

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
- a hung implementor: `codex-round stop <out-file>` (either channel) — the session
  survives either way.

## Worktrees, pausing, idle reviewers

- Codex worktrees: `git worktree add -b codex/<unit> "$T/wt-<unit>" HEAD` under your scratchpad;
  remove the worktree after merge or discard so the next session does not find it.
- Pausing: "stop at the next safe point (tree compiling, editor not in Play, isolation restored),
  report in five lines, then wait." A paused agent is warm for its cache clock (5 min Claude,
  30 min codex) and worth continuing while the budget mod allows it; past that, spawn from its
  handover.
- A codex reviewer's recheck resumes the same OpenCode session at any time;
  only the CLI fallback has the 30-minute cliff, after which a fresh session with the findings list
  and the fix diff in the brief is cheaper than the cold re-read.
