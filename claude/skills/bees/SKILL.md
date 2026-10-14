---
name: bees
description: >-
  Orchestrates multi-agent development: scores units, routes each to a codex or Claude cost bucket, pairs it with a cross-vendor reviewer and keeps state in committed plan files. Use when the user asks to delegate or orchestrate coding work across agents, run a plan with bees, or says "bees".
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

Read, in order, nothing else: `docs/queue.md`, the plan's checklist, `## Rules` and `## Resume`,
each whole since a plan is short (`plan` skill "Tables at the top"), then `tools/workspace.sh list`
— the whole committed state, so any machine resumes from it. Schedule from score, route,
dependencies and status; open a unit's section (`sed -En '/^### <unit> ·/,/^#{1,3} /p'`) only
when a decision, blocker or finding turns on it — it is its implementor's to read. A group row
(several linked plans) has one orchestrator: read each open plan's checklist, Rules and Resume,
and schedule its plans by each plan's own stage, `Depends` and status.

Nothing is asked per plan; its `## Rules` overrides the defaults (buckets by score, codex preferred,
in place in a lane when it drives an editor; review cross-vendor, once per item before it
lands) and these **standing owner rules**: a decision with a recommendation takes it — except a
change to an approved brief, which goes to the queue's Owner list; a question for the owner during
execution goes to the advisors first ([`reference/briefs.md`](reference/briefs.md) "Blocker cap and
consults"); an expansion needs no owner approval; parallelise items eligible under the `plan`
skill's "Item fields by stage"; sharding is `reference/routing.md` "Cost routing"'s.

**Plan lifecycle** — [`reference/plan-lifecycle.md`](reference/plan-lifecycle.md): read its
planning, mode or adoption passage for those, "Preflight" before the session's first codex unit,
"Plan close" when the plan's final gate is green.

## Rules

1. **You own decisions**: goal, expansion, decomposition, scoring, routing, resources, evaluating
   results, blockers, acceptance.
2. **Six concurrent agents and four lanes, hard caps, both vendors** — every agent (codex,
   reviewer, scout, runner, advisor) counts, being one more event stream you absorb; at most
   four hold a lane; a seventh or a fifth lane unit is queued; only the user changes the caps.
   Briefs say "do not spawn sub-agents". Start with up to four lane implementors plus two review or
   scout slots (lanes share the Unity host cap, `workspaces` skill); a scout runs in a free slot
   **before** the implementors start.
3. **One driver per Unity resource, named in the brief by its slot** (unity-cli "One driver per
   project"): in nono4u a **lane** (`lane-<n>`, one worktree with its `Game/` and `GameCore/`) or
   **`integration`** (the owner's checkout, only to merge and run the final check), claimed and
   released by its holder per the `workspaces` skill (reuse a warm lane first); a shared runtime
   claim the plan names (`perf-tests-<project>`) likewise. Others work read-only, in another slot
   or a blind worktree no editor loads — or wait; disjoint files in one slot are not enough. A blind
   codex worktree is outside every slot; validating its diff in a lane is not.
4. **Session budget, both vendors: continue below 100k, finish the round below 250k** (a codex
   review session continues further: `codex-review` "One session for the whole loop") — the
   harness's count or `.usage` `context_tokens`, never the agent's estimate. At 100k no new brief,
   not even a fix or recheck (every resumed step re-reads the whole session): spawn fresh, hand the
   resource over. A bee is warned at 200k and pauses itself at 250k, or earlier
   (`reference/budgets.md` "Per-agent budget table"). **Another repo or area gets a fresh session**
   (a codex session is pinned to its directory); **the same area is the point of a split** — a
   sub-item finished below 100k earns the next ready sibling. Check before every SendMessage or
   `-s` (the `bees-budget` and `opencode-budget` mods enforce it); read `reference/budgets.md`
   before any continue-or-spawn decision.
5. **Evidence, not claims**: a suite count, a real run, a byte-identity check. A blind-worktree
   codex diff is unverified until you or a `bee-sonnet-medium` holding the resource compile and
   test it; codex in place with the editor card verifies itself. **No report, no commit**: a Unity
   test run with no XML this session leaves the tree dirty, `Blocked`, for you to validate; other
   verification records each command, exit status and result. A suite count counts only beside its
   `report: … · finished <HH:MM>` line, timed to the round — never open the XML.
6. **A background task is inspected, never waited on** ("Watching rounds").
7. **Review once per item, after its build, on the lane before it lands**, in proportion to risk,
   until the recheck is clean; the churn check, not a round count, stops a loop that is not
   converging (`reference/review.md`, read when choosing or briefing a reviewer).
8. **State is the queue and two committed files per plan** (full mode): `<plan>.md` — checklist,
   `## Rules`, `## Resume` — and `<plan>.log.md`, nothing derived ("Status and acceptance").
9. **Hand off at the first safe point past 170k, by 200k**
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

Each item carries its `plan` skill score, 1, 2, 3 or 5: an 8 or 13 was split at planning and never
reaches a bucket. A fix round scores the findings it closes: a reviewer's exact fixes are a 1; a
finding of unknown cause is a diagnosis first.

An item you cannot score is a **diagnosis** unit: read-only, it judges causes, usually runs
something, and returns the split and real scores — in one area unscored work for
`bee-sonnet-medium`, broader a scored 3. A **scout** (`bee-scout`) answers one enumerable question —
callers, writers, call path, tests, owners, evidence in a log — with no points and no judgment: if
you can write the report's headings before spawning, scout; if the answer needs *why* or *which*,
diagnosis. A question that needs a run goes to `bee-haiku-runner` when the brief can name the
commands and the answer is their raw output, else to `bee-sonnet-medium`.

A unit taking a pipeline where no committed consumer has gone gets a **path map** first
(plan-lifecycle "Path maps").

**Buckets** — codex is `codex-implementor` with `-m openai/gpt-6.1-sol-fast` and the row's `-e`:

| scores | codex (preferred) | Claude (needs live judgment, or a codex round hit a usage limit) |
|---|---|---|
| 1 2 | `-e medium` | `bee-opus-low` |
| 3 | `-e medium` | `bee-opus-medium` |
| 5 | `-e high` | `bee-opus-medium` |
| support, no points | — | `bee-haiku-runner`, `bee-sonnet-medium` (above) |

Model and effort live in the agent files and wrapper flags — **never pass `model:` on the Agent
call**. **Usage limits**: no usage check runs before a round; a codex round failing on one (429)
goes to its bucket's Claude column, same score, its review to the Claude reviewer, logged (`[G1]
decision: codex 429 → bee-opus-medium`); OpenCode's `cost: 0` is not spend, its tokens serve the
budget rule only. Channels, Claude instead of codex, validation and the three test levels
(round, post-integrate, gate): [`reference/routing.md`](reference/routing.md).

Fold a confirmation into the next real brief, but send a ready brief now, inside the cache clock.
Stop starting units at ~80% of the known spend budget; a cut-off never finds an agent mid-editor.

## Lifecycle

```text
- [ ] 1–4. Plan the row (plan-lifecycle "Planning a row"): brief draft → brief review (owner)
         → expand → plan review → `ready`. Draft the next row's brief while the current runs.
- [ ] 5. Run: score and bucket ("Routing"), mode (plan-lifecycle "Choose the mode"); a scout,
         diagnosis or path map only for a decision you must make first; roster resources →
         holders → slots → order; delegate, continue or spawn (reference/budgets.md).
- [ ] 6. Each hand-back: evaluate; review the item on its lane (reference/review.md), fix,
         recheck; accept and land it ("Status and acceptance"); route every gap ("Intake"); one
         scheduling pass (a `ready` row or item with a free lane?); report. Only the Owner list
         waits on the owner, and during execution it gains only questions the advisors could not
         decide; nothing `ready` → report starvation and stop, never adding a row, drafting
         an unqueued plan or bypassing the brief review.
- [ ] 7. A GATE row whose items have landed: full suites on its target SHA. Red → yours: add a
         reviewed repair as the next item, rerun the gate on the repaired SHA. Final gate green →
         triage, pick-up, retro, final report (plan-lifecycle "Plan close") → close commit.
- [ ] 8. Context hook fired at any pause, decision or acceptance? → reference/handoff.md
```

Convergence tasks: freeze metric, threshold, reference set and known floor before the loop; put
open owner questions in one decision packet with costs.

## Briefing an agent

`bees-brief` builds a Claude bee's brief from the unit's own lines (objective, decisions and
overrides since the plan, may-change, extra verification), adding units, BEES order, plan-section
pointers, slot block, standing rules and return contract. Feed a quoted heredoc (an unquoted one
runs backticks); in a lane repo `reuse` the lane first; hand over `Read <brief> and do what it says.`
Copy "Start at" from the files and symbols the item's Today and Approach name, and "Test filter"
from its Tests, never re-derived, keeping the planned verification boundary.

```sh
~/.claude/skills/bees/scripts/bees-brief --plan docs/plans/<plan>.md --units DR-02,DR-01 \
  --kind impl --round 1 --include .claude/skills/workspaces/templates/lane-brief.txt \
  --set lane=lane-1 --set 'task branch=task/lane-1-x' --set "full base sha=$B" \
  --set 'target branch=feat/x' <<'EOF'
Objective: <one sentence>
Decision: <each owner decision or override since the plan was written>
Start at: <the files and symbols the item's Today and Approach name> — a reference, not a limit.
Test filter: <the item's Tests filter>
EOF
```

`--kind` is `impl`, `fix`, `review`, `recheck`, `advise`, `gate`, `plan-brief` or `plan-expand`. A
fix goes back to the implementor by SendMessage while it is under 100k and inside its cache clock.
**Read `reference/briefs.md`** for any other kind, an item without Today and Approach, light mode, a codex
or scout brief, a blocker or a question for the owner.

- Carry the load-bearing constants agents reported, citing the contract file, never memory; a
  count only with its command; times from `date +%H:%M`; no transcripts or source dumps.
- **Point, don't paste**: acceptance is the plan section, a fix the review file and ids; the brief
  adds only what is not written down, since a pasted line is paid again in your context.
- A brief with a live check says never to substitute an emulation without saying so in `Outcome`.
- For batch `unity test`, the brief says: run from the project dir or pass an absolute
  `--output`, parse the XML, ignore stdout and exit code — it prints nothing and can exit 1 on
  a green run.

**The BEES line** (`results=` from an implementor, `reviews=` above a reviewer's verdict) is the
outcome. Missing, duplicated, wrapped or wrong-unit is malformed — you decide what is repeated,
never an automatic re-run. A `needs-decision` or `blocked` goes to the advisors
(`reference/briefs.md` "Blocker cap and consults"); a replan they decide is yours (`plan` skill
"Tables at the top"), logged on the unit. A hand-back that ignores its contract is acted on as
is; the next brief says so in one line.

## Watching rounds

Launch each codex round as its own Bash call with `run_in_background: true` (a trailing `&`'s
finish goes unnoticed), its `-o` out-file `docs/plans/<plan>.work/impl-<unit>[+<unit>…]-r<N>.txt`
or `review-…-r<N>.txt`, N counting up per unit and role. Watch with
`~/.claude/skills/bees/scripts/bees-watch <out-file>...` or `--dir docs/plans/<plan>.work`;
a round quiet ~20 min gets a `bees-watch`. On a flag, a termination, a worktree or a pause read
`reference/watching.md`. A stuck round goes to the owner in one line, never left for the next
session.

## Status and acceptance

Full mode only. State is hand-written markdown committed with the plan, never only in `.work/`
(gitignored, disposable); formats are the `plan` skill's "Rules, Resume and log". Rules: this plan's
owner rules, edited in place. Resume: unfinished work, ≤ 10 lines, overwritten at a pause, a
handoff or a change of holder (with a kept codex session's id, pinned directory, last out-file and
context). The queue: what's next and what waits on the owner.

**Accepting** an item: Status ✅ `<reviewed lane SHA> <count>`, and the
log line `- <date '+%F %H:%M'> [<unit>] accept: <suite count, review verdict, reviewed lane SHA>`;
then land it with `tools/workspace.sh land` — editors closed, claim released, plan and log folded
into the item's squash (flags: `workspaces` skill "Integrate a lane").
**Post-integrate**, after every landing: hold `integration` and run the landed item's filter
only, as background Bash; the full suites wait for the plan's gates. Finish before the next
landing moves the target; a red target is the next lane unit, ahead of the queue. Record tested
SHA, command, filter and count. A GameCore filter selecting more than one Integration test borrows the test shards (`workspaces`
"Borrow the test shards"); Game runs in one editor. It is target evidence, not acceptance.

Also log each round (`[<unit>] round: impl r2 codex sol high, done, ctx 96k, impl-<unit>-r2.txt`),
review verdict, owner decision (`decision: …`; one still applying next session is a Rules line),
`gap: …`, `replan` and escape. More than one line is a checklist row or plan section instead.

**Commit cadence**: one commit per item — the plan and log, written uncommitted in `integration`,
land folded into it; lines `land` cannot fold wait for the next landing. The only docs-only
commits are a plan stage, a plan close and a handoff, each by path
(`git commit -m … -- <paths>`). A landed commit is found by its unit id (`git log --grep '<ID>'`).

## Intake

Every agent reports a gap — source, evidence, minutes lost, workaround; **only you write**
`docs/plans/tooling-gaps.md`, `docs/backlog.md` and the queue, since two lanes appending to one
table conflict. **Only the owner adds a queue row**: you keep a row's Stage, Lanes and Since and
the Owner list current, never add a row or plan — except an item's replan file (`plan` skill
"Replanning an item mid-run"). Route each gap by [`reference/intake.md`](reference/intake.md).
Triage (`reference/plan-lifecycle.md` "Triage") writes findings only to `tooling-gaps.md` or
`docs/backlog.md` and stops: it drafts no plan, adds no row and proposes none in the Owner list,
which holds only questions the owner must answer and brief reviews.

## What you say to the user

Never print your private "needed next" list. Say the **delta**: each fact once, ever; "after X"
for dependencies; numbers on the unit's line.

| turn | say | length |
|---|---|---|
| waiting | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause · continued or retired, why | 2–3 lines |
| quiet round | what `bees-watch` found, what you did | 1–2 lines |
| decision or blocker | only one the advisors could not decide, now on the Owner list: question, options with cost (scope: units and plans), recommendation | ≤ 6 lines |
| pause or end | changed rows, `Next`, uncommitted state | ≤ 10 lines |
| handoff | tab name, the new session's first unit, "this session stays open" | 3 lines |
| completion | changes, decisions by id, verification, review, risks, owner decisions | as needed |

## Reference

Read each when its linking passage says: [`plan-lifecycle`](reference/plan-lifecycle.md),
[`budgets`](reference/budgets.md), [`routing`](reference/routing.md),
[`briefs`](reference/briefs.md), [`review`](reference/review.md),
[`watching`](reference/watching.md), [`intake`](reference/intake.md),
[`handoff`](reference/handoff.md).
