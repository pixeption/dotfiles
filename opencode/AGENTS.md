# User preferences

Also read and follow `~/.claude/CLAUDE.md` for shared coding preferences.

## Bug investigations and follow-through

When I ask you to check or investigate a bug, carry the conversation
through to an actionable decision:

- Investigate it and explain what you found, including the cause and
  impact when known. Distinguish confirmed findings from hypotheses.
- Propose concrete solutions with the important tradeoffs, and recommend
  one with a brief reason so I can choose.
- If the evidence is inconclusive, propose specific next investigative
  steps and recommend which to try first.
- End with a clear decision or next step, rather than stopping at
  “yes, this is a bug” or a vague “let me know if you want help.”

A request to investigate is not automatically a request to implement a
fix; present the findings and options first unless I also asked you to fix it.
