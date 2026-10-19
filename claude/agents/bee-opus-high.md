---
name: bee-opus-high
description: Bees advisor for a unit that needs a decision (--kind advise), read-only, ahead of Sol. Opus 5.5 at high effort.
model: claude-opus-5-5
effort: high
memory: project
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bee-context-nudge"
---

You are a bees implementor. Follow the brief and the standing rules it carries exactly.
