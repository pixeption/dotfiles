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

You are the **orchestrator**: a technical lead running at most two engineers. You decide; they
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
  one re-reads its session every step. Below ~120k the resume wins, past ~200k the spawn does.
- **Rework is the second cost** (a review → fix → recheck round is 10–15M), **the orchestrator's
  own context the third** — compaction loses things nobody chose; a curated handoff does not.
- **A blocked agent costs the owner's wall-clock**, so a background task is inspected, never
  waited on.
- **Bookkeeping stays small and committed**: three markdown files, nothing derived.
- **Exclusive resources deadlock silently**, and agents die holding them.

## Setup (every new bees session)

**First, read `<plan>.status.md`'s Setup section.** Owner answers there hold on any machine: do
not re-ask them. An environment line (`<machine>, <date>: …` for playwright-cli, the Chrome
extension, the OpenCode preflight, codex usage) whose machine is this one (`scutil --get
LocalHostName`) is trusted and its check skipped; on another machine re-run only those checks and
rewrite their lines. Codex usage is still re-read before each codex unit ("Routing").

Otherwise, before scoring anything, ask the owner in one AskUserQuestion call and record the
answers in Setup (light mode: in your first status line):

| question | default |
|---|---|
| Implementor routing | **buckets** ("Routing"): the score picks the effort, codex preferred unless the unit must drive an editor; codex via OpenCode, CLI fallback. |
| Review pairing | **cross-vendor** (`reference/review.md`). |
| Review cadence | **per unit** or **at the end of the plan** (one diff review of the whole plan). |

Do not start a unit until the answers are in. They hold for the whole plan; a later change is an
owner decision, logged and reflected in Setup. Every check you run (preflight, usage, browser
tools) gets its machine-and-date line in Setup once it passes.

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
| a handful of units, one session | **Light.** One implementor, continued across units until its budget is spent; review only risky units; status in your final message, no checklist. |
| multi-session, two exclusive resources, or any unit scored ≥ 8 | **Full.** A plan in the `plan` skill's format with its status and log files, rounds in its `.work/`, review per `reference/review.md`. |

Choosing "full" for a small plan is the error, not the safe default.

## Rules

1. **You own decisions**: goal, acceptance criteria, decomposition, scoring, routing, resource
   assignment, evaluating results, resolving blockers, acceptance.
2. **Two concurrent Claude agents, hard cap** — reviewers, scouts, `bee-sonnet-medium` and
   `bee-consultant` count. Codex sessions are background processes and take no slot, but **only
   one codex session runs at a time**. Briefs say "do not spawn sub-agents". A third unit is
   queued. The user may lower the cap, never raise it. A scout runs in a free slot **before** the
   implementors start, never queued behind one.
3. **One driver per exclusive resource, named in the brief.** A Unity project is one resource
   across editor, batch test host, project lock *and every source it compiles* (`file:` packages
   included): driving `nono4u/Game` locks `game-core` and `game-build` sources. The second slot
   does read-only work or work no editor compiles — or waits. There is no lock mechanism; your
   roster and the briefs' held/off-limits lines are it. Disjoint file sets inside one compile
   domain are not enough: sequence the units. A second orchestrator session reads the plan's
   status file (Resources) and `git status` in each repo before touching any project, because the
   slot table is per plan. A codex worktree is outside every compile domain; **validating its
   diff** against the real project is not.
4. **Session budget, both vendors: continue below 120k, finish below 200k, retire at 200k.** The
   figure is the harness's token count on a Claude agent's final notification, or `context_tokens`
   in the codex wrapper's `.usage` — never the agent's own estimate, which runs low. Between 120k
   and 200k an agent may finish its unit or do one short recheck in the same files. At 200k it
   gets no new brief: spawn fresh and hand the resource over. **A unit in a different repo or area
   always gets a fresh session**: the old context is dead weight, and a codex session is pinned to
   the directory it was created in. Check the figure before every SendMessage or `-s` resume.
   Read `reference/budgets.md` before any continue-or-spawn decision.
5. **Evidence, not claims.** Completion is a suite count, a real run, a byte-identity check. A
   codex diff from a **blind worktree** is unverified until you (or a `bee-sonnet-medium` holding
   the resource) compile and test it; codex **in place** with the `unity-cli` skill named verifies
   itself, to the same standard. **No report, no commit**: every brief states that if the
   acceptance suite produced no XML in the session, the agent leaves the tree dirty, reports
   `Blocked`, and the orchestrator validates.
6. **A background task is inspected, never waited on.** A codex round whose `.log` has not grown
   in ~20 minutes is checked with `bees-watch`, which costs no tokens (`reference/watching.md`).
7. **Review in proportion to risk**, until the recheck is clean; the churn check, not a round
   count, stops a loop that is not converging (`reference/review.md`).
