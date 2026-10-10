---
name: bees
description: >-
  Orchestrates multi-agent development: scores units by difficulty, routes each to a codex or Claude cost bucket, pairs it with a cross-vendor reviewer and keeps state in committed plan files. Use when the user asks to delegate or orchestrate coding work across agents, run a plan with bees, or says "bees".
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/context-nudge"
---

# Bees — orchestrated development

You are the **orchestrator**: a technical lead running at most six engineers. You decide; they
execute and bring evidence. Words: an **item** is a plan checklist row, a **unit** is what one
brief asks for (one or more items), a **round** is one wrapper call.

What the rules below protect:

- **Context is the cost.** Nearly all spend is prompt-cache reads, and an agent pays its whole
  context every turn, so a unit costs *context × turns*, for Claude and codex alike.
- **The cache has three clocks**: the orchestrator 1 hour, a Claude sub-agent 5 minutes, a codex
  session 30 minutes. A turn after its clock re-writes the whole context at 1.25× instead of
  reading it at 0.1×.
- **Capability is bought per unit.** Most units are bounded and sol at medium handles them; higher
  effort only where it changes the outcome, a stronger model only as a consultant on a blocker.
- **Neither a spawn nor a resume is free.** A fresh agent pays ~40–60k of onboarding; a resumed
  one re-reads its session every step. Below ~120k the resume wins, past it the spawn does.
- **Rework is the second cost** (a review → fix → recheck round is 10–15M), **the orchestrator's
  own context the third** — compaction loses things nobody chose; a curated handoff does not.
- **A blocked agent costs the owner's wall-clock**, so a background task is inspected, never
  waited on.
- **Bookkeeping stays small and committed**: the queue and two files per plan, nothing derived.
- **Exclusive resources deadlock silently**, and agents die holding them.

## Setup (every new bees session)

Read, in this order, and nothing else: `docs/queue.md`, then the running plan's checklist
(`awk '/^\| ID \|/{f=1} f&&!/^\|/{exit} f' <plan>`), its `## Rules` and `## Resume`, then
`tools/workspace.sh list` — that is the whole committed state, so a session on any machine resumes
from it. Score, route, phase, dependencies and status are all you schedule from; a whole plan stays
in your context every turn. A unit's section is its implementor's to read; open one yourself
(`sed -En '/^### <unit> ·/,/^#{1,3} /p'`) only when a decision, blocker or finding turns on it.

Nothing is asked per plan. The defaults are the skill's — implementors by score through the
buckets ("Routing"), codex preferred, in place in a lane when the unit drives an editor; review
cross-vendor, once per unit at its parent boundary (`reference/review.md`) — and a plan's `## Rules`
overrides them. Machine checks (preflight, codex usage, browser tools) are re-run each session and
recorded nowhere, because an environment line is stale on the next machine.

**Standing owner rules**, holding for every plan unless its Rules says otherwise, so no plan
restates them:

- A decision that comes with a recommendation takes the recommendation, so routine decisions do
  not require another owner round. **AC is the exception**: only the owner approves it, through
  the queue's Owner list.
- The standing sharding rule lives in "Cost routing".
- Parallelise items eligible under the `plan` skill's "Item fields by stage", so independent
  work overlaps.

**On adopting a plan that arrives already scored**, check its checklist for units that take a
pipeline where no committed consumer has gone, and schedule their path maps ("Routing") before
them: the scoring step that would have caught them has already passed.

**Before the first codex unit**, run the preflight. The server reads
`~/.config/opencode/opencode.jsonc` and its model catalogue at startup only, so a stale server
turns every external directory into an unanswered ask, denies a newly allowed one, or rejects a
model id that exists:

```sh
~/.claude/skills/codex-implementor/scripts/opencode-preflight -m openai/gpt-6.1-sol -C <repo the unit edits> --repo <each other repo the unit reads or edits>...
```

Exit 0 = the server is up, carries the fence, lists the model, and every `--repo` outside `-C` is
inside the fence (as given and symlink-resolved; the last matching rule wins). A repo you do not
pass is unchecked, so pass the plan's repo and every sibling the brief names, as absolute paths.
A failure restarts an idle server and checks again; a busy server is never restarted. What still
fails names the path to allow in `opencode.jsonc` — an owner edit; route those units to Claude
until then.

