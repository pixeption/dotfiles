# Claude Code config

**This directory is `~/.claude`** — `~/.claude` is a symlink to it, so Claude Code needs no
`CLAUDE_CONFIG_DIR` override and writes its config files here directly.

Only `CLAUDE.md`, `settings.json`, `statusline.sh` and `skills/` are tracked. Everything else
Claude Code puts here (sessions, projects, history, caches, credentials, plugins) is machine-local
runtime state, ignored by the whitelist in `.gitignore`.

⚠️ Because live state lives in the working tree, **never run `git clean -x`/`-X` in `~/.config`** —
it would delete sessions, history and credentials.

`~/.claude_work` (the `CLAUDE_CONFIG_DIR` work profile) is local-only and not in this repo.

## Install on a new machine

```bash
# after cloning the dotfiles repo to ~/.config
mv ~/.claude ~/.claude.bak 2>/dev/null   # if Claude Code already ran here
ln -s ~/.config/claude ~/.claude

(cd ~/.claude/skills/img-diff && npm ci)   # Playwright, used by scripts/shoot.mjs
claude          # log in: credentials are not synced
```

Then, if the machine's username isn't `vbnn2`, fix the absolute status-line path in
`settings.json`:

```json
"statusLine": { "type": "command", "command": "/Users/<you>/.claude/statusline.sh", "padding": 0 }
```

`settings.json` is rewritten in place by Claude Code (`/config`, theme/model changes, and the
growing `autoMode.environment` block), so expect it to show up dirty — commit it when the change
is one you want on both machines.

## Per-machine prerequisites

The skills shell out to tools that are not part of this repo:

| Skill | Needs |
|---|---|
| `img-diff` | `node`, `npm ci` in the skill dir, `python3` with `pillow`, `numpy`, `scikit-image` |
| `playwright-cli` | `npx playwright` |
| `unity-cli` | `unity` CLI on `PATH` (the scripts prepend `~/.unity/bin`) |
| `codex-review` | `codex` CLI |
| `handoff` | `kitty` with remote control enabled |
| `statusline.sh` | `jq` |

`skills/img-diff/scripts/parity-v1/` are frozen project-specific one-offs; they take their paths
from env vars (`PARITY_SCRATCH`, `PARITY_BASE`, `PARITY_OUT`, `UNITY`, `PROJECT_PATH`).
