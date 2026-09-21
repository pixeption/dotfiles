---
name: codex-review
description: Run a second-opinion code/design review with a codex-family model (default gpt-5.6-sol) — grounded against the actual repo source, as a multi-round conversation you steer. DEFAULT channel is OpenCode (`opencode-review`): a persistent, human-attachable, hard read-only session with no 30-min resume cliff (findings-application between rounds routinely exceeds it). FALLBACK is the `codex` CLI (`codex-review`, `codex exec --sandbox read-only`). Use whenever the user asks to "run codex", get a "codex review" / "codex sol review", have codex review a plan/design/PR/diff, or a second AI opinion before building. Covers both channels, session reuse across rounds, the review prompt shape, the verdict that ends the loop, and how to read the findings back.
---

# Codex review

A review loop with a **codex-family model** as a second opinion on a plan, a design or a diff.
**You are the lead; the reviewer is a helper.** It raises findings; you decide, apply them
yourself, and bring the result back. Verified against `opencode 1.18.31`, `codex-cli 0.155.0`,
default model `gpt-5.6-sol`.

Two channels to the **same models**; the method (prompt shape, rounds, verdict, reading findings
back) is identical. Only the harness differs.

| | **Default — OpenCode** (`opencode-review`) | **Fallback — codex CLI** (`codex-review`) |
|---|---|---|
| how | `opencode run --agent plan` against one persistent `opencode serve` | `codex exec` background process |
| read-only | **hard** — `--agent plan` denies the edit tool (verified: refuses even when told to edit); reads and read-only bash work, so it can run a suite or `unity command` to *check* a claim | codex `--sandbox read-only` |
| session | server-held, **no TTL** — resume any time | prompt cache **30-min TTL**; resume within it or start cold |
| live view | owner attaches to the session (`opencode-sessions --attach`) | read-only tail of the JSONL `.log` |
| use when | the default | OpenCode server won't start |

**Prefer the default.** A review loop spends minutes-to-hours *between* rounds while you apply
findings — routinely past the CLI's 30-minute cache cliff. OpenCode's session has no cliff.

## Run it — OpenCode

`scripts/opencode-review` ensures the server is up, runs one round via `--dir` with
`--agent plan --auto`, and records the final answer, session id and usage.

```bash
# round 1 — write the prompt to a file first (see "Prompt shape")
~/.claude/skills/codex-review/scripts/opencode-review \
  -C <repo> -p "$T/r1-prompt.txt" -o "$T/r1-out.txt"          # default openai/gpt-5.6-sol / medium
# every later round — same session, any time
~/.claude/skills/codex-review/scripts/opencode-review \
  -C <repo> -p "$T/r2-prompt.txt" -o "$T/r2-out.txt" -s "$(cat "$T/r1-out.txt.session")"
# harder review: -e high
```

- Run via the **Bash tool with `run_in_background: true`**; reviews take minutes. `$T` is your
  scratchpad, never `/tmp`.
- The out-file holds **only the final answer** (findings, suggestions, verdict). The `.log` is a
  liveness aid only — never read it into context. Under the ChatGPT oauth credential `.usage`
  `cost` reads 0; report tokens.
- **Usage limit**: check `~/.claude/skills/bees/scripts/codex-usage` first. A STALE reading is not
  a reading — it said "ok" once while the real 5-hour window was at 100% and three reviews came
  back truncated or empty (429). When STALE, read `x-codex-primary-used-percent` from the newest
  wrapper `.log`, or spend one cheap codex turn. Out of window → the review goes to `bee-reviewer`.
- **Watching**: one server serves every repo, but the TUI's `/sessions` shows a single directory
  (the server's start directory unless `--dir` is passed — your shell's cwd does not matter) and
  never shows child sessions. `~/.claude/skills/codex-implementor/scripts/opencode-sessions`
  lists across repos; `--attach` picks and attaches. The wrapper prints the exact attach command.
- `-C <repo>` is the repo the review reads. Point it at the repo that holds the artifact and the
  sources it composes over; name sibling repos in the prompt by absolute path.

## Run it — codex CLI fallback