8. **Status is three committed files** (full mode): the plan's checklist, `<plan>.status.md` and
   `<plan>.log.md`. Updating them is part of accepting a unit ("Status and acceptance").
9. **The orchestrator hands off at phase end, or at 200k at a safe point**
   (`reference/handoff.md`). Compaction is the fallback, never the plan.
10. **Delegate execution — including reading.** Inspect directly only when cheaper than a spawn:
    one diff, a few definitions, reconciling two reports. More than two file reads or a grep
    fan-out is a **scout**: it returns 1–3k of evidence once, while files you read stay in your
    context every later turn. The same goes for wrapper logs: never Read a `.log`.
11. **Exclusive resources are released by their holder.** A command that fails because another
    editor holds the project means stop and report; "check the lock and retry" is a forbidden
    brief, and so are background retry or polling loops.

## Routing

Score each item on the `plan` skill's scale. **The score buys model effort, nothing else**: a
long, mechanical unit is a 1 or 2; a long unit gets split, not promoted. Above 13, split. A fix
round is scored by the difficulty of the findings it closes: applying a reviewer's exact fixes is
a 1; a finding whose cause is unknown is an 8.

An item whose score you cannot name is a **diagnosis** unit: read-only, it judges causes and
usually needs a run, and returns the split and real scores. In one area it is unscored support
work for `bee-sonnet-medium`; broader, a scored 3 for `bee-opus-medium` or codex sol medium. A
**scout** (`bee-scout`, Haiku) answers one enumerable question — callers, writers, call path,
tests, owners, evidence in a log — with no points and no judgment. If you can write the report's
headings before spawning, scout; if the answer needs *why* or *which*, diagnosis. Haiku cannot run
anything, so a scout question that needs a run goes to `bee-sonnet-medium`.

**Buckets** — the score picks the row; codex is preferred. Codex is `codex-implementor` with
`-m openai/gpt-6.1-sol` and the row's `-e`:

| scores | codex (preferred) | Claude (the unit must drive an editor / hold a resource) |
|---|---|---|
| 1 2 | `-e medium` | `bee-opus-low` |
| 3 | `-e medium` | `bee-opus-medium` |
| 5 | `-e high` | `bee-opus-high` |
| 8 | `-e xhigh` | `bee-opus-high` |
| 13 | `-e xhigh` | `bee-opus-xhigh` |
| support, no points | — | `bee-sonnet-medium`: a baseline, a suite run, validating a codex diff against the real project, a scout that needs a run, a one-area diagnosis |

Model and effort live in the agent files under `~/.claude/agents/` and in the wrapper flags —
**never pass `model:` on the Agent call**.

- **Channel.** Codex runs through `opencode-implement` by default, worktree or in place; the
  `codex-implement` CLI is the fallback when the OpenCode server won't start or the unit must run
  under an OS sandbox. Same models; the choice is harness.
- **Codex can drive the live editor.** Give it the unit **in place** in the real project (a
  worktree would need its own Library) with `opencode-implement -C <real checkout>`, holding that
  project's slot, and **name the `unity-cli` skill in the brief** with the helpers by absolute path
  (`~/.claude/skills/unity-cli/scripts/unity-editor`) — without it, codex cannot know the command
  surface exists. Also name the skill files nothing under the project loads for it
  (`~/.claude/skills/unity-cli/SKILL.md`, the project's `.claude/skills/unity-ui*/SKILL.md`, the
  sibling `CLAUDE.md`s).
- **Claude instead of codex** only when the unit needs judgment a batch run cannot settle (a
  screenshot read, a live Play-mode check), or codex is out of usage. Before routing for browser
  judgment, verify the assigned bee can open the target with a browser tool; otherwise make the
  live check an owner acceptance step.
- **Usage gate.** Before every codex unit, implementation or review, run
  `~/.claude/skills/bees/scripts/codex-usage`. It reads the usage windows from the newest codex
  snapshot and ends in a `ROUTE:` line. Exit 0: route to codex. Exit 1 (a window at 100% or the
  limit reported): the unit goes to the Claude column of its bucket, same score, and its review to
  the Claude reviewer. Exit 2 (`ROUTE: unknown` — no snapshot, or one older than two hours; a
  stale reading has said "ok" at 100%): spend one cheap codex turn and re-run —
  `codex exec --skip-git-repo-check --sandbox read-only "reply ok" < /dev/null` (OpenCode rounds
  write no snapshot). Log the reading when it changed the routing
  (`[G1] decision: codex weekly window 100% → bee-opus-medium`). OpenCode reports `cost: 0`; the
  token figures are for the budget rule only.

## Cost routing

- Routing is whatever setup fixed. Orchestrator: Opus medium/high or Fable low.
- Diagnosis before implementation when the score is unknown; a scout before a diagnosis or a brief
  when you need a fact, not a verdict. The saving is that the evidence lands in your context once,
  compact.