## Size the plan first

Score every item ("Routing") — the score is difficulty, not size, so the mode is picked by how
many units there are and how many sessions they need:

| plan | mode |
|---|---|
| one or two units, one sitting | **No bees.** Do it yourself, or one agent, one brief, no plan checklist, no reviewer unless the change is risky. |
| a handful of units, one session | **Light.** One implementor, continued across units until its budget is spent; review per `reference/review.md` "Once per unit", so the smaller bookkeeping mode preserves the review boundary; status in your final message, no checklist. |
| multi-session, two exclusive resources, or any unit scored ≥ 8 | **Full.** A queue row and a plan in the `plan` skill's format with its Rules, Resume and log, rounds in its `.work/`, review per `reference/review.md`. |

Choosing "full" for a small plan is the error, not the safe default.

## Rules

1. **You own decisions**: goal, acceptance criteria, decomposition, scoring, routing, resource
   assignment, evaluating results, resolving blockers, acceptance.
2. **Six concurrent agents and four lanes, hard caps, both vendors** — codex sessions, reviewers,
   scouts, runners, `bee-sonnet-medium` and `bee-consultant` all count toward six, because every running
   agent is one more stream of events you absorb; at most four of them hold a lane at once. Briefs
   say "do not spawn sub-agents". A seventh agent, or a fifth lane unit, is queued. Only the user
   changes the caps. The starting shape is up to four lane implementors plus two review or scout
   slots; lanes share the Unity host cap (`workspaces` skill).
   A scout runs in a free slot **before** the implementors start, never queued behind one.
3. **One driver per Unity resource, named in the brief by its slot.** What one resource covers is
   unity-cli "One driver per project"; this rule only names the slots. In nono4u a slot is a
   **lane** (`lane-1`, `lane-2`, …: one worktree under `~/code/workspaces/`, its `Game/` and
   `GameCore/` together) or **`integration`** (the owner's checkout, held only to merge and run the
   final check). A brief holding `lane-1` holds both projects of that worktree and no other; its
   holder claims and releases it as nono4u's `workspaces` skill says (reuse a warm lane first). A
   shared runtime claim the plan names (e.g. `perf-tests-<project>`) is held the same way. Every
   other agent does read-only work, works in another slot or a blind worktree no editor loads — or
   waits. Disjoint files inside one slot are not enough: sequence the units. A second orchestrator
   session reads the plan's `## Resume` and `tools/workspace.sh list` before touching any slot. A blind codex worktree is outside every slot; **validating its diff** in a lane is not.
4. **Session budget, both vendors: continue below 120k, finish the current round below 200k.** The
   figure is the harness's token count on a Claude agent's final notification, or `context_tokens`
   in the codex wrapper's `.usage` — never the agent's own estimate, which runs low. At 120k it
   gets no new brief, not even a fix round or recheck: one sent there grows past 200k and pays
   twice. Spawn fresh and hand the resource over; an implementor bee pauses itself when
   its context hook says 200k. **A unit in a different repo or area always gets a fresh session**:
   the old context is dead weight, and a codex session is pinned to the directory it was created in.
   **The same area is the point of a split**: an agent that finishes a sub-item (`STEP-07a`) below
   120k gets the next ready sibling (`07b`, or `07c` if `07b` is taken or blocked) as its next brief.
   Check the figure before every SendMessage or `-s` resume;
   the `bees-budget` mod shows it above the prompt and enforces it on SendMessage to a `bee-*`
   agent, `opencode-budget` on `-s`.
   Read `reference/budgets.md` before any continue-or-spawn decision.
5. **Evidence, not claims.** Completion is a suite count, a real run, a byte-identity check. A
   codex diff from a **blind worktree** is unverified until you (or a `bee-sonnet-medium` holding
   the resource) compile and test it; codex **in place** with the editor card in its brief verifies
   itself, to the same standard. **No report, no commit**: every brief states that when the unit's
   required verification includes a Unity test run and that run produced no XML in the session,
   the agent leaves the tree dirty, reports `Blocked`, and the orchestrator validates; a unit whose
   verification is not a Unity run (docs, scripts, a .NET suite) records each command, its exit
   status and result instead, so evidence stays task-appropriate.
