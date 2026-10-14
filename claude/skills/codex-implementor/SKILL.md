---
name: codex-implementor
description: >-
  Runs codex-family jobs through one codex-round script over OpenCode, falling back to the codex CLI: command runs (suites, baselines, gates, render batches) in a claimed lane, and in-place implementation when Claude is out of usage. Use when the user asks to have codex run tests or commands, to implement with codex, or to delegate a unit to codex. For a review use codex-review.
---

# Codex implementor

**You are the lead; codex executes and brings evidence.** Accept on a suite count or a real run.

## Run it

One `codex-round` line per job, its own Bash call with `run_in_background: true`. Before a session's
first round read [`~/.claude/skills/codex-review/reference/opencode-channel.md`](../codex-review/reference/opencode-channel.md).

```bash
S=~/.claude/skills/codex-implementor/scripts
$S/codex-round run       -C ~/code/workspaces/<lane> -p "$T/brief.md" -u <unit> -o "$W/run-<unit>-r1.txt"
$S/codex-round implement -C ~/code/workspaces/<lane> -p "$T/brief.md" -u <unit> -o "$W/impl-<unit>-r1.txt"
$S/codex-round implement ... -s "$(cat "$W/impl-<unit>-r1.txt.session")"   # resume; add -e high for a harder unit
$S/codex-round stop <out-file>                                             # stop a running round
$S/opencode-preflight --stop                                               # stop-server: only when idle
```

Exit 0 finished · 1 failed or refused · 2 usage · 3 codex unavailable; then read the out-file and the change.

## Models and effort

| model | id (opencode / codex) | default effort |
|---|---|---|
| sol **(default)** | `openai/gpt-6.1-sol-fast` / `gpt-6.1-sol` | **medium** |
| luna | `openai/gpt-6-luna` / `gpt-6-luna` | max |

Raise `-e` only when capability changes the outcome: `low|medium|high|xhigh|max` (codex also `ultra`).

## Resume or fresh

Resume only in the same directory on the same channel; past the session budget the hook refuses, so start fresh.

## What the session loads, and what it doesn't

- A new session reads `~/.claude/CLAUDE.md` and the repo's `CLAUDE.md` files; everything it reads stays in context, so give it passages, never documents.
- Under bees, the plan path and unit-section pointer; otherwise a contract quoted or cited as `path:start-end`.
- The `CLAUDE.md` of the one game-core package the unit edits (`GameCore/Packages/<package>/CLAUDE.md`).
- For a lane, the editor card ([`templates/editor-card.md`](templates/editor-card.md)) in place of the `unity-cli` skill.

## Briefs

`cat` a template into `$T/brief.md` and fill every `<…>`: [`templates/brief-implement.md`](templates/brief-implement.md)
to implement, [`templates/brief-run.md`](templates/brief-run.md) to run commands.
