# Launching, watching and ending rounds

## Contents

- Naming and launching a codex round
- Watching: `bees-watch` states
- After a termination
- Worktrees, pausing, idle reviewers

## Naming and launching a codex round

- **Naming.** The wrappers take `-o` verbatim, so name every out-file
  `docs/plans/<plan>.work/impl-<unit>[+<unit>…]-r<N>.txt` or `review-…-r<N>.txt`, N counting up per
  unit and role; `bees-watch --dir` reads only files named that way. An astra consult is
  `review-<unit>-consult-r<N>.txt`.
- **Launching.** Run the wrapper (`opencode-implement`, `opencode-review`, the CLI fallbacks) as
  its own Bash call with `run_in_background: true`, never with a trailing `&`: the harness then
  re-invokes you when the round exits, while a `&`-detached round's finish goes unnoticed.
- Batch `unity test` writes its report to a cwd-relative `test-results.xml`, prints nothing and
  can exit 1 on a green run. Briefs say: run from the project dir or pass an absolute `--output`,
  parse the XML, ignore stdout and exit code (unity-cli skill).

## Watching: `bees-watch` states

Never tail or Read the wrapper's `.log` — it stays in your context every later turn. Run:

```sh
~/.claude/skills/bees/scripts/bees-watch <out-file>...
~/.claude/skills/bees/scripts/bees-watch --dir docs/plans/<plan>.work   # running or flagged rounds; --all for every one
```

One line per round — running/finished, minutes since the log last grew, BUSY/idle, context
tokens, session id — and a flag, exit 1, when something needs you. BUSY is the server's status for
the round's directory (`/session/status` is scoped per directory) or a live wrapper mid-step.

| flag | meaning | do |
|---|---|---|
| `ASK WAITING` | a permission ask nobody headless can answer | answer it through the attach TUI if the pattern is inside the fence's allowlist, else kill the run and re-brief; then fix the cause — the server predates the fence (SKILL.md "Setup"), or the session was resumed for a directory it is not pinned to |
| `STALE` | no log growth in 20 minutes and not BUSY: the run died | check the editor, re-run |
| `quiet but BUSY (tool running)` | a long tool call — a Unity suite can be silent for 20 minutes | leave it |
| `quiet but BUSY (model stream …)` | a provider holding a stream open with no output | leave it: `opencode-round` fails the round itself (`Blocked: the model stream stalled`) after `OPENCODE_ROUND_STALL_MIN` (15) minutes unchanged; resume with `-s` and the same prompt |
| `ACTIVITY UNKNOWN` | the server did not answer for the session | check the server |
| `failed (…)` | the wrapper finished but the out-file is empty or carries its `Blocked:` line (an `error` event, a rejected ask, a non-zero `opencode run` exit, no final message, an unfinished final step, a review without a verdict); the wrapper exited 1 | read the out-file, decide |
| `DEAD` | the wrapper's PID (`.pid`) is gone and it never wrote `.usage` | check what it left, re-run |

Under `--dir`, `failed` and `DEAD` show as `history`, not flagged, once the unit has a newer round
of that role or a `[<unit>] accept:` line in `<plan>.log.md`. Then check the editor's state if the
unit held a project. A stuck round is reported to the owner in one line with what `bees-watch`
printed; it is never left for the next session.

## After a termination

On any termination notice (`failed`, cut-off, no report), verify what the agent may have left
before handing the project on, and say so in the next brief:

- Play mode, data isolation (`data_restore`);
- stray `unity test` loops (`pkill -f 'unity test'`);
- a hung implementor: `pkill -f "opencode run"` (default channel) or `pkill -f "codex exec"` (CLI
  fallback) — the session survives on the server either way.

## Worktrees, pausing, idle reviewers

- Codex worktrees: `git worktree add -b codex/<unit> "$T/wt-<unit>" HEAD` under your scratchpad;
  remove the worktree after merge or discard so the next session does not find it.
- Pausing: "stop at the next safe point (tree compiling, editor not in Play, isolation restored),
  report in five lines, then wait." A paused agent is warm for its cache clock (5 min Claude,
  30 min codex) and worth continuing under ~100k after it; past that, spawn from its handover.
- A Claude reviewer waiting > ~30 min for a fix is retired; a fresh one rechecks from the findings
  list and the fix diff. A codex reviewer's recheck resumes the same OpenCode session at any time;
  only the CLI fallback has the 30-minute cliff, after which a fresh session with the findings list
  and the fix diff in the brief is cheaper than the cold re-read.
