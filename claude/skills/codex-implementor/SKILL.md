---
name: codex-implementor
description: Delegate a bounded, well-specified implementation unit to a codex-family model (openai/gpt-5.6-luna default, sol for hard units) with the same powers a Claude sub-agent has — including driving a live Unity editor and running suites IN PLACE in the real checkout — as a multi-round conversation you review and accept. DEFAULT channel is OpenCode (`opencode-implement`) — persistent, attachable, session pinned to one directory, worktree or in place. FALLBACK is the `codex` CLI (`codex-implement`) only when the OpenCode server won't start or an OS sandbox is required. Use whenever the user asks to "have codex implement/build/write" something, delegate a unit to codex, or run a model bake-off. For a read-only second opinion use codex-review instead.
---

# Codex implementor

Delegate a **bounded, well-specified** unit to a **codex-family model**. It is an engineer with the
same reach as a Claude sub-agent: it edits, compiles, runs suites and drives the live Unity editor
through the `unity` CLI. **You are the lead; it executes and brings evidence.** You accept on a
suite count or a real run, never on its claim. Verified against `opencode 1.18.31`,
`codex-cli 0.155.0`; in-place editor drive verified 2026-09-20 on two projects.

## Two channels, same models

| | **Default — OpenCode** (`opencode-implement`) | **Fallback — codex CLI** (`codex-implement`) |
|---|---|---|
| how | `opencode run` against one persistent `opencode serve` | `codex exec` background process |
| where it runs | `-C <any directory>`: a worktree **or the real checkout** | same, plus `--sandbox` tiers |
| session | server-held; resume with `-s` **in the same `-C` only** (pinned to its directory); cache warm **30 min**, one cold turn after | prompt cache **30 min**; the wrapper refuses a resume older than that |
| live view | owner attaches a TUI to the very session (`opencode-sessions --attach`) | read-only tail of the JSONL `.log` |
| isolation | none built in; the fence is the `permission` block in `~/.config/opencode/opencode.jsonc`, loaded at server **startup** | OS seatbelt (`workspace-write` / `danger-full-access`) |
| use when | every unit | server won't start, or the unit must run under an OS sandbox |

**Prefer the default.** The session survives idle gaps (a cold resume costs one full re-read, not a
fresh session), the owner watches and can steer, and it runs in place as well as in a worktree. The
CLI's only extra is the seatbelt — a restriction, not a capability. (Until 2026-09-20 this skill
claimed in-place drive needed the CLI; it does not.)

**Resume or fresh — one rule, both vendors (bees §3).** Read `tokens.total` from `.usage`: it is
the session's context size, re-read on every step. Below 120k resume freely; 120–200k only for a
short recheck in the same files; at 200k, or for **any other directory**, start a new session. A
codex session is pinned to the directory it was created in — a brief for another repo trips the
external-directory fence and asks a human who is not there (a round waited from 23:18 to morning
on exactly that, 2026-09-20). The wrapper now refuses such a resume up front.

## Models and effort

| model | id (opencode / codex) | $/M in·out | default effort |
|---|---|---|---|
| luna **(default)** | `openai/gpt-5.6-luna` / `gpt-5.6-luna` | 0.20 / 1.20 | **max** |
| terra | `openai/gpt-5.6-terra` / `gpt-5.6-terra` | 2 / 12 | high |
| sol | `openai/gpt-5.6-sol` / `gpt-5.6-sol` | 5 / 30 | medium |

On a bounded task all tiers usually produce the same correct diff (KIT-BTN bake-off 2026-09-17:
sol-low = terra-high = luna-max; luna-max 7.3× cheaper). **Pick by price when all tiers get it
right; pay for sol only when capability changes the outcome.** Effort → codex `-e` / opencode
`--variant`: `minimal|low|medium|high|max` (codex also `xhigh|ultra`). Under the ChatGPT oauth
credential `.usage` `cost` reads 0 — spend is against the subscription; report tokens. Check
`~/.claude/skills/bees/scripts/codex-usage` before a unit; a STALE reading is not a reading.

## Worktree or in place — pick by what the unit must verify

