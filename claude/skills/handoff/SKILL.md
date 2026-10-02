---
name: handoff
description: >-
  Spawns a fresh Claude Code session in a new kitty tab and hands it the current work as its first prompt, instead of writing a handoff document; this session stays open. Use when the user wants to "hand off", "continue in a new/fresh session", "start a clean session and keep going", or "pass this to another session".
---

# Handoff to a fresh session

Spawn a new interactive Claude Code session in a kitty tab whose first prompt is the handoff
message, so it starts working at once. The user takes over the new tab; **this session stays open**
as a fallback.

## Prerequisites

- `claude --version` ≥ 2.1.224 (cross-session messaging).
- kitty remote control is live: `kitty @ ls >/dev/null 2>&1` succeeds and `$KITTY_LISTEN_ON` is
  set. If not, tell the user to enable `allow_remote_control yes` + a listen socket in kitty.conf,
  or to open the tab themselves and give you the session name.

## Compose the message

Write it yourself from the current conversation, before spawning anything — it replaces the handoff
document and is the new session's whole context (it never sees our history or files). Plain text,
self-contained:

- **One-line summary** on the first line (the preview the user sees).
- **What we did / current state** — concrete changes, decisions, anything half-finished.
- **Next steps** — the ordered list of what the new session should do.
- **Key files** — by path; `@`-mentions are fine, nothing is auto-attached.
- **Gotchas / constraints** — what would bite a fresh context (build profile, a flaky test, a
  decision *not* to do something).

Tight and factual; never the transcript.

## Spawn it

Write the message to a file (or pipe it on stdin) and run:

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/skills/handoff/scripts/spawn-handoff.sh \
  --cwd "$(pwd)" --task "fix pipeline-ui frictions" \
  --model '<exact current model id>' /path/to/message.txt
```

- **`--model` is required** — the exact model id from your system prompt, quoted (ids can carry
  `[...]`). The model is not in the environment, and without it the handoff would land on the CLI
  default; the script exits 2. Effort is inherited from `$CLAUDE_EFFORT`. Override either only when
  the user asks for a different model or effort.
- **`--task`** names the tab after the work: slugified plus an `-HHMMSS` suffix
  (`fix-pipeline-ui-frictions-170939`). `--name` sets an exact name with no suffix; with neither,
  `handoff-HHMMSS`.
- `--os-window` opens a separate window; `--dry-run` previews without spawning.

The script resolves `claude` even off a non-login PATH, forwards `CLAUDE_CONFIG_DIR` (kitty children
get kitty's env, not yours), and launches `claude --name <name> --settings
'{"crossSessionInbound":"accept"}' "<message>"` with the message as one argv element, so newlines,
quotes, `$` and backticks are safe. It prints `NAME=<name>` and `WINDOW=<id>`; capture both.

If it fails a precondition (kitty remote control off, no `claude` binary), read
[reference/manual-fallback.md](reference/manual-fallback.md) and follow it.

## Report

Optionally `ListAgents` to see `<name>` come up busy. Then give the tab name and "switch to the
`<name>` tab to drive it; this session stays open." Do **not** close this session.

Done when the new tab is running on the handed-off model and the user has its name.

## Notes / failure modes

- **Approval hold instead of delivery:** if the send is held for approval, the `--settings '{"crossSessionInbound":"accept"}'` was dropped (e.g. bad JSON quoting) — the user can approve the dialog in the new tab once, or re-spawn with the setting fixed.
- **Name collision:** if a live session already uses `$name`, Claude Code renames the new one to a variant, so the name you `@`-mention may not match. The timestamp suffix makes this rare; if `ListAgents` shows a variant, message the variant.
- **Don't hand off denied work:** never ask the new session to do something that was denied or blocked in this session — route that back to the user instead. Permission boundaries are per-session; the fresh session will hit its own prompts.
- **This is not context transfer.** Only the message text crosses. If the user actually wants the *same conversation* (full context/files) in another terminal, that's `claude --resume` / session resume, not this skill — say so.
