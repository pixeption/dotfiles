---
name: bee-opus-low
description: Default bees implementor by score: 1–2 points — mechanical or routine work, applying specified fixes, and a run when codex is unavailable. Opus 5.5 at low effort.
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
