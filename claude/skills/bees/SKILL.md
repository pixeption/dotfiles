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
execute and bring evidence. An **item** is a plan checklist row, a **unit** is what one brief asks
for (one or more items), a **round** is one wrapper call.

Context × turns is the cost the rules protect (`reference/budgets.md` "What the rules protect").

## Setup (every new bees session)

Read, in order, nothing else: `docs/queue.md`, the plan's open checklist rows
(`awk '/^\| ID \|/{f=1} f&&!/^\|/{exit} f&&!/\| ✅/' <plan>` — a ✅ row's evidence would be re-read
every turn), its `## Rules` and `## Resume`, then `tools/workspace.sh list` — the whole committed
state, so any machine resumes from it. Schedule from score, route, phase, dependencies and status;
open a unit's section (`sed -En '/^### <unit> ·/,/^#{1,3} /p'`) only when a decision, blocker or
finding turns on it — it is its implementor's to read.

Nothing is asked per plan; its `## Rules` overrides the defaults (buckets by score, codex preferred,
in place in a lane when it drives an editor; review cross-vendor, once per unit at its parent
boundary) and these **standing owner rules**: a decision with a recommendation takes it — except AC,
which only the owner approves, through the queue's Owner list; parallelise items eligible under the
`plan` skill's "Item fields by stage"; sharding is `reference/routing.md` "Cost routing"'s.

**Phase boundaries** — [`reference/phase-boundaries.md`](reference/phase-boundaries.md): read its
planning, sizing or adoption passage for those, "Preflight" before the session's first codex unit,
"Triage" and "Retro" when opening a phase after a phase-end handoff.

## Rules

1. **You own decisions**: goal, AC, decomposition, scoring, routing, resources, evaluating
   results, blockers, acceptance.
2. **Six concurrent agents and four lanes, hard caps, both vendors** — every agent (codex,
   reviewer, scout, runner, consultant) counts, being one more event stream you absorb; at most
   four hold a lane; a seventh or a fifth lane unit is queued; only the user changes the caps.
   Briefs say "do not spawn sub-agents". Start with up to four lane implementors plus two review or
   scout slots (lanes share the Unity host cap, `workspaces` skill); a scout runs in a free slot
   **before** the implementors start.
