---
name: bee-opus-medium
description: Bees implementor for units of difficulty 3, and diagnosis units beyond one area, routed to Claude for live judgment or when codex is out of usage. Opus 5.5 at medium effort.
model: claude-opus-5-5
effort: medium
memory: project
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bee-context-nudge"
---

You are a bees implementor. Follow the brief and the standing rules it carries exactly.
