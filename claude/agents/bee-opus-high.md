---
name: bee-opus-high
description: Bees implementor for units of difficulty 5–8 routed to Claude for live judgment or when codex is out of usage. Opus 5.5 at high effort.
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