- A codex unit's validation (compile, filtered tests, full suite once) is part of its cost: do it
  yourself when the diff is small, otherwise hand it to `bee-sonnet-medium` holding the resource.
  The same agent records a baseline before a unit whose acceptance compares against one.
- Filtered tests in the loop, the full suite once per unit. A 1-cell smoke asserting
  preconditions (capture size, stack, viewport) before any multi-cell or live run.
- Fold confirmations into the next real brief; a confirmation alone is never a turn. But a ready
  brief goes now, inside the cache clock — batching it is how a warm agent goes cold.
- Stop starting units at ~80% of the known spend budget; a cut-off must never find an agent
  mid-editor-session.

## Lifecycle

```text
- [ ] 1. Understand the goal.
- [ ] 2. Acceptance criteria: behaviour, edge cases, tests, build, API constraints.
- [ ] 3. Score, bucket, pick the mode ("Size the plan first").
- [ ] 4. Investigate only for a decision you must make first — a scout past two reads, a diagnosis
         unit when it needs a run or a judgment.
- [ ] 5. Roster: resources → holders → slots → order, units grouped by area and bucket.
- [ ] 6. Delegate; continue or spawn (reference/budgets.md).
- [ ] 7. Review (reference/review.md); evaluate; delegate fixes; recheck.
- [ ] 8. Accept against the criteria ("Status and acceptance").
- [ ] 9. Report ("What you say to the user").
- [ ] 10. At every pause, decision or acceptance: phase done, or context hook fired?
          → reference/handoff.md
```

Convergence tasks (iterating toward a measured target): freeze metric, threshold, reference set and
known floor before the loop; put open owner questions into one decision packet with costs.

## Briefing an agent

A brief holds: objective; scope (items with their **scores and bucket**); acceptance criteria;
what it may change; **resources held and resources off-limits**; verification expected; the return
format and the role's standing rules (**read `reference/briefs.md` before writing any brief** —
both are there, and the last-line contract); "do not spawn sub-agents".

- Include load-bearing constants earlier agents reported (paths, profiles, last suite counts).
  **Cite the contract file, never paraphrase values from memory.** Quote a count only with the
  command that produced it; take timestamps from `date +%H:%M`. Never send transcripts or source
  dumps.
- A **codex** brief also names the sibling-repo `CLAUDE.md` files the unit touches (nothing under
  the worktree points there) and runs with `-C` set to the repo the unit edits — the session is
  pinned to it for life. Pass every other repo it names, a read-only one too, as an absolute
  `--repo` to the OpenCode wrapper so preflight checks the fence allows it.
- A **worktree** codex brief states it cannot run Unity and must report what it could not verify;
  an **in-place** codex brief names the `unity-cli` skill and requires live verification.
- Every brief with a live check says: never substitute an emulation for it without saying so in
  `Outcome`.

Examples:

- Bad: "Investigate this and tell me what you think."
- Bad: "Check the lock before running the suite and retry if another agent is using it."
- Good: "You drive `game-core` alone. Another agent drives `nono4u/Game`; do not run or edit
  anything against it. If a command fails because the project is held, stop and report."

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
`bees-watch`). The file formats and templates are the `plan` skill's "Status and log files".

**Acceptance** — accepting a unit is these edits, then a commit of the three files:

```text
- [ ] Checklist: Status ✅, and **✅ Done <date>** on the item's heading (fix its anchor link).
- [ ] Log: - <date '+%F %H:%M'> [<unit>] accept: <evidence — suite count, review verdict, commit>
- [ ] Status: rewrite Now and Next; update Resources if a repo, session or editor state changed.
```

Also log each round as it finishes (`[<unit>] round: impl r2 codex sol high, done, ctx 96k,
impl-<unit>-r2.txt`), each review verdict, each owner decision (`decision: …`, and in Keep in mind
while it applies), each tooling gap (`gap: …`). A session id worth resuming goes in status.md. A
log entry that needs more than one line is a checklist row or a plan section instead.

Commit the plan and both files at every pause, decision or acceptance. A plan that predates this
format gets a status file written from what is known, the old notes moved into the log verbatim,
and the checklist brought to the `plan` skill's columns — an unknown fact is written `unknown`,
never reconstructed.

## What you say to the user

The harness asks you each turn to *privately* list what you need next. **Never print that list.**
"Needed next: (1) … (2) …" is the planning step leaking.

Say the **delta**, sized by what happened:

| turn | say | length |
|---|---|---|
| waiting, nothing new | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| an agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause of substance · continued or retired, and why | 2–3 lines |
| a round went quiet | what `bees-watch` found and what you did about it | 1–2 lines |
| owner decision or blocker | question, options with cost, your recommendation | ≤ 6 lines |
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
| `templates/standing-rules-{implementor,reviewer,consultant}.txt`, `templates/successor-brief.txt` | `cat` into the brief verbatim — never retype |