| unit needs | run it | verify |
|---|---|---|
| a diff only (pure C#, docs, data, a tool with its own tests) | **worktree**: `git worktree add -b oc/<unit> "$T/wt-<unit>" HEAD` | you compile/test the diff on the real project afterward — a worktree has no `Library`, so Unity cannot run there |
| Unity: compile, a suite, the live editor, a prefab/scene, a screenshot | **in place**: `-C ~/code/<project>` | the implementor verifies itself in the editor and reports counts; you re-run once |

An in-place unit **holds that Unity project** exactly like a Claude agent would: one driver per
compile domain (nono4u/Game compiles game-core and game-build sources through `file:` packages, so
those three are one domain). Before launching, check nothing else drives the domain — another
agent's uncommitted edits show up as a Safe-Mode compile error in your run (trial 2, 2026-09-20).
Edits land on the real branch; the fence and the brief carry the git discipline.

## Run it — OpenCode

`scripts/opencode-implement` ensures one `opencode serve` is up **with the fence loaded** (starts
it headless if absent; restarts an idle server that predates `opencode.jsonc`, refuses when one is
busy), refuses a `-s` resume whose session is pinned to another directory, runs one round via
`--dir` with `--auto`, watches it, and records the final message, session id and usage. The
watcher polls the server's pending-permission list every 15 s (local HTTP, no tokens): an ask for
this session means the unit reached outside the fence, so it rejects it, stops the run and appends
`Blocked: permission … <patterns>` to the out-file. Widen the fence or re-brief; never answer it by
hand in the TUI and carry on.

```bash
# in place (editor-drive) — the common Unity case
~/.claude/skills/codex-implementor/scripts/opencode-implement \
  -C ~/code/game-core -p "$T/brief.md" -o "$T/r1-out.txt" --title <unit>
# worktree (pure diff)
git worktree add -b oc/<unit> "$T/wt-<unit>" HEAD
~/.claude/skills/codex-implementor/scripts/opencode-implement -C "$T/wt-<unit>" -p "$T/brief.md" -o "$T/r1-out.txt"
# follow-up round, same session, same -C, context < 200k (warm inside 30 min)
... -p "$T/r2.md" -o "$T/r2-out.txt" -s "$(cat "$T/r1-out.txt.session")"
# harder unit
... -m openai/gpt-5.6-sol -e high
```

- Run via the **Bash tool with `run_in_background: true`**; you are notified on completion.
  `$T` is your scratchpad, never `/tmp`.
- Read **`<out-file>`** (final message) and the change (`git -C <dir> diff`, or the commits it
  reports). The `.log` is a liveness aid only — never read it into context. `.usage` is written
  by `scripts/extract-opencode-usage` (this channel) or `codex-review`'s
  `scripts/extract-codex-cli-usage` (CLI fallback) — the single source of truth for this shared
  by both this skill's wrappers and codex-review's; its `context_tokens` field is the same
  budget figure regardless of channel. Spend over the round is the sum of the `.log`'s
  `step_finish` events.
- **A quiet round is inspected, not waited on.** If the `.log` has not grown in ~20 min:
  `curl -s http://127.0.0.1:4096/permission` (should be `[]` — the watcher handles asks, this is
  the belt), then `scripts/opencode-sessions` (BUSY = a long tool call, e.g. a Unity suite; idle
  with no final message = the run died → `pkill -f "opencode run"`, resume the session).
- **Watching**: one server serves every repo; the TUI's `/sessions` shows only one directory —
  the server's start directory unless `--dir` is given, whatever folder you attach from — and
  never shows child sessions. Use `scripts/opencode-sessions` (cross-repo list, BUSY flag) or
  `scripts/opencode-sessions --attach` (fzf picker → attach). The wrapper prints the exact
  `opencode attach <url> --dir <dir> --session <id>` too.
- Leave `opencode serve` running across rounds and units; the wrapper reuses a live one.

**The fence** (`~/.config/opencode/opencode.jsonc`): `--auto` approves every "ask"; only `deny`
holds. `external_directory` is deny-by-default with `~/code/**`, `~/.claude/**`,
`~/.unity/**`, `~/Library/Logs/Unity/**` and the temp dirs allowed; bash denies `git reset --hard`,
`git checkout -- <path>`, `git stash`, `git clean`, force push, `rm -rf` on root/home. If a unit
reports a denied path it legitimately needed, the owner widens the fence; the unit never works
around it. **The server reads this file once, at startup**: after editing it, `pkill -f "opencode
serve"` when no session is busy — the wrapper does this itself when it finds a fenceless idle
server, and checks with `curl -s :4096/config | jq .permission`.

## Run it — codex CLI fallback

`scripts/codex-implement` hardcodes `< /dev/null`, reads the prompt from a file, writes only the
final message, records session id and usage, and **refuses a resume older than 30 minutes**.

```bash
~/.claude/skills/codex-implementor/scripts/codex-implement \
  -C <dir> -p "$T/brief.md" -o "$T/r1-out.txt" [-m gpt-5.6-sol -e high] [-t fast|standard]
# in place with the editor: -s danger-full-access ; follow-up within 30 min: -r "$(cat "$T/r1-out.txt.session")"
```

**The stdin trap.** `codex exec` appends stdin as a `<stdin>` block and, backgrounded, inherits an
fd that never EOFs — it **hangs forever** at `Reading additional input from stdin...`. Never remove
the wrapper's `< /dev/null`. Hung or working? after ~60–90 s `<out-file>.log` growing = working;
stuck on that line = hung → `pkill -f "codex exec"`, resume the session.

## Both channels load CLAUDE.md and skills — but not PATH helpers

A **new** session gets a preamble: read `~/.claude/CLAUDE.md`, every `CLAUDE.md` under the
directory (root first) and the skills under `~/.claude/skills` / `.claude/skills`. A resumed
session has it already. Two things the preamble does **not** give it — put them in the brief:

- **sibling-repo guidance** (`../game-core/Packages/*/CLAUDE.md`) when the unit touches those
  packages: nothing under the directory points there;
- the **unity-cli helper scripts by absolute path**: `unity-editor`, `unity-wait`, `unity-suite`,
  `unity-test` live in `~/.claude/skills/unity-cli/scripts/` and are **not on PATH** (trial 2 lost
  an attempt on `command not found`).

## The brief — what a Claude agent's brief has, nothing less

The implementor knows only the brief and the repo. Structure (bees §7 shape):

1. **Objective and acceptance criteria** — concrete and checkable: files it should touch, files it
   must not, the suite filter that proves it, the count it must reach.
2. **Where it runs** — worktree (cannot run Unity; report what it could not verify) or **in place**
   (which project it holds alone; the sibling projects it must not touch; that the project
   compiles at the start).
3. **Editor-drive contract** (in place): read `~/.claude/skills/unity-cli/SKILL.md` and the
   project's `.claude/skills/unity-ui*/SKILL.md`; helpers by absolute path; batch `unity test` with
   an absolute `--output` before any `--`, parse the XML, ignore stdout and the exit code; live
   editor via `unity-editor up` / `unity command …`; `unity close` before reporting, never kill.
4. **Commit gate** — "no suite XML in this session → no commit: leave the tree dirty, report
   `Blocked`" (a luna committed `0f4c12d` on a licensing hang, 22 red tests, 2026-09-19). Stage by
   explicit path only; the forbidden git commands are listed and denied by the fence.
5. **Owner WIP paths** never staged, edited or reverted — listed verbatim.
6. **Blocker cap** — two materially different attempts, then `STOP. Goal / Discovered / Blocker /
   Tried (both) / Options / Need from orchestrator`; stop immediately on a held resource or a
   missing decision; no retry loops.
7. **Style** — short, obviously correct, no restating comments, no unrelated refactors, classify
   every failure introduced / pre-existing (with evidence) / unknown.
8. **Return format** — `Outcome / Findings / Changes / Verification (commands verbatim + parsed
   counts) / Resources (editor state before/after) / Cost / Concerns / Need from orchestrator`.

Cite the contract file, never paraphrase values from memory. Quote a count only with the command
that produced it. Never send transcripts or source dumps.

## Accept on evidence, then a review

After each round: read the report, read the diff, and **re-run the acceptance suite once
yourself** (or hand it to a mechanical agent holding the resource) — a worktree diff is unverified
until compiled on the real project; an in-place report is checked, not trusted. Findings go back as
the next round's prompt in the same session (`-s`). Bees pairs a codex implementor with a
`bee-reviewer` (cross-vendor). When it is right: worktree → apply its commits/diff and
`git worktree remove`; in place → its commits are already on the branch.

## Bake-offs

One explicit worktree per arm (`git worktree add -b <arm> <path> HEAD`), same brief, one wrapper
run per arm, then diff the arms and cost them from the `.log` totals. Channels differ only in
interaction, never in output quality — compare models, not channels.
