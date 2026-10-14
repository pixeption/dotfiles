---
name: bees
description: >-
  Orchestrates multi-agent development: scores units, routes implementation to Claude bees by score, review and long command runs to codex, and keeps state in committed plan files. Use when the user asks to delegate or orchestrate coding work across agents, run a plan with bees, or says "bees".
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

The owner names the plan(s) to run. Read, in order, nothing else: each named plan's checklist and
its `<plan>.status.md`, each whole since both are short (`plan` skill "Tables at the top"), then
`tools/workspace.sh list` — the whole committed state, so any machine resumes from it. Schedule
from score, route, dependencies and status; open a unit's section
(`sed -En '/^### <unit> ·/,/^#{1,3} /p'`) only when a decision, blocker or finding turns on it — it
is its implementor's to read.

Nothing is asked per plan; the owner rules in its status file override the defaults (Claude
implements by score, codex reviews and runs long commands, in place in a lane when it drives an
editor; review once per item, of its landed commit) and these **standing owner rules**: a decision with a recommendation takes
it — except a change to an approved brief, which goes to a `Blocked` `owner:` line; a question for the owner during
execution goes to the advisors first ([`reference/briefs.md`](reference/briefs.md) "Blocker cap and
consults"); an expansion needs no owner approval; parallelise items eligible under the `plan`
skill's "Item fields by stage"; sharding is `reference/routing.md` "Cost routing"'s.

**Plan lifecycle** — [`reference/plan-lifecycle.md`](reference/plan-lifecycle.md): read its
planning, mode or adoption passage for those, "Preflight" before the session's first codex unit,
"Plan close" when the plan's final gate is green.

## Rules

1. **You own decisions**: goal, expansion, decomposition, scoring, routing, resources, evaluating
   results, blockers, acceptance.
2. **Six concurrent agents and four lanes, hard caps, both vendors** — every agent (Claude
   bee, codex review or run, scout, advisor) counts, being one more event stream you absorb; at most
   four hold a lane; a seventh or a fifth lane unit waits; only the user changes the caps.
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
4. **Past its context threshold a session hands off and a sub-agent is not continued; the hook or
   mod tells you when — the numbers live only in the scripts.** The count is the harness's or
   `.usage` `context_tokens`, never the agent's estimate. A refused agent gets no new brief, not
   even a fix or recheck (every resumed step re-reads the whole session): spawn fresh and hand the
   resource over; read `reference/budgets.md` before any continue-or-spawn decision. The
   orchestrator hands off at the first safe point after its hook fires (`reference/handoff.md`);
   compaction is the fallback, never the plan. **Another repo or area gets a fresh session** (a
   codex session is pinned to its directory); **the same area is the point of a split** — a
   sub-item finished while the mod still allows a continuation earns the next ready sibling.
5. **Evidence, not claims**: a suite count, a real run, a byte-identity check. A blind-worktree
   codex diff is unverified until a codex run in the resource compiles and tests it; codex in
   place with the editor card verifies itself. **No report, no commit**: a Unity test run with no
   XML this session leaves the tree dirty, `Blocked`, for you to validate; other verification records each command, exit status and result. A suite count counts only beside its
   `report: … · finished <HH:MM>` line, timed to the round — never open the XML.
6. **A background task is inspected, never waited on** ("Watching rounds").
7. **Review once per item, of its landed commit, by codex in the background**: it holds no lane
   and no editor, and its findings go to the status file's Fixes (`reference/review.md`, read when
   choosing or briefing a reviewer).
8. **State is two committed files per plan beside `<plan>.md`: `<plan>.status.md` and
   `<plan>.log.md`, nothing derived** (full mode; "Status and acceptance").
9. **Delegate execution, including reading.** Inspect directly only when cheaper than a spawn: one
   diff, a few definitions, reconciling two reports. More than two file reads or a grep fan-out is
   a **scout**, whose 1–3k of evidence lands once, while files you read stay every later turn.
   Never Read a `.log` or `cat` a report: read a report or codex out-file with
   `~/.claude/skills/bees/scripts/bees-report <file>...`, adding in the same call `--finding <IDs>`
   for whole finding blocks and `--lane <path> --since <base sha>` for the lane's commits and dirty
   files, instead of follow-up reads.
10. **Exclusive resources are released by their holder.** A command failing because another editor
    holds the project means stop and report; "check the lock and retry" is a forbidden brief, and
    so are background retry or polling loops.

## Routing

Each item carries its `plan` skill score, 1, 2, 3 or 5: an 8 or 13 was split at planning and never
reaches routing. A fix round scores the findings it closes: a reviewer's exact fixes are a 1; a
finding of unknown cause is a diagnosis first.

