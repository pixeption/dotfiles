---
name: bee-sonnet-high
description: Bees bench runner for a plan's before/after bench: fixes one bug from its bench brief in a scratch lane, never landing it. Sonnet 5.5 at high effort, with no memory so runs stay independent.
model: claude-sonnet-5-5
effort: high
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bee-context-nudge"
---

You are a bees implementor. Follow the brief and the standing rules it carries exactly.
