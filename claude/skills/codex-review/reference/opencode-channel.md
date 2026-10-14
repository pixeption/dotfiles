# The OpenCode channel

Shared by every job of codex-implementor's `scripts/codex-round` (`implement`, `run`, `review`,
`advise`): each round runs through `scripts/opencode-round` against one persistent `opencode serve`,
and `codex-round stop <out-file>` stops a running one. `scripts/` paths here are codex-implementor's.
Read before the first round of a session, and when a round fails or goes quiet.

## Contents

- Round checklist
- Preflight and the server
- The fence
- Running a round: flags and files
- Failed rounds
- Watching a round

## Round checklist

```text
- [ ] prompt/brief written to a file in your scratchpad ($T), never /tmp
- [ ] wrapper launched as its own Bash call with run_in_background: true
- [ ] -o names a new out-file; under bees $W/<impl|review>-<unit>-r<N>.txt
- [ ] every repo outside -C passed as an absolute --repo
- [ ] while it runs: bees-watch <out-file>, never the .log
- [ ] on finish: read the out-file and .usage; a Blocked: line is a failed round, not a result;
      one on a usage limit (429) goes to Claude per bees "Routing"
```

## Preflight and the server

Both wrappers run `scripts/opencode-preflight` before writing any round file: one `opencode serve`
is up (started headless if absent), it carries the fence, every `--repo` outside `-C` is inside
the fence's allows (as given and symlink-resolved; the last matching rule wins), and `-m` is listed
in `/config/providers`.

The server reads `opencode.jsonc` and its model catalogue **at startup only**, so a stale server
asks about a directory nobody can answer, denies a newly allowed one, or fails a round's first
step on a model id that exists. A failed check therefore restarts the server when idle — no busy
session in any directory, no `opencode run --attach`/`attach` client — and refuses when busy. What
still fails names the path to allow. Check by hand with:

```sh
~/.claude/skills/codex-implementor/scripts/opencode-preflight --no-restart -m <model> -C <dir> [--repo <dir>]...
```

Leave `opencode serve` running across rounds and units; the wrappers reuse a live one.

**Server address.** Every wrapper, `opencode-preflight` and `bees-watch` take
`--url`; without it the base URL is `http://127.0.0.1:<--port>`, default port 4096.

## The fence

The fence is the `permission` block in `~/.config/opencode/opencode.jsonc`. `--auto` approves
every "ask"; only `deny` holds. `external_directory` is deny-by-default with the code, skill,
config, Unity and temp directories allowed; bash denies `git reset --hard`, `git checkout --
<path>`, `git stash`, `git clean`, force push and `rm -rf` on root/home. If a unit reports a denied
path it legitimately needed, the owner widens the fence; the unit never works around it. After an
edit, `opencode-preflight` restarts an idle server itself, as it does one whose resident memory
passes `--max-rss-mb` (default 4096: the server keeps every session it has served on its heap); a
busy server over the cap only gets a warning. `opencode-preflight --stop` stops the server when no
session is busy and no client is attached, and exits 1 naming why otherwise.

## Running a round: flags and files

- Run the wrapper via the **Bash tool with `run_in_background: true`**; you are notified when it
  exits. `$T` (prompts, briefs, worktrees) is your scratchpad.
- `-o` is taken verbatim and refused if it already holds a round. Under bees it is
  `$W/<impl|review>-<unit>-r<N>.txt` with `$W` = `docs/plans/<plan>.work`; `bees-watch` relies on
  that `-r<N>` naming. Without a plan any path works.
- `-u <unit>` (repeatable) labels the round's `BEES:` line. `--repo <dir>` (repeatable) names a
  sibling repo the round reads or edits, so preflight checks the fence allows it.
- A session is pinned to the directory it was created in: resume with `-s` only under the same
  `-C`. `codex-round` refuses a resume pinned elsewhere.

| file | holds |
|---|---|
| `<out-file>` | only the final message's text (`scripts/extract-opencode-final`) — read this |
| `<out-file>.session` | the session id, for `-s` |
| `<out-file>.usage` | `context_tokens` (the session-budget figure), tokens, and `cost` (`scripts/extract-opencode-usage`, scoped to this session's step events) |
| `<out-file>.pid`, `.cwd` | the wrapper's PID and the round's directory, for `bees-watch` |
| `<out-file>.log` | the raw JSONL stream — a liveness aid only; never read it into context |

Under the ChatGPT oauth credential `cost` reads 0 — spend is against the subscription; report
tokens.

## Failed rounds

`opencode-round` polls the server's pending-permission list for the round's directory every 15 s
(local HTTP, no tokens). An ask for this session means the round reached outside the fence: it
rejects the ask and stops the run. A round that did not finish — that ask, an `error` event, a
non-zero `opencode run` exit, no final message, a final step that did not end with reason `stop`,
or (review) an answer not ending in `APPROVE`/`CHANGES_REQUIRED` — gets an out-file starting
`Blocked: <reason>` and ending `BEES: results=<unit>:blocked:-`, and the wrapper exits 1. It never
counts as a result or a verdict. Widen the fence or re-brief; never answer an ask by hand in the
TUI and carry on.

## Watching a round

- **A quiet round is inspected, not waited on.** Run
  `~/.claude/skills/bees/scripts/bees-watch <out-file>`; bees `reference/watching.md` lists its
  flags and what to do for each. `quiet but BUSY (model stream …)` is left alone:
  `opencode-round` fails the round itself (`Blocked: the model stream stalled`) after
  `OPENCODE_ROUND_STALL_MIN` (15) minutes unchanged, and it is resumed with `-s`. `STALE` →
  `codex-round stop <out-file>` (aborts the session, ends that round's processes only) and resume
  the session.
- `scripts/opencode-activity` prints what a session's latest message is doing (`tool` or
  `stream <n>`) when checking by hand. `/session/status` is scoped per directory: pass
  `?directory=<the round's .cwd>`, or a busy session in another directory reads as idle.