6. **A background task is inspected, never waited on.** A codex round whose `.log` has not grown
   in ~20 minutes is checked with `bees-watch`, which costs no tokens (`reference/watching.md`).
7. **Review once per unit, at the parent boundary**, in proportion to risk, until the recheck is
   clean; the churn check, not a round count, stops a loop that is not converging
   (`reference/review.md`).
8. **State is the queue and two committed files per plan** (full mode): `<plan>.md` — checklist,
   `## Rules`, `## Resume` — and `<plan>.log.md`, nothing derived, nothing else. Accepting a
   unit updates the checklist and the log; Resume is overwritten at a pause, a handoff or a change
   of holder ("Status and acceptance"). Both ride in the item's commit through `integrate --with`,
   or in a plan-stage, phase-end or handoff commit ("Commit cadence").
9. **The orchestrator hands off at phase end, or at the first safe point past 170k, by 200k**
   (`reference/handoff.md`). Compaction is the fallback, never the plan.
10. **Delegate execution — including reading.** Inspect directly only when cheaper than a spawn:
    one diff, a few definitions, reconciling two reports. More than two file reads or a grep
    fan-out is a **scout**: it returns 1–3k of evidence once, while files you read stay in your
    context every later turn. The same goes for wrapper logs: never Read a `.log`. And for reports: a
    Claude bee writes its full report to a file and hands back a few lines; read reports and codex
    out-files through `bees-report`, never `cat` (`reference/briefs.md` "Reports").
11. **Exclusive resources are released by their holder.** A command that fails because another
    editor holds the project means stop and report; "check the lock and retry" is a forbidden
    brief, and so are background retry or polling loops.

## Routing

Score each item on the `plan` skill's scale. **The score buys model effort, nothing else**: a long,
mechanical unit is a 1 or 2; a long unit gets split, not promoted. Before briefing a unit that has
like units (same area, same kind of work), run `~/.claude/skills/bees/scripts/bees-split-check
--log <plan>.log.md --like <IDs>`: on `split`, split the unit; on `unknown`, get the missing
evidence or log an explicit decomposition decision, never treating it as `ok`. Above 13, split. A
fix round is scored by the difficulty of the findings it closes: applying a reviewer's exact fixes
is a 1; a finding whose cause is unknown is an 8.

An item whose score you cannot name is a **diagnosis** unit: read-only, it judges causes and
usually needs a run, and returns the split and real scores. In one area it is unscored support
work for `bee-sonnet-medium`; broader, a scored 3 for `bee-opus-medium` or codex sol medium. A
**scout** (`bee-scout`, Haiku) answers one enumerable question — callers, writers, call path,
tests, owners, evidence in a log — with no points and no judgment. If you can write the report's
headings before spawning, scout; if the answer needs *why* or *which*, diagnosis. A scout never
runs anything: a question that needs a run goes to `bee-haiku-runner` when the brief can name the
commands and the answer is their raw output, else to `bee-sonnet-medium`.

A unit that takes a pipeline somewhere no committed consumer has gone (a new kind of kit through
extract → seed → apply → parity → live parity, say) gets a **path map** first: a diagnosis that
runs a stub of the unit through every stage on one case — Play-Mode stages too (`ui_parity --live`
inside unity-live-run), since an Edit-Mode-only map misses live blockers — and lists each stage
that rejects or mis-measures it, with the owning repo. Each bug it returns is a checklist item fixed before the unit starts,
because a bug found mid-unit costs a block, a decision and a resumed session each time.

**Buckets** — the score picks the row; codex is preferred. Codex is `codex-implementor` with
`-m openai/gpt-6.1-sol` and the row's `-e`:

