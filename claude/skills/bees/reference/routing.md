# Channels, validation and test levels

Read when choosing a unit's channel (codex worktree or in place, Claude instead of codex), deciding
who validates a codex diff or records a baseline, or running a check at a test level (a round's
filter, the post-integrate check, the phase gate). SKILL.md "Routing" holds the scores and buckets.

## Contents

- Channels
- Cost routing

## Channels

- **Channel.** Codex runs through `opencode-implement` by default, worktree or in place; the
  `codex-implement` CLI is the fallback when the OpenCode server won't start or the unit must run
  under an OS sandbox. Same models; the choice is harness.
- **Codex can drive the live editor.** Give it the unit **in place** in the real project (a
  worktree would need its own Library) with `opencode-implement -C <real checkout>`, holding that
  project's slot, and **put the editor card in the brief** (codex-implementor "What the session
  loads, and what it doesn't") — without it, codex cannot know the command surface exists.
- **Lanes.** In a repo that runs lanes (nono4u), who runs where — codex in place in a lane or `bee-*`
  sub-agents holding one for units that edit or drive an editor, sub-agents for read-only work and the gate — is its
  `workspaces` skill "Who works where"; follow the checkpoint and parent-review boundary in
  `reference/review.md` "Once per unit" before reusing a lane, so pieces are not accepted separately.
- **Claude instead of codex** only when the unit needs judgment a batch run cannot settle (a
  screenshot read, a live Play-mode check), or its codex round failed on a usage limit (SKILL.md
  "Routing"). Before routing for browser judgment, verify the assigned bee can open the target
  with a browser tool; otherwise make the live check an owner acceptance step.

## Cost routing

- Routing is whatever setup fixed. Orchestrator: Opus medium/high or Fable low.
- Diagnosis before implementation when the score is unknown; a scout before a diagnosis or a brief
  when you need a fact, not a verdict. The saving is that the evidence lands in your context once,
  compact.
- A codex unit's validation (compile, the fast lane) is part of its cost: do it
  yourself when the diff is small, otherwise hand it to `bee-sonnet-medium` holding the resource.
  A baseline before a unit whose acceptance compares against one goes to `bee-haiku-runner`.
- **Three test levels, each run once at its boundary**, so verification is not repeated within a level:
  - *Round* — the bee, holding its lane: the fail-before plus the item's test filter, its own and
    its callers' test classes, once at the end of the round
    (`templates/standing-rules-implementor.txt`); it never re-runs Game full or another unit's filter.
  - *Post-integrate* — you, after each landing, holding `integration`, as background Bash: the
    landed unit's filter on the target plus Game full, once (about 2 min), so the target never
    goes red. Landings are serialised: this check finishes before the next landing moves
    the target, and a red target is the next unit on a lane, ahead of the queue. It is a target
    check, not acceptance: a parallel piece that passes it is still unreviewed until its parent
    review.
  - *Phase gate* — the sharded runner, holding `integration` and `test-shards`: the full suites,
    once per phase, on a `bee-haiku-runner`, because it outlasts the 5-minute cache clock and a
    cold turn is cheapest on Haiku and keeps the run out of your context.
  At any level a GameCore run selecting more than one Integration test borrows the test shards
  (`workspaces` "Borrow the test shards"); Game runs in one editor, since its `file:` packages
  cannot shard. Every run records the SHA or worktree it tested, the command, the filter and the
  count — a count without them is not evidence. A bug first caught one level later than it should
  have been is an **escape**, logged `escape: <unit> <test> caught at <level>`: within the plan's
  escape bound the trimmed levels hold; past it the retro adds the missing check back at the level
  that should have caught it.
- A 1-cell smoke asserting preconditions (capture size, stack, viewport) before any multi-cell or
  live run.