An item you cannot score is a **diagnosis** unit: read-only, it judges causes, usually runs
something, and returns the split and real scores. If you can write the report's headings before
spawning, it is a scout; if the answer needs *why* or *which*, a diagnosis.

A unit taking a pipeline where no committed consumer has gone gets a **path map** first
(plan-lifecycle "Path maps").

1. **Implement or fix**: a Claude bee, `bee-opus-low` for 1–2 points, `bee-opus-medium` for 3–5.
   It runs its own item filter inside its round.
2. **Review and recheck**: codex via `codex-review`, `-e medium`, `-e high` for a 5.
3. **Every run you order** — a baseline, a gate's suites, a render batch, a codex diff's
   validation — goes to a codex runner session through `codex-implementor` with the commands, and
   returns their results, because a Claude sub-agent's 5-minute cache expires while it waits.
4. **A fact** before a decision: `bee-scout`. **A cause** before a score: a diagnosis by
   `bee-opus-medium`. **A decision**: `bee-opus-high`, then codex `-e high`. Your judgment picks.
5. **Codex unavailable** (both channels down or a usage limit): the review is skipped and logged
   `review: skipped, codex unavailable`; a run goes to a `bee-opus-low`, logged `decision: codex unavailable → bee-opus-low run`. **A Claude usage limit**
   sends implementation to codex (`codex-implementor`, in place in the lane), reviewed by a
   separate codex session and logged as a same-vendor exception.

Model and effort live in the agent files and wrapper flags — **never pass `model:` on the Agent
call**. No usage check runs before a round; OpenCode's `cost: 0` is not spend, its tokens serve the
budget rule only. Channels, validation and the test levels (round, gate):
[`reference/routing.md`](reference/routing.md).

Fold a confirmation into the next real brief, but send a ready brief now, inside the cache clock.
Stop starting units at ~80% of the known spend budget; a cut-off never finds an agent mid-editor.

## Lifecycle

```text
- [ ] 1–4. Plan the row (plan-lifecycle "Planning a row"): brief draft → brief review (owner)
         → expand → plan review → `ready`. Draft the next row's brief while the current runs.
- [ ] 5. Run: score and route ("Routing"), mode (plan-lifecycle "Choose the mode"); a scout,
         diagnosis or path map only for a decision you must make first; roster resources →
         holders → slots → order; delegate, continue or spawn (reference/budgets.md).
- [ ] 6. Each hand-back: evaluate; accept and land it, reuse its lane, start its review
         ("Status and acceptance"); route every gap ("Intake"); one
         scheduling pass (a `ready` row or item with a free lane?); report. Only `owner:` lines
         in a status file wait on the owner, and during execution they gain only questions the
         advisors could not decide; nothing `ready` → report starvation and stop, never adding a
         row, drafting a plan the owner did not start or bypassing the brief review.
- [ ] 7. A GATE row whose items have landed: full suites on its target SHA. Red → yours: add a
         reviewed repair as the next item, rerun the gate on the repaired SHA. Final gate green →
         triage, pick-up, retro, final report (plan-lifecycle "Plan close") → close commit.
- [ ] 8. Context hook fired at any pause, decision or acceptance? → reference/handoff.md
```

Convergence tasks: freeze metric, threshold, reference set and known floor before the loop; put
open owner questions in one decision packet with costs.

## Briefing an agent

`bees-brief` builds a Claude bee's brief, adding units, BEES order, plan-section pointers, slot
block, standing rules and return contract. The orchestrator does not read an item's section to brief
it, only when a decision of its own turns on it: the implementor derives where to start and its
filter from the section. Stdin carries only what the plan does not: `Piece: <id> — this piece only`
when the unit is part of an item, `Decision:` lines (decisions and overrides since the plan), and
`Conflicts:` lines (files, goldens, test classes or resources another running unit owns). Feed a
quoted heredoc (an unquoted one runs backticks); in a lane repo `reuse` the lane first; hand over
`Read <brief> and do what it says.`

```sh
~/.claude/skills/bees/scripts/bees-brief --plan docs/plans/<plan>.md --units DR-02,DR-01 \
  --kind impl --round 1 --include .claude/skills/workspaces/templates/lane-brief.txt \
  --set lane=lane-1 --set 'task branch=task/lane-1-x' --set "full base sha=$B" \
  --set 'target branch=feat/x' <<'EOF'
Piece: DEL-03b — this piece only
Decision: <each owner decision or override since the plan was written>
Conflicts: RenderGoldenTests belongs to the unit re-taking render goldens: leave it out of your filter
EOF
```

