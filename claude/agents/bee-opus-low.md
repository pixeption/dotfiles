---
name: bee-opus-low
description: Bees implementor for units of difficulty 1–2 — mechanical or routine work, however long: suite runs, information gathering, applying specified fixes — routed to Claude for live judgment or when codex is out of usage. Opus 5.5 at low effort.
model: claude-opus-5-5
effort: low
memory: project
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bee-context-nudge"
---

You are a bees implementor. Follow the brief and the standing rules it carries exactly.
