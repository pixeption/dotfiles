# Channels, validation and test levels

Read when choosing a unit's channel (codex worktree or in place, codex instead of Claude), deciding
who validates a codex diff or records a baseline, or running a check at a test level (a round's
filter, a gate). SKILL.md "Routing" holds who does what by score.

## Contents

- Channels
- Cost routing

## Channels

- **Channel.** Codex runs through `codex-round implement`, worktree or in place, on OpenCode by
  default; the codex CLI is its fallback when the OpenCode server won't start or the unit must run
  under an OS sandbox. Same models; the choice is harness.
- **Codex can drive the live editor.** Give it the unit **in place** in the real project (a
  worktree would need its own Library) with `codex-round implement -C <real checkout>`, holding that
  project's slot, and **put the editor card in the brief** (codex-implementor "What the session
  loads, and what it doesn't") — without it, codex cannot know the command surface exists.
- **Lanes.** In a repo that runs lanes (nono4u), who runs where — codex in place in a lane or `bee-*`
  sub-agents holding one for units that edit or drive an editor, sub-agents for read-only work and the gate — is its
  `workspaces` skill "Who works where"; a lane is reused once its item is accepted and landed
  (`reference/review.md` "Once per unit").
- **Codex instead of Claude** only on a Claude usage limit (SKILL.md "Routing"). Before routing
  a Claude bee for browser judgment, verify it can open the target with a browser tool; otherwise
  make the live check an owner acceptance step.

## Cost routing

- Routing is whatever setup fixed. Orchestrator: Opus medium/high or Fable low.
- Diagnosis before implementation when the score is unknown; a scout before a diagnosis or a brief
  when you need a fact, not a verdict. The saving is that the evidence lands in your context once,
  compact.
- A codex unit's validation (compile, the fast lane) is a codex run holding the resource, per SKILL.md "Routing".
  A baseline before a unit whose acceptance compares against one is a codex run.
- **Two test levels, each run once at its boundary**, so verification is not repeated within a level:
  - *Round* — the bee, holding its lane: the item's test filter and any red run the fail-before rule requires, its own and
    its callers' test classes, once at the end of the round
    (`templates/standing-rules-implementor.txt`); never a full suite or another item's filter.
  - *Gate* — each GATE row (`plan` skill "Review, landing and the gate"): the full suites on its
    target SHA, holding `test-shards`, and `integration` only while it copies that SHA
    (`workspaces` "Integrate a lane"), as a codex run, because it outlasts a Claude sub-agent's
    5-minute cache clock and keeps the run out of your context.
  At any level a GameCore run selecting more than one Integration test borrows the test shards
  (`workspaces` "Borrow the test shards"); Game runs in one editor, since its `file:` packages
  cannot shard. Every run records the SHA or worktree it tested, the command, the filter and the
  count — a count without them is not evidence. A bug first caught one level later than it should
  have been is an **escape**, logged `escape: <unit> <test> caught at <level>`: within the plan's
  escape bound the trimmed levels hold; past it the retro adds the missing check back at the level
  that should have caught it.
- A 1-cell smoke asserting preconditions (capture size, stack, viewport) before any multi-cell or
  live run.