`--kind` is `impl`, `fix`, `review`, `recheck`, `advise`, `gate`, `plan-brief` or `plan-expand`. A
fix goes back to the implementor by SendMessage while the `bees-budget` mod allows it and
inside its cache clock.
**Read `reference/briefs.md`** for any other kind, light mode, a codex
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
(gitignored, disposable). The **status file** `<plan>.status.md` starts as a copy of
[`templates/status.md`](templates/status.md) (`cat` it): Now, Next, Blocked and Resources are
overwritten when they change, holding `unknown` for an unknown fact; Rules, this plan's owner
rules, are edited in place. An unresolved owner question is a `Blocked` `owner:` line.

**Accepting** an item takes the hand-back's own `report: … · finished <HH:MM>` count (rule 5)
for the item's whole filter, every fail-before and its Done when — none missing, none red. Then
`tools/workspace.sh land <lane> --plan <plan> --log <log> --with <plan>.status.md --mark
'<ID>=✅ <count>'` with the log line `- <date '+%F %H:%M'> [<ID>] accept: <count> green, <filter>,
lane <lane sha>` (flags: `workspaces` skill "Integrate a lane"). From `land`'s printed
`<old>..<new>`, write `<ID> · landed <new> · review <out-file>` in the status file's Now, and
`reuse` the lane for its next unit at once.

**The review** of the landed commit needs no lane and no editor:
`git -C <repo> worktree add --detach <review dir> <new>` (nono4u `~/code/workspaces/review-<ID>`;
a skill repo, a worktree of `~/.config`), then a `codex-review` with `-C <review dir>` over
`git show <new>` minus the folded `docs/plans/<plan>.*` files, against the item's section,
out-file `review-<ID>-r1.txt`, `run_in_background`. Nobody edits that worktree; remove it after
the verdict. The verdict is the log line `[<ID>] review: <new> <clean | findings <ids> → Fixes>
(review-<ID>-r1.txt)`, and the Now line goes. Codex unavailable → `review: skipped, codex
unavailable`.

The log keeps five kinds of line, nothing else: `accept`; `review` —
`[<ID>] review: <landed sha> <verdict> (<report>)` or `[<ID>] review: skipped, codex unavailable`;
`gate` — `[GATE-<n>] gate: <target sha> <commands> <counts> <green|red>`; `decision` — a change
of plan or an owner answer (one still applying next session is also a Rules line); and `escape`.
More than one line is a checklist row or plan section instead.

**Commit cadence**: one commit per item — the plan, status file and log, written uncommitted in
`integration`, land folded into it; lines `land` cannot fold wait for the next landing. The only docs-only
commits are a plan stage, a plan close and a handoff, each by path
(`git commit -m … -- <paths>`). A landed commit is found by its unit id (`git log --grep '<ID>'`).

## Intake

Every agent reports a gap — source, evidence, minutes lost, workaround; **only you write**
`docs/plans/tooling-gaps.md`, the status files and `docs/backlog.md`, since two lanes appending to
one table conflict. **Only the owner starts a plan or adds one**: you keep each status file
current, never add a plan — except an item's replan file (`plan` skill "Replanning an item
mid-run"). Route each gap by [`reference/intake.md`](reference/intake.md).
Triage (`reference/plan-lifecycle.md` "Triage") writes findings only to `tooling-gaps.md` or
`docs/backlog.md` and stops: it drafts no plan and writes no `owner:` line, since those hold
only questions the owner must answer and brief reviews.

## What you say to the user

Never print your private "needed next" list. Say the **delta**: each fact once, ever; "after X"
for dependencies; numbers on the unit's line.

| turn | say | length |
|---|---|---|
| waiting | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| agent reported | unit (pts · route · who) · outcome · commit/suite · one clause · continued or retired, why | 2–3 lines |
| quiet round | what `bees-watch` found, what you did | 1–2 lines |
| decision or blocker | only one the advisors could not decide, now a `Blocked` `owner:` line: question, options with cost (scope: units and plans), recommendation | ≤ 6 lines |
| pause or end | changed rows, `Next`, uncommitted state | ≤ 10 lines |
| handoff | tab name, the new session's first unit, "this session stays open" | 3 lines |
| completion | changes, decisions by id, verification, review, risks, owner decisions | as needed |

## Reference

Read each when its linking passage says: [`plan-lifecycle`](reference/plan-lifecycle.md),
[`budgets`](reference/budgets.md), [`routing`](reference/routing.md),
[`briefs`](reference/briefs.md), [`review`](reference/review.md),
[`watching`](reference/watching.md), [`intake`](reference/intake.md),
[`handoff`](reference/handoff.md).
