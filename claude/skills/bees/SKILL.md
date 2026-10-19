---
name: bees
description: >-
  Orchestrates multi-agent development: scores units, routes code implementation, planning and advice to Claude bees and everything else — authoring, runs, diagnosis, review — to codex, and keeps state in committed plan files. Use when the user asks to delegate or orchestrate coding work across agents, run a plan with bees, or says "bees".
hooks:
  PostToolUse:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/context-nudge"
---

# Bees — orchestrated development

You are the **orchestrator**: you own goal, decomposition, scoring, routing, resources, blockers
and acceptance; agents execute and bring evidence. An **item** is a plan row, a **unit** one
brief's work, a **round** one wrapper call; context × turns is the cost the rules protect.

## Setup (every new bees session)

Read, in order, nothing else: each plan the owner names with its `<plan>.status.md`, whole (`plan`
skill "Checklist"), then `tools/workspace.sh list`: the whole committed state, so any
machine resumes from it. Open a unit's section (`sed -En '/^### <unit> ·/,/^#{1,3} /p'`) only when
a decision of yours turns on it. The status file's Rules override the defaults; always, a decision
with a recommendation takes it. One you cannot take, a change to a frozen artifact included, goes to
the advisors (briefs "Consults") and, if they cannot decide, is deferred as a `Blocked` `owner:`
line; the owner is never asked mid-run, since a question stalls the run on them.
Read [`reference/plan-lifecycle.md`](reference/plan-lifecycle.md) to plan, choose the mode, adopt a
plan, path-map a unit taking a pipeline no committed consumer has gone, run "Preflight" before the
session's first codex unit, or "Plan close" at the green final gate.

## Rules

1. **Ten concurrent agents and five lanes, hard caps, both vendors**, since each agent is one more
   event stream you absorb; only the user changes them. A scout runs before the units it informs.
2. **One driver per Unity resource, named in the brief by its slot** (a lane, `integration` or a
   claim the plan names), claimed and released by its holder (`workspaces` skill); others work
   elsewhere or wait. A command failing because another editor holds the project stops and
   reports; retry and polling loops are forbidden.
3. **Past its context threshold a session hands off and a sub-agent is not continued**, by the
   hook's or mod's count, never an estimate, since every resumed step re-reads the whole session.
   Another repo or area gets a fresh session.
4. **Evidence, not claims**: a suite count beside its `report: … · finished <HH:MM>` line timed to
   the round, a real run, a byte-identity check; never open the XML. A blind-worktree codex diff is
   unverified until a run in the resource compiles and tests it.
5. **Delegate execution, including reading**: more than one diff, a few definitions or two reports
   is a **scout**, whose evidence lands once while files you read stay every turn. Read a report or
   out-file only with `~/.claude/skills/bees/scripts/bees-report <file>...` (adding `--finding
   <IDs>` or `--lane <path> --since <sha>` in the same call), never Read or `cat`.

## Routing

An item carries its `plan` skill score, 1–5; one you cannot score is a read-only **diagnosis** that
returns the split and real scores, or a scout if you can write its report's headings now.

1. **Claude bees do only three things**, because Claude usage is the scarce budget: **implement or
   fix code** — production or tool logic, and repairing existing tests it breaks — `bee-opus-low` for 1–2 points
   (a reviewer's exact fixes score 1), `bee-opus-medium` for 3–5; **plan** — draft, expand and
   apply plan-review findings — so codex reviews another vendor's plan; and **advise** on a
   decision (briefs "Consults").
2. **Everything else is codex's**: **new tests** (written from the plan's acceptance and the public interface, never
   the diff, so they pin the spec rather than the implementor's reading; spec-first, red before the code, where the plan
   states a law, else after the code) and authoring at volume (corpus, fixture or catalogue cases,
   inventories, mechanical migrations, planted breaks) by `codex-implementor` in place in a lane;
   **a run you order** — a baseline, a gate's suites or a codex diff's validation, never an
   implementor's own filter — by a codex runner, also because a waiting Claude sub-agent's cache
   expires; a **cause** (a diagnosis) by `codex-round advise`, or `run` in a lane when it must run
   something; **review and recheck** by `codex-review`, `-e high` for 5 or more, else medium.
   **A fact**: `bee-scout`.
3. **Codex unavailable**: log `review: skipped, codex unavailable`; a run goes to `bee-opus-low`, a
   diagnosis to `bee-opus-medium`.
   **A Claude usage limit**: codex implements in place, a separate codex session reviews, logged as
   a same-vendor exception.

Never pass `model:` on the Agent call; the agent files and wrapper flags own it. A round runs only
its item's filter, the full suites only a GATE row; a bug caught a level later is an `escape` line.

## Lifecycle

```text
- [ ] 1–4. Plan it (plan-lifecycle "Planning a plan"): brief draft → brief review → owner
         approves → expand → plan review → `ready`.
- [ ] 5. Run: score and route ("Routing"); roster resources → slots → order; delegate, continue
         or spawn (reference/briefs.md "Continue or spawn").
- [ ] 6. Each hand-back: evaluate, land, reuse its lane, start its review ("Status and
         acceptance"); route every gap ("Intake"); schedule; report. Nothing `ready` → report
         starvation and stop.
- [ ] 7. A GATE row whose items landed: a codex run of the full suites on its target SHA, even with
         reviews out. Check it off only when green on a SHA after which no covered fix landed,
         every covered item and fix unit has a `review:` line, no open Critical or Major Fixes
         line names one, and each open Minor is a backlog row (priority `review`), its line
         deleted for a log `decision:` naming the row. Red → Fixes line `GATE-<n> · red at <sha> · <failing tests>`, fix unit
         `GATE-<n>-fix<m>`, rerun on the repaired tip. Final gate green → "Plan close".
- [ ] 8. Context hook fired → reference/handoff.md, at the first safe point.
```

