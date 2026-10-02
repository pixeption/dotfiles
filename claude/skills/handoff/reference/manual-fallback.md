# Manual handoff (fallback)

What `spawn-handoff.sh` automates, step by step — use it only when the script fails a precondition.

1. **Compose the handoff message first**, before spawning anything, with the structure in SKILL.md's "Compose the message".

2. **Pick a unique, mentionable session name.** Use only letters/digits/hyphens so it needs no quotes to `@`-mention:
   ```bash
   name="handoff-$(date +%H%M%S)"
   ```

3. **Spawn the new session in a kitty tab**, in the current repo, accepting inbound messages unattended so the handoff lands without an approval dialog:
   ```bash
   cwd="$(pwd)"
   wid=$(kitty @ launch --type=tab --env "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}" \
     --cwd="$cwd" --title="$name" \
     -- claude --name "$name" --model '<exact current model id>' --effort "$CLAUDE_EFFORT" \
     --settings '{"crossSessionInbound":"accept"}')
   echo "spawned window=$wid name=$name"
   ```
   The `--env` forwards a non-default config dir; kitty doesn't inherit it. Capture both `$name` and `$wid` — you need `$name` to message it, and `$wid` to close it later if the user asks. Use `--type=os-window` instead of `--type=tab` if the user prefers a separate window.

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