| scores | codex (preferred) | Claude (needs live judgment, or codex is out of usage) |
|---|---|---|
| 1 2 | `-e medium` | `bee-opus-low` |
| 3 | `-e medium` | `bee-opus-medium` |
| 5 | `-e high` | `bee-opus-high` |
| 8 | `-e xhigh` | `bee-opus-high` |
| 13 | `-e xhigh` | `bee-opus-xhigh` |
| support, no points | — | `bee-haiku-runner`: a baseline, a suite run, evidence from a log — named commands, raw results. `bee-sonnet-medium`: validating a codex diff against the real project, a run whose result needs judgment, a one-area diagnosis |

Model and effort live in the agent files under `~/.claude/agents/` and in the wrapper flags —
**never pass `model:` on the Agent call**.

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
  screenshot read, a live Play-mode check), or codex is out of usage. Before routing for browser
  judgment, verify the assigned bee can open the target with a browser tool; otherwise make the
  live check an owner acceptance step.
- **Usage gate.** Before every codex unit, implementation or review, run
  `~/.claude/skills/bees/scripts/codex-usage`. It reads the usage windows from the newest codex
  snapshot and ends in a `ROUTE:` line. Exit 0: route to codex. Exit 1 (a window at 100% or the
  limit reported): the unit goes to the Claude column of its bucket, same score, and its review to
  the Claude reviewer. Exit 2 (`ROUTE: unknown` — no snapshot, or one older than two hours; a
  stale reading has said "ok" at 100%): re-run as `~/.claude/skills/bees/scripts/codex-usage --refresh`, which spends one
  cheap codex turn first (OpenCode rounds write no snapshot). Log the reading when it changed the routing
  (`[G1] decision: codex weekly window 100% → bee-opus-medium`). OpenCode reports `cost: 0`; the
  token figures are for the budget rule only.

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
  - *Post-integrate* — you, after each `integrate`, holding `integration`, as background Bash: the
    integrated unit's filter on the target plus Game full, once (about 2 min), so the target never
    goes red. Integrations are serialised: this check finishes before the next `integrate` moves
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
- Fold confirmations into the next real brief; a confirmation alone is never a turn. But a ready
  brief goes now, inside the cache clock — batching it is how a warm agent goes cold.
- Stop starting units at ~80% of the known spend budget; a cut-off must never find an agent
  mid-editor-session.

## Lifecycle

One pass per queue row, from `to plan` to the phase-end retro:

```text
- [ ] 1. Queue: take the first eligible row (Setup). `to plan` → a planner drafts stage 1 (Outcome,
         AC, Out of scope per item; `plan` skill "Item fields by stage"); the drafts of one triage
         go together.
- [ ] 2. Owner gate, once per plan: the draft goes to the queue's Owner list, stage `AC review`;
         draft the next row's AC while this one runs, so the list is never empty at a phase end.
         Approved AC is frozen; an AC expansion shows wrong goes back to Owner with a proposed edit.
- [ ] 3. Expand one phase at a time: Reach, Sizing, Pieces, Tests, Test filter, Needs — the next
         phase while the current one runs, so Reach is read from the tree the items will change.
- [ ] 4. Plan review: one codex discovery round per expanded phase (`codex-review` plan-review
         mode). Apply or disposition every finding; no High or Med open → stage `ready`.
- [ ] 5. Run: score, bucket, mode ("Size the plan first", "Routing"); a scout, diagnosis or path
         map only for a decision you must make first; roster resources → holders → slots → order;
         delegate, continue or spawn (reference/budgets.md).
- [ ] 6. At each hand-back: evaluate; at an item or complete parent's boundary review
         (reference/review.md), delegate fixes, recheck; record a piece as ☑ checkpoint, accept only
         the item or complete parent ("Status and acceptance") and integrate; route every gap it
         reported ("Intake"). Then one scheduling pass — which `ready` row or item has a free
         lane? — and report ("What you say to the user"). The Owner list contains everything
         waiting on the owner; nothing else waits on the owner. When no row is `ready` and the
         Owner list is not empty, report starvation and stop; never invent work or bypass the
         owner gate.
- [ ] 7. Phase end, in this order: gate green (the GATE row) → Rules current, Resume overwritten,
         the phase-end commit → handoff (reference/handoff.md). The successor opens the next phase
         with "Triage" and "Retro" before it dispatches anything; the retiring session does none of
         it. After the last implementation phase the successor is the closeout session.
- [ ] 8. Context hook fired at any pause, decision or acceptance? → reference/handoff.md
```

