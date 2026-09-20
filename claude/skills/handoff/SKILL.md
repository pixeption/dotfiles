---
name: handoff
description: Spawn a fresh Claude Code session in a new kitty tab and hand off the current work to it directly via cross-session messaging, instead of writing a handoff document. Use when the user wants to "hand off", "continue in a new/fresh session", "start a clean session and keep going", or "pass this to another session". Creates the new session, waits for it to register, sends it a full handoff message, then reports back. This session stays open.
---

# Handoff to a fresh session

Replace the write-a-doc → open-new-session → read-doc → close-old dance with one step: spawn a new interactive Claude Code session in a kitty tab and deliver the handoff to it directly over cross-session messaging (`ListAgents` + `SendMessage`). The user takes over the new tab; **this session stays open** as a fallback.

## Prerequisites (already verified for this machine, re-check if anything fails)

- `claude --version` ≥ 2.1.224 (cross-session messaging). This machine had 2.1.263.
- kitty remote control is live: `kitty @ ls >/dev/null 2>&1` succeeds and `$KITTY_LISTEN_ON` is set. If `kitty @` fails, remote control is off — tell the user to enable `allow_remote_control yes` + a listen socket in kitty.conf, or fall back to opening the tab themselves and giving you the session name.

## One-shot (preferred): `scripts/spawn-handoff.sh`

The whole dance below collapses to a single command, because `claude [options] [prompt]` accepts a
positional prompt: spawn the new session **with the handoff as its first prompt**, so it starts
working immediately — no process-wait, no `ListAgents`, no `SendMessage` round trip.

1. **Compose the handoff message** exactly as in step 1 of the manual procedure (same structure and
   rules — it is the new session's first turn, so quality is everything). Write it to a file, or pipe
   it on stdin.
2. **Run the script** (beside this skill), passing the message file (or stdin). **Name the tab after
   the work with `--task`** so it is self-describing in `ListAgents` and the kitty tab bar:
   ```bash
   ~/.claude/skills/handoff/scripts/spawn-handoff.sh \
     --cwd "$(pwd)" --task "fix pipeline-ui frictions" /path/to/message.txt
   # or: printf '%s' "$msg" | .../spawn-handoff.sh --cwd "$(pwd)" --task "…"
   ```
   `--task` is slugified into a mentionable name plus an `-HHMMSS` suffix for uniqueness
   (`fix-pipeline-ui-frictions-170939`). Use `--name` instead to set an exact name verbatim (no
   suffix); with neither it falls back to `handoff-HHMMSS`. The new session runs on
   **`claude-opus-4-8` at `medium` effort by default**; override with `--model <alias|full-id>` and
   `--effort low|medium|high|xhigh|max` when the task wants more (or less) horsepower — note the bare
   `opus` alias now resolves to Opus 5, so the default pins the full `claude-opus-4-8` id. The script
   resolves the `claude` binary
   (even off a non-login PATH), checks kitty remote control, opens a tab in `--cwd`, and launches
   `claude --name <name> --settings '{"crossSessionInbound":"accept"}' "<message>"`. The message is
   expanded into a single argv element by the script's own shell, so kitty never tokenizes it —
   newlines, quotes, `$`, backticks in the handoff are all safe. It prints `NAME=<name>` and
   `WINDOW=<id>`; capture both. Flags: `--os-window` for a separate window, `--dry-run` to preview
   without spawning.
3. **Confirm and report.** Optionally `ListAgents` to see `<name>` come up busy (it is already acting
   on the handoff). Then report as in step 6 below: give the tab name and "switch to the `<name>` tab
   to drive it; this session stays open." Do **not** close this session.

Only the message text crosses — this is not context/file transfer (see the note at the end). If the
script fails a precondition (kitty RC off, no `claude` binary), fall back to the manual procedure.

## Procedure (manual / fallback — what the script automates)

1. **Compose the handoff message first, before spawning anything.** This is the whole point — the message replaces the handoff document. Write it yourself from the current conversation. Make it self-contained plain text; the new session gets *only this text*, never our history or files. Structure it as:
   - **One-line summary** on the first line (this becomes the preview the user sees).
   - **What we did / current state** — the concrete changes, decisions made, and anything half-finished.
   - **Next steps** — the ordered list of what the new session should do.
   - **Key files** — reference them by path (e.g. `Assets/_Game/Scripts/...`). You may `@`-mention paths; the receiving session can open them with its own tools (nothing is auto-attached).
   - **Gotchas / constraints** — anything that would bite a fresh context (build profile, a flaky test, a decision *not* to do something).

   Keep it tight and factual. Don't dump the transcript. Size cap is ~1M chars — not a concern, but brevity helps the receiver.

2. **Pick a unique, mentionable session name.** Use only letters/digits/hyphens so it needs no quotes to `@`-mention:
   ```bash
   name="handoff-$(date +%H%M%S)"
   ```

3. **Spawn the new session in a kitty tab**, in the current repo, accepting inbound messages unattended so the handoff lands without an approval dialog:
   ```bash
   cwd="$(pwd)"
   wid=$(kitty @ launch --type=tab --cwd="$cwd" --title="$name" \
     -- claude --name "$name" --settings '{"crossSessionInbound":"accept"}')
   echo "spawned window=$wid name=$name"
   ```
   Capture both `$name` and `$wid` — you need `$name` to message it, and `$wid` to close it later if the user asks. Use `--type=os-window` instead of `--type=tab` if the user prefers a separate window.

4. **Wait for it to register**, then confirm with `ListAgents`. A fresh session takes a few seconds to boot and bind its inbox socket:
   ```bash
   for i in $(seq 1 40); do
     pgrep -f "claude --name $name" >/dev/null && break
     sleep 0.5
   done
   echo "process up"
   ```
   This is a bounded wait loop (not an indefinite foreground `sleep`). Then call the **`ListAgents`** tool and confirm `$name` appears in the reachable sessions. If it isn't there yet, wait once more and re-list. If it never appears after ~20s, the session failed to start or messaging is off — check the new tab for an error and report to the user rather than sending blind.

5. **Send the handoff.** `SendMessage` is a deferred tool — load it first, then send:
   - `ToolSearch("select:SendMessage")`
   - `SendMessage({ to: "<name>", message: "<the handoff text from step 1>" })`

   Because the new session is idle at its prompt, Claude Code starts a new turn with your message — the new session begins acting on the handoff immediately, with the user watching in that tab.

6. **Report back in this session.** Confirm delivery, give the tab title/name, and one line: "switch to the `<name>` tab to drive it; this session stays open." Do **not** close this session — the user chose to keep it as a fallback.

## Notes / failure modes

- **Approval hold instead of delivery:** if the send is held for approval, the `--settings '{"crossSessionInbound":"accept"}'` was dropped (e.g. bad JSON quoting) — the user can approve the dialog in the new tab once, or re-spawn with the setting fixed.
- **Name collision:** if a live session already uses `$name`, Claude Code renames the new one to a variant, so the name you `@`-mention may not match. The timestamp suffix makes this rare; if `ListAgents` shows a variant, message the variant.
- **Don't hand off denied work:** never ask the new session to do something that was denied or blocked in this session — route that back to the user instead. Permission boundaries are per-session; the fresh session will hit its own prompts.
- **This is not context transfer.** Only the message text crosses. If the user actually wants the *same conversation* (full context/files) in another terminal, that's `claude --resume` / session resume, not this skill — say so.