## Briefing an agent

`~/.claude/skills/bees/scripts/bees-brief --plan <plan>.md --units <ids> --kind impl --round <N>`
builds a Claude bee's brief, `--include`-ing the slot block (nono4u
`.claude/skills/workspaces/templates/lane-brief.txt`) with a `--set` per placeholder; stdin, a
quoted heredoc, carries only `Piece:`, `Decision:` and `Conflicts:` lines the plan lacks. `reuse`
the lane first; hand over `Read <brief> and do what it says.` Read
[`reference/briefs.md`](reference/briefs.md) for any kind but `impl`, light mode, a scout, a blocker
or an owner question; a codex brief is `codex-implementor`'s.

**Point, don't paste** (acceptance is the plan section, a fix the review file and ids), since a
pasted line is paid again in your context. **The BEES line** is the outcome: a malformed one is
yours to judge, never an automatic re-run; `needs-decision` or `blocked` goes to briefs "Consults".

## Watching rounds

A background task is inspected, never waited on. Launch each codex round as its own Bash call with
`run_in_background: true`, out-file `docs/plans/<plan>.work/<impl|review>-<unit>-r<N>.txt`, N
counting up per unit and role; check it with `~/.claude/skills/bees/scripts/bees-watch <out-file>`
or `--dir <plan>.work`. Read [`reference/watching.md`](reference/watching.md) on a flag or a
termination; a stuck round goes to the owner in one line.

## Status and acceptance

Full mode keeps state in `<plan>.status.md`, a copy of [`templates/status.md`](templates/status.md),
and `<plan>.log.md`, committed, nothing derived. The status file holds only unfinished work: a
line whose work is done is deleted, never struck or marked ✅, because the checklist, the log and
`git log --grep` already record it and a growing file is reread every session. **Accepting** takes the hand-back's own count
("Rules", evidence) for its whole filter, every fail-before and its Done when. Then
`tools/workspace.sh land <lane> --plan <plan> --log <log> --with <plan>.status.md --mark '<ID>=✅
<count>'` (`workspaces` "Integrate a lane"), log `[<ID>] accept: <count> green, <filter>`, write
`<ID> · landed <new> · review <out-file>` in Now until its `review:` line is logged, and `reuse` the lane at once. A sub-item
(`plan` skill "Scoring") is accepted without landing: mark its row and log its `accept:` line in
integration, and brief the next sub-item into the same lane and branch; after the last, `land` the
item with `--message` naming it and its sub-items.

**The review**, once per item, by codex in the background, needs no lane: `git -C <repo> worktree
add --detach <dir> <new>` (nono4u `~/code/workspaces/review-<ID>`, a skill a `~/.config`
worktree), `codex-review -C <dir>` over `git show <new>` minus `docs/plans/<plan>.*` against the
item's section ([`reference/review.md`](reference/review.md) to choose or brief a reviewer). Remove
the worktree after; log `[<ID>] review: <new> <clean | findings <ids> → Fixes> (<file>)`.

The log has five kinds of line: `accept`, `review`, `gate` (`[GATE-<n>] gate: <sha> <commands>
<counts> <green|red>`), `decision` and `escape`. **Commit cadence**: one commit per item, plan files
folded into its landing; docs-only commits (a stage, a close, a handoff) go by path.

## Fixes

Each Critical or Major finding is one status-file line, `- [ ] <id> · <item> · <severity> ·
<reviewer's exact fix> (<review file>)`, deleted once its fix lands; never a checklist row. Critical and Major take the next free lane before any new item, and a Critical blocks every
not-started item depending on the faulty one; a Minor runs only in an idle lane, else is a backlog
row at the gate; a Nit rides with a fix unit. No exact fix: a diagnosis first.
One review's lines are one fix unit `<item>-fix<n>`: `reuse <lane> --unit <item>-fix<n> --base
<target tip> --target <target>`, `bees-brief --kind fix` (briefs "Composing a brief"); once it
hands back, codex `--kind recheck` on `git diff <base>..HEAD` until every id is Fixed; then `land
… --message 'fix(<scope>): <item> <ids> — <summary>'`, no `--mark`; a rebase conflict returns to
the implementor to resolve, rerun the item's filter and recheck the resolution diff before
retrying land; no review after landing. Log each recheck `[<item>-fix<n>] review: <sha> recheck
<APPROVE | ids open> (<file>)`.

## Intake

Agents report gaps; **only you write** `docs/plans/tooling-gaps.md`, the status files and
`docs/backlog.md`, since two lanes appending to one table conflict. Route each by
[`reference/intake.md`](reference/intake.md) and stop: no plan, no `owner:` line; only the owner
starts a plan, bar an item's replan (`plan` skill "Replanning an item mid-run").

## What you say to the user

The **delta**, each fact once: a wait in one line; a report in 2–3 (unit · pts · route · who ·
outcome · commit/suite · kept or retired); a deferred `owner:` line in ≤ 6 (options, cost, a
recommendation), only in a pause or end report; a pause or end in ≤ 10 (changed rows, `Next`, uncommitted state).