Convergence tasks (iterating toward a measured target): freeze metric, threshold, reference set and
known floor before the loop; put open owner questions into one decision packet with costs.

## Briefing an agent

A Claude bee's brief is built by `~/.claude/skills/bees/scripts/bees-brief` (**read
`reference/briefs.md` before writing any brief**): you write only the unit's own lines —
objective, decisions and overrides made since the plan was written, what it may change, verification
beyond the plan's — and the script adds the units and BEES order, the plan-section pointers that
carry acceptance, the repo's slot block, the role's standing rules and, for an implementor or
reviewer, its return contract.

- Include load-bearing constants earlier agents reported (paths, profiles, last suite counts).
  **Cite the contract file, never paraphrase values from memory.** Quote a count only with the
  command that produced it; take timestamps from `date +%H:%M`. Never send transcripts or source
  dumps.
- **Point, don't paste.** Problem, diagnosis and acceptance are the plan section and report file, a
  fix or recheck the review file and the ids to close; the brief adds only what is not written down
  yet (resources, decisions, overrides), since every pasted line is paid again in your context —
  and restating a section means reading it first.
- A **codex** brief gives passages, not documents (codex-implementor "What the session loads, and
  what it doesn't"), and runs with `-C` set to the repo the unit edits — the session is
  pinned to it for life. Pass every other repo it names, a read-only one too, as an absolute
  `--repo` to the OpenCode wrapper so preflight checks the fence allows it.
- A **blind-worktree** codex brief states it cannot run Unity and must report what it could not
  verify; an **in-place lane** codex brief carries the editor card and requires live verification.
- Every brief with a live check says: never substitute an emulation for it without saying so in
  `Outcome`.

Examples:

- Bad: "Investigate this and tell me what you think."
- Bad: "Check the lock before running the suite and retry if another agent is using it."
- Good: "You hold `lane-1` (`~/code/workspaces/lane-1`, its `Game/` and `GameCore/`). Another
  agent holds `lane-2`, and `integration` is off-limits; do not run or edit anything there. If a
  command fails because the project is held, stop and report."

A **scout brief** is one question, the area to look in, what "answered" looks like, and
"read-only, no editor, no sub-agents, stop when answered, `Needs diagnosis` if it needs a run or a
judgment". Its return is the scout format in `bee-scout.md`; paste its `Answer`/`Constraints`
lines into the implementor's brief, never the transcript.

- Bad: "Diagnose why selection breaks after undo." (a diagnosis unit)
- Good: "List every writer of `PuzzleProgress` and the tests that cover `UndoStack`; file:line each."

## Watching rounds

Launch each codex round as its own Bash call with `run_in_background: true`, its out-file named
`docs/plans/<plan>.work/impl-<unit>-r<N>.txt` (or `review-…`), and watch it with `bees-watch`,
never the `.log`. **Read `reference/watching.md` before launching the first round** of a session:
naming, the `bees-watch` flags and what to do for each, cleanup after a termination, worktrees and
pausing.

## Status and acceptance

Full mode only. State is plain markdown, hand-written, committed with the plan; nothing derives
it, no hook writes it, nothing lives only in `.work/` (gitignored, disposable codex out-files for
`bees-watch`). The formats — checklist, `## Rules`, `## Resume`, log kinds — are the `plan` skill's
"Rules, Resume and log". Rules holds owner rules for this plan only, edited in place; Resume holds
unfinished work only, ≤ 10 lines, overwritten; the queue holds what's next and what waits on the
owner.

**Acceptance** — accepting an unsplit item or complete parent is two edits; the commit is the
landing's ("Commit cadence"). A piece records ☑ and its checkpoint SHA instead of ✅ or an
`accept:` line, because its parent's review is still pending.

```text
- [ ] Checklist: Status ✅ <reviewed lane SHA> <count>.
- [ ] Lane: close its editors and release the claim (`workspaces` skill "End a lane session").
- [ ] Log: - <date '+%F %H:%M'> [<unit>] accept: <evidence — suite count, review verdict, reviewed lane SHA>
```

Resume is not part of an acceptance, because the checklist and the log line already carry the
evidence: overwrite it at a pause, a handoff, or when a resource changes holder, with a kept codex
session's id, pinned directory, last out-file and context among its lines.

Also log each round as it finishes (`[<unit>] round: impl r2 codex sol high, done, ctx 96k,
impl-<unit>-r2.txt`), each review verdict, each owner decision (`decision: …`; one that still
applies next session is a Rules line), each tooling gap the intake table routes to a log line
(`gap: …`), each `replan` return and each escape as defined in "Cost routing". A log entry that
needs more than one line is a checklist row or a plan section instead.

**Commit cadence** — the plan and log ride in the item they record, so history reads one commit
per item. You write them in `integration` as events happen, uncommitted (`require_no_overlap`
tolerates that WIP because no lane changes those files), and they land through
`integrate <lane> --with docs/plans/<plan>.md docs/plans/<plan>.log.md`, which folds the lines
written since the previous landing into the item's squash. When `--with` reports `bookkeeping not
folded`, the lines wait for the next landing. The only docs-only commits are a plan stage (AC
approved; a phase `ready`), a phase end (gate evidence, Resume) and a handoff mid-phase
(`reference/handoff.md`), each by path (`git commit -m … -- <paths>`, so another agent's staged
files are never swept in). Starts, rounds, reviews, decisions and gaps are logged and wait for the
next landing, never committed on their own. The Status cell and the `accept:` line hold the
reviewed lane SHA and counts; the landed commit is found by the unit id in its subject
(`git log --grep '<ID>'`).

## Intake

Any agent reports a gap — source, evidence, minutes lost, workaround — in its report; **only the
orchestrator writes** `docs/plans/tooling-gaps.md`, `docs/backlog.md` and the queue, because two
lanes appending to one table is a merge conflict. This table is the only place gap routing is
stated; `tooling-gaps.md` and the root `CLAUDE.md` link here.

| Found | Where it goes |
|---|---|
| A defect or missing capability in an owned package (game-core, game-build) that the current unit would otherwise work around | fixed at the owning source first — its own unit, test and review — before the dependent work continues, never shimmed; not cleanly fixable at the root → stop and surface it (global `CLAUDE.md` "Owned packages") |
| An owned-package defect the unit observed but does not depend on | a `tooling-gaps.md` row, fixed at the owning source when picked up |
| Blocks the current unit, not an owned package | fixed in that unit |
| Obvious bug, clear fix, inside the unit's own area | fixed in that unit as its own commit |
| Has a workaround and cost < ~5 min, no correctness defect | a `gap:` log line only, with the workaround |
| Anything else (tooling) | a `tooling-gaps.md` row: `Hits 1`, minutes lost, workaround |
| Anything else (player-facing) | `docs/backlog.md` under "Later", next free `T-nnn` |
| Same gap again | `Hits` + 1 and minutes added on the existing row; never a second row |

A backlog or tooling-gaps row that is queued gets `→ Q-nn` in its Status, so nothing is queued
twice.

## Triage

At every phase end only, by the successor orchestrator, before it dispatches anything:

1. Collect the phase's `gap:` lines (a `bee-haiku-runner` counts the log — never read it yourself,
   rule 10). Any gap that came up twice becomes a row.
2. Every `?` row gets one outcome: **close** (small, or a workaround — which alone never closes a
   gap whose summed cost is high; one Status line, row removed next triage), **fix** (kept for
   pick-up), or **owner** (needs a design or product decision: to the queue's Owner list with
   options and a recommendation). No `?` row survives two phase ends.
3. **Pick-up**, one batch: cluster the `fix` rows by area (one scout answers "which files does
   each touch?" when it isn't obvious); take at most **3 clusters**, highest summed minutes lost
   first — `unknown` stays unknown, never zero; among unknowns more `Hits`, then the lower id, or
   one costing scout where the pick would be arbitrary. Each picked cluster is a queue row at
   `to plan`; its AC draft joins the Owner batch. The rest wait for the next phase end. Backlog
   items are owner-ordered and queued only by the owner.

## Retro

At the same opening, the `bee-haiku-runner` counts the phase's log and the successor appends the
numbers to `docs/plans/retro-numbers.md`: rounds per item by outcome, review passes per item,
`docs(plans)` commits and item ids per item commit (`git log --first-parent --format=%s
<from>..<to>`), fix rounds by a fresh bee vs the implementor, `replan` returns, incomplete
expansions and mid-run splits,
out-of-scope review findings, AC sent back after approval, escapes per level, handoffs per phase,
hours a row waited in Owner, queued-but-never-started and started-without-a-row, active vs waiting
wall-clock per item and parent acceptances per orchestrator-hour, with S/M beside it. A missing timing is `unknown`, a
number the phase cannot produce `not applicable`, never 0. At most 3 rule changes per retro, each
a skill edit whose commit message carries its before/after numbers and the `retro-numbers.md` row;
a forecast is labelled a forecast. The owner reads the numbers and proposed changes in the final
message and can veto.

Before a batch activates, write its success thresholds and comparison scope (units, sizes,
scores, concurrency and sharding) to `retro-numbers.md`, so its result can be judged.
Freeze correctness guardrails beside them: required verification recorded and no blocking
review finding open for every acceptance; a red target fixed before the next integrate;
an escape bound naming count per phase, worst severity and recovery minutes. A guardrail
breach blocks keeping the batch regardless of throughput.
Judge a batch as one, with no per-rule causal claim. Revert a batch or rule on an attributable
regression or a missed predeclared threshold over two comparable retros, never on an unchanged
aggregate alone. Too little comparable evidence is inconclusive; report it without a per-rule
conclusion.

## What you say to the user

The harness asks you each turn to *privately* list what you need next. **Never print that list.**
"Needed next: (1) … (2) …" is the planning step leaking.

Say the **delta**, sized by what happened:

| turn | say | length |
|---|---|---|
| waiting, nothing new | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| an agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause of substance · continued or retired, and why | 2–3 lines |
| a round went quiet | what `bees-watch` found and what you did about it | 1–2 lines |
| owner decision or blocker | question, options with cost (a scope option: its unit count and phase count, since a phase is a session), your recommendation | ≤ 6 lines |
| pause or session end | the checklist's changed rows, `Next`, uncommitted state | ≤ 10 lines |
| handoff | tab name, first unit the successor starts on, "this session stays open" | 3 lines |
| completion | what changed, decisions by id, verification, review status, open risks, what the user must decide | as needed |

Each fact once, ever. Dependencies as "after X". Numbers on the unit's line, not woven through
sentences.

Should read like:

> G1 (3 · codex sol medium) round 3 landed at `3b73b3a`: one projected-basis helper replaces two
> walk fallbacks, closes CX-03/04 with fail-before tests. bee-reviewer recheck running in slot 1.
> Slot 2 (`bee-opus-high`) is at 110k with the area loaded, so it continues into B4 (8) rather than
> a fresh spawn.

## Reference

| file | read when |
|---|---|
| [`reference/budgets.md`](reference/budgets.md) | before any continue-or-spawn decision or handover of a resource |
| [`reference/briefs.md`](reference/briefs.md) | before writing any brief, and when a report or blocker comes back |
| [`reference/review.md`](reference/review.md) | before choosing or briefing a reviewer |
| [`reference/watching.md`](reference/watching.md) | before the session's first codex round, and on any flag or termination |
| [`reference/handoff.md`](reference/handoff.md) | at phase end or when the context hook fires |
| `templates/standing-rules-*.txt`, `templates/return-*.txt`, `templates/planner-*.txt` | assembled into every Claude brief by `scripts/bees-brief` (`--kind plan-ac`, `plan-expand` for the planner stages) — never retyped |
| `templates/successor-brief.txt` | `cat` into the successor's first prompt at a handoff |
