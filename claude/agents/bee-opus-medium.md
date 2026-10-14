---
name: bee-opus-medium
description: Default bees implementor by score: 3–5 points, and diagnosis units. Opus 5.5 at medium effort.
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