Same review, codex's harness (`--sandbox read-only`, 30-min TTL). `scripts/codex-review`
hardcodes `< /dev/null`, reads the prompt from a file, writes only the final answer, records the
session id, and records context size (`<out-file>.usage`, from the log's last `token_count`
event's `last_token_usage` — never `total_token_usage`, a cumulative sum across the whole
session, not the current context).

```bash
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r1-prompt.txt" -o "$T/r1-out.txt" -e medium
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r2-prompt.txt" -o "$T/r2-out.txt" -r "$(cat "$T/r1-out.txt.session")"
```

**The stdin trap**: `codex exec` (and `resume`) appends stdin as a `<stdin>` block even with a
prompt argument; backgrounded, it inherits an fd that never EOFs and **hangs forever** at
`Reading additional input from stdin...`. Never remove `< /dev/null`. Hung or working? after
~60–90 s the `.log` growing = working; stuck on that line = hung → `pkill -f "codex exec"`, resume
by **explicit id**, never `--last`.

## One session for the whole loop

All rounds on one artifact run in **one session** (`-s` / `-r`). The reviewer keeps what it read
and every finding it raised, you accepted or rejected, so later rounds neither start cold nor
re-raise settled points. Start a **new** session only for a different artifact, or if the repo
changed under it far beyond the plan's edits. Your follow-up need not restate old findings:
reference them ("your round-2 F1–F4") and say what you did with each — **applied**, **applied
differently (how)**, or **rejected (why)**. A rejection with a reason is a decision, not an
invitation to re-argue; the reviewer may push back once with new evidence, and you rule.

## Prompt shape — grounded, bounded, findings-only

- **Point at the artifact and the real source it composes over** — the plan/PR/diff (a commit
  range, `git diff A..B`), plus the files/classes to verify claims against. It runs in the repo
  and can read them, run read-only commands, and (in place, read-only) run a suite or a `unity
  command` query to check a claim — invite that when the acceptance criteria are behavioural.
- **Scope it** — one feature/section/diff at a time. "The whole plan" always means the feature
  under review and the context it composes over, never the entire repository.
- **Ask for a findings list**: stable id (F1, F2, …, continuing across rounds), **severity**
  (High/Med/Low — or Critical/Major/Minor/Nit for a diff under bees), the claim, **why, citing
  file:line**, the **fix**. Ask it to **confirm what is sound** and **not to rewrite** the artifact.
- **Invite suggestions** as a separate, labelled, non-blocking list.
- **Ask for a terminal verdict** as the last line: `APPROVE` (no blocking High/Med findings remain)
  or `CHANGES_REQUIRED`. Suggestions never block. Only `APPROVE` ends the loop.

## Follow-up rounds: verify the delta, approve the whole

Each follow-up has **two mandatory parts**: (1) **fix verification** — for each applied finding:
actually fixed, complete, no regression; call out any incorrect or incomplete fix; (2)
**whole-artifact revalidation** — the artifact as it now exists, prioritizing changed areas and
their dependencies, raising anything new, not re-raising settled items. *Previous findings are
context and priority, not the scope.* Having applied findings is the trigger for another round;
if nothing changed, do not re-run. Later rounds mostly find regressions the fixes introduced —
lock each with a targeted test.

## Final whole-artifact pass before implementing

After a follow-up returns `APPROVE`, ask once more in the same session, with no reference to
individual findings: *"Read the artifact as it now stands, top to bottom, against the repository,
and say whether it is coherent and implementation-ready. End with the verdict."* Implementation
starts only after this returns `APPROVE`. If the session seems anchored (approving text you can
see is wrong), run this pass in a fresh session — the exception, since it re-pays the repo read.

## Reading the findings back

The out-file is only the final message — read it directly. Triage as lead: apply what you agree
with, apply differently or reject with a reason, treat suggestions as optional. Under bees, a
recheck returns `Fixed / Partial / Open` id lists scoped to the listed findings plus anything the
fix introduced; a clean review is valid.

## Alternative: `codex exec review`

Reviews the repository's uncommitted changes as a diff, without a prompt you write. Use this
skill's prompt flow for a **document or design**; `codex exec review` for a **raw diff** when you
want no framing. `< /dev/null` applies to both when backgrounded.