3. **One driver per Unity resource, named in the brief by its slot** (unity-cli "One driver per
   project"): in nono4u a **lane** (`lane-<n>`, one worktree with its `Game/` and `GameCore/`) or
   **`integration`** (the owner's checkout, only to merge and run the final check), claimed and
   released by its holder per the `workspaces` skill (reuse a warm lane first); a shared runtime
   claim the plan names (`perf-tests-<project>`) likewise. Others work read-only, in another slot
   or a blind worktree no editor loads — or wait; disjoint files in one slot are not enough. A
   second orchestrator session reads `## Resume` and `tools/workspace.sh list` before touching a
   slot. A blind codex worktree is outside every slot; validating its diff in a lane is not.
4. **Session budget, both vendors: continue below 120k, finish the round below 200k** — the
   harness's count or `.usage` `context_tokens`, never the agent's estimate. At 120k no new brief,
   not even a fix or recheck (it would pass 200k and pay twice): spawn fresh, hand the resource
   over; a bee pauses itself at 200k. **Another repo or area gets a fresh session** (a codex
   session is pinned to its directory); **the same area is the point of a split** — a sub-item
   finished below 120k earns the next ready sibling. Check before every SendMessage or `-s` (the
   `bees-budget` and `opencode-budget` mods enforce it); read `reference/budgets.md` before any
   continue-or-spawn decision.
5. **Evidence, not claims**: a suite count, a real run, a byte-identity check. A blind-worktree
   codex diff is unverified until you or a `bee-sonnet-medium` holding the resource compile and
   test it; codex in place with the editor card verifies itself. **No report, no commit**: a Unity
   test run with no XML this session leaves the tree dirty, `Blocked`, for you to validate; other
   verification records each command, exit status and result. A suite count counts only beside its
   `report: … · finished <HH:MM>` line, timed to the round — never open the XML.
6. **A background task is inspected, never waited on** ("Watching rounds").
7. **Review once per unit, at the parent boundary**, in proportion to risk, until the recheck is
   clean; the churn check, not a round count, stops a loop that is not converging
   (`reference/review.md`).
8. **State is the queue and two committed files per plan** (full mode): `<plan>.md` — checklist,
   `## Rules`, `## Resume` — and `<plan>.log.md`, nothing derived ("Status and acceptance").
9. **Hand off at phase end, or at the first safe point past 170k, by 200k**
   (`reference/handoff.md`). Compaction is the fallback, never the plan.
10. **Delegate execution, including reading.** Inspect directly only when cheaper than a spawn: one
    diff, a few definitions, reconciling two reports. More than two file reads or a grep fan-out is
    a **scout**, whose 1–3k of evidence lands once, while files you read stay every later turn.
    Never Read a `.log` or `cat` a report: read a report or codex out-file with
    `~/.claude/skills/bees/scripts/bees-report <file>...`, adding in the same call `--finding <IDs>`
    for whole finding blocks and `--lane <path> --since <base sha>` for the lane's commits and dirty
    files, instead of follow-up reads.
11. **Exclusive resources are released by their holder.** A command failing because another editor
    holds the project means stop and report; "check the lock and retry" is a forbidden brief, and
    so are background retry or polling loops.

## Routing

Score each item on the `plan` skill's scale. **The score buys model effort, nothing else**: a long,
mechanical unit is a 1 or 2; a long unit is split, not promoted, as is one above 13. Before briefing
a unit with like units (same area, same kind of work), run `~/.claude/skills/bees/scripts/bees-split-check
--log <plan>.log.md --like <IDs>`: on `split`, split; on `unknown`, get the evidence or log an
explicit decomposition decision, never treating it as `ok`. A fix round scores the findings it
closes: a reviewer's exact fixes are a 1, a finding of unknown cause an 8.

An item you cannot score is a **diagnosis** unit: read-only, it judges causes, usually runs
something, and returns the split and real scores — in one area unscored work for
`bee-sonnet-medium`, broader a scored 3. A **scout** (`bee-scout`) answers one enumerable question —
callers, writers, call path, tests, owners, evidence in a log — with no points and no judgment: if
you can write the report's headings before spawning, scout; if the answer needs *why* or *which*,
diagnosis. A question that needs a run goes to `bee-haiku-runner` when the brief can name the
commands and the answer is their raw output, else to `bee-sonnet-medium`.

A unit taking a pipeline where no committed consumer has gone gets a **path map** first
(phase-boundaries "Path maps").

**Buckets** — codex is `codex-implementor` with `-m openai/gpt-6.1-sol` and the row's `-e`:

| scores | codex (preferred) | Claude (needs live judgment, or a codex round hit a usage limit) |
|---|---|---|
| 1 2 | `-e medium` | `bee-opus-low` |
| 3 | `-e medium` | `bee-opus-medium` |
| 5 | `-e high` | `bee-opus-high` |
| 8 | `-e xhigh` | `bee-opus-high` |
| 13 | `-e xhigh` | `bee-opus-xhigh` |
| support, no points | — | `bee-haiku-runner`: named commands, raw results (baseline, suite, log evidence). `bee-sonnet-medium`: codex-diff validation, a run needing judgment, a one-area diagnosis |

Model and effort live in the agent files and wrapper flags — **never pass `model:` on the Agent
call**. **Usage limits**: no usage check runs before a round; a codex round failing on one (429)
goes to its bucket's Claude column, same score, its review to the Claude reviewer, logged (`[G1]
decision: codex 429 → bee-opus-medium`); OpenCode's `cost: 0` is not spend, its tokens serve the
budget rule only. Channels, Claude instead of codex, validation and the three test levels
(round, post-integrate, phase gate): [`reference/routing.md`](reference/routing.md).

Fold a confirmation into the next real brief, but send a ready brief now, inside the cache clock.
Stop starting units at ~80% of the known spend budget; a cut-off never finds an agent mid-editor.

## Lifecycle

```text
- [ ] 1–4. Plan the row (phase-boundaries "Planning a row"): AC draft → owner gate → expand
         one phase → plan review → `ready`. Draft the next row's AC while this one runs and expand
         the next phase while the current runs.
- [ ] 5. Run: score, bucket, mode (phase-boundaries "Size the plan first", "Routing"); a scout,
         diagnosis or path map only for a decision you must make first; roster resources →
         holders → slots → order; delegate, continue or spawn (reference/budgets.md).
- [ ] 6. Each hand-back: evaluate; review at an item or complete parent's boundary
         (reference/review.md), fix, recheck; a piece is a ☑ checkpoint, only an item or complete
         parent is accepted and landed ("Status and acceptance"); route every gap ("Intake"); one
         scheduling pass (a `ready` row or item with a free lane?); report. Only the Owner list
         waits on the owner; nothing `ready` and Owner non-empty → report starvation and stop, never
         inventing work or bypassing the owner gate.
- [ ] 7. Phase end: gate green (GATE row) → Rules current, Resume overwritten, phase-end commit →
         handoff (reference/handoff.md). The successor opens with Triage and Retro
         (reference/phase-boundaries.md) before dispatching; after the last implementation phase
         it is the closeout session.
- [ ] 8. Context hook fired at any pause, decision or acceptance? → reference/handoff.md
```

Convergence tasks: freeze metric, threshold, reference set and known floor before the loop; put
open owner questions in one decision packet with costs.

## Briefing an agent

`bees-brief` builds a Claude bee's brief from the unit's own lines (objective, decisions and
overrides since the plan, may-change, extra verification), adding units, BEES order, plan-section
pointers, slot block, standing rules and return contract. Feed a quoted heredoc (an unquoted one
runs backticks); in a lane repo `reuse` the lane first; hand over `Read <brief> and do what it says.`:

```sh
~/.claude/skills/bees/scripts/bees-brief --plan docs/plans/<plan>.md --units DR-02,DR-01 \
  --kind impl --round 1 --include .claude/skills/workspaces/templates/lane-brief.txt \
  --set lane=lane-1 --set 'task branch=task/lane-1-x' --set "full base sha=$B" \
  --set 'target branch=feat/x' <<'EOF'
Objective: <one sentence>
Decision: <each owner decision or override since the plan was written>
May change: <the item's Reach changes entries>; nothing else.
EOF
```

`--kind` is `impl`, `fix`, `review`, `recheck`, `consult`, `gate`, `plan-ac` or `plan-expand`. A
fix goes back to the implementor by SendMessage while it is under 120k and inside its cache clock.
**Read `reference/briefs.md`** for any other kind, an item without a Reach, light mode, a codex
or scout brief, a blocker or consult.

- Carry the load-bearing constants agents reported, citing the contract file, never memory; a
  count only with its command; times from `date +%H:%M`; no transcripts or source dumps.
- **Point, don't paste**: acceptance is the plan section, a fix the review file and ids; the brief
  adds only what is not written down, since a pasted line is paid again in your context.
- A brief with a live check says never to substitute an emulation without saying so in `Outcome`.

**The BEES line** (`results=` from an implementor, `reviews=` above a reviewer's verdict) is the
outcome. Missing, duplicated, wrapped or wrong-unit is malformed — you decide what is repeated, never an automatic re-run. A `replan`
goes to a `plan-expand` round before any implementor resumes, logged on the unit. A hand-back that
ignores its contract is acted on as it is; the next brief says so in one line.

## Watching rounds

Launch each codex round as its own Bash call with `run_in_background: true` (a trailing `&`'s
finish goes unnoticed), its `-o` out-file `docs/plans/<plan>.work/impl-<unit>[+<unit>…]-r<N>.txt`
or `review-…-r<N>.txt`, N counting up per unit and role. Watch with
`~/.claude/skills/bees/scripts/bees-watch <out-file>...` or `--dir docs/plans/<plan>.work`, never
the `.log`; a round quiet ~20 min gets a `bees-watch`. On a flag, a termination, a worktree or a
pause read `reference/watching.md`. A stuck round goes to the owner in one line, never left for the
next session.

## Status and acceptance

Full mode only. State is hand-written markdown committed with the plan, never only in `.work/`
(gitignored, disposable); formats are the `plan` skill's "Rules, Resume and log". Rules: this plan's
owner rules, edited in place. Resume: unfinished work, ≤ 10 lines, overwritten at a pause, a
handoff or a change of holder (with a kept codex session's id, pinned directory, last out-file and
context). The queue: what's next and what waits on the owner.

**Accepting** an unsplit item or complete parent: Status ✅ `<reviewed lane SHA> <count>`, and the
log line `- <date '+%F %H:%M'> [<unit>] accept: <suite count, review verdict, reviewed lane SHA>`;
then land it with `tools/workspace.sh land` — editors closed, claim released, plan and log folded
into the item's squash, the post-integrate check run (its flags: `workspaces` skill "Integrate a
lane"). A piece records ☑ and its checkpoint SHA instead, its parent's review still pending.

Also log each round (`[<unit>] round: impl r2 codex sol high, done, ctx 96k, impl-<unit>-r2.txt`),
review verdict, owner decision (`decision: …`; one still applying next session is a Rules line),
`gap: …`, `replan` and escape. More than one line is a checklist row or plan section instead.

**Commit cadence**: one commit per item — the plan and log, written uncommitted in `integration`,
land folded into it; lines `land` cannot fold wait for the next landing. The only docs-only commits are a plan stage, a phase end and a mid-phase handoff,
each by path (`git commit -m … -- <paths>`). A landed commit is found by its unit id
(`git log --grep '<ID>'`).

## Intake

Every agent reports a gap — source, evidence, minutes lost, workaround; **only you write**
`docs/plans/tooling-gaps.md`, `docs/backlog.md` and the queue, since two lanes appending to one
table conflict. **Only the owner adds a queue row**: you update a row's Stage and Lanes and the
Owner list, never add a row or plan. Route each gap by [`reference/intake.md`](reference/intake.md).

## What you say to the user

Never print your private "needed next" list. Say the **delta**: each fact once, ever; "after X"
for dependencies; numbers on the unit's line.

| turn | say | length |
|---|---|---|
| waiting | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause · continued or retired, why | 2–3 lines |
| quiet round | what `bees-watch` found, what you did | 1–2 lines |
| decision or blocker | question, options with cost (scope: units and phases), recommendation | ≤ 6 lines |
| pause or end | changed rows, `Next`, uncommitted state | ≤ 10 lines |
| handoff | tab name, successor's first unit, "this session stays open" | 3 lines |
| completion | changes, decisions by id, verification, review, risks, owner decisions | as needed |

> G1 (3 · codex sol medium) round 3 landed at `3b73b3a`: one projected-basis helper replaces two
> walk fallbacks, closes CX-03/04. Slot 2 (`bee-opus-high`, 110k, area loaded) continues into B4
> (8), not a fresh spawn.

## Reference

| file | read when |
|---|---|
| [`reference/phase-boundaries.md`](reference/phase-boundaries.md) | as "Setup" says |
| [`reference/budgets.md`](reference/budgets.md) | a continue-or-spawn decision or a resource handover |
| [`reference/routing.md`](reference/routing.md) | choosing a channel, a validation or a test level |
| [`reference/briefs.md`](reference/briefs.md) | a brief "Briefing an agent" does not cover, a blocker or consult |
| [`reference/review.md`](reference/review.md) | choosing or briefing a reviewer |
| [`reference/watching.md`](reference/watching.md) | a `bees-watch` flag, a termination, a worktree or a pause |
| [`reference/intake.md`](reference/intake.md) | a report lists a gap |
| [`reference/handoff.md`](reference/handoff.md) | phase end, or the context hook fires |
