---
name: plan
description: >-
  Formats structured Markdown plans, audits and reviews with summary tables, stable item IDs, scoring, staged items, linked replans, source links and the companion status file and log a fresh session resumes from. Use when writing, restructuring or deleting a structured Markdown deliverable with enumerated items, or when bees runs a plan.
---

# Plan and audit format

One format for plans, audits and design reviews, so any session (or machine) can pick one up
from the committed files alone.

## Header

Right under the title:

```markdown
**Date:** 2026-09-24
**Scope:** what is covered (repos, areas)
**Focus:** why now, what the document is for
**By:** claude-opus-5-5 · reasoning: high (name any subagent used)
**Method:** real verification done — compile check, call-site tracing, a build/test run, a review loop
**Brief approved:** 2026-09-25
```

`Method` only when something was actually verified. Stage lives only in `<plan>.status.md` (bees
"Status and acceptance"). `Brief approved` appears once the owner approves the brief and never
changes after: the brief is the only owner-approved part of a plan and is frozen from then on. A
plan the owner shaped in conversation says so in its header instead of a brief review.

## Tables at the top

A summary table, then the checklist table, both right after the header — **never at the
end**, even if a project's own `CLAUDE.md` says to end with a checklist.

Checklist columns for a plan:

| column | holds |
|---|---|
| `ID` | anchor link to the item's heading: `[STEP-01](#step-01--title-slug)` |
| `Item` | one line |
| `Pts` | score (below) |
| `Route` | who implements it (a bees "Routing" bucket or a named agent/model); `-` outside bees |
| `Depends` | hard dependencies only — IDs, or `-` — so scheduling does not serialize independent work |
| `Status` | ☐ queued · 🟡 in progress · 🔴 blocked · ✅ `<count>` done — its filter's green count; the landed SHA is in the status file |

An audit or review may use `ID | Severity | Item | Status` instead; the ID/anchor rules still hold.

A plan holds at most ~20 checklist rows, so a fresh session reads its checklist and status file
whole. Larger work is several plans.

**Replanning an item mid-run** is the orchestrator's, on an advisor's decision: the new items go to
`docs/plans/<plan>.<ID>.md` in this format, linked from the item's row, and share the parent's
status file and log. The parent item is ✅ only when every row of the linked file is.

## IDs and headings

- Stable, category-prefixed, sequential: `BUG-01`, `PERF-01`, `STEP-01`. Never renumber; a new
  item takes the next free number; a split item's parts are `STEP-08.1`, `STEP-08.2` ("Scoring").
- Each item is a `### <ID> · <title>` heading. The checklist link targets GitHub's auto-slug:
  lowercase, spaces → `-`, most punctuation dropped, ` · ` and ` — ` each become `--`; the dot
  goes too, so `### STEP-08.1 · Title` is `#step-081--title`.
- Done: `✅` in the checklist's Status cell, nowhere else. The heading never changes, so its
  anchor link stays valid.
- A re-run of an audit adds a compact "Resolved since previous" table instead of rewriting history.

## Scoring

Score each item by judgment, one number for how hard and how big it is together (Fibonacci):

| Pts | Item |
|---|---|
| 1 | mechanical: a fully specified change, a suite run, a rename, a given diff |
| 2 | routine: a known pattern in known files, nothing to design |
| 3 | one design choice inside one area, or routine work across many files |
| 5 | several interacting parts or a non-obvious invariant, or a large change in one area |

An item that would score 8 or 13 — an unknown cause, cross-area trade-offs, new architecture, or
more than one agent can hold — is split at planning into items scored 5 or less, numbered after it:
`STEP-08` becomes `STEP-08.1`, `STEP-08.2` …, which replace its row. Each is a normal checklist row
with its own score, route, `Depends`, status and `### STEP-08.1 · <title>` section, built,
reviewed, accepted and landed on its own; the parent's `### STEP-08` section keeps only the shared
context. Split along a seam — contract or model first, then its callers; one screen, case or area
at a time; a read-only diagnosis before the fix it scopes — keep code and its tests in one item,
and never into items that need each other's uncommitted work. An item whose score you cannot name
is a read-only diagnosis item (3) that returns the split.

## Item fields by stage

A plan goes through `brief draft` (planner), `brief review` (codex, then the owner approves),
`expand` (planner), `plan review` (codex, skipped at three items or fewer) and `ready`; bees "Lifecycle"
holds the round caps. Each stage adds fields to its items
and none rewrites an earlier stage's. Fields are bold labels after the item's shared context, so an
implementor reads its scope and its filter from the item alone. Each stage has a template to copy:
`cat ~/.claude/skills/plan/templates/item-brief.md`,
`cat ~/.claude/skills/plan/templates/item-expand.md`, or
`cat ~/.claude/skills/plan/templates/item-review.md`.

The **brief** is one page per plan, in plain words with no code references: a `## Brief` section
after the tables holds how the result is used and an architecture note of a few lines, and each item
carries its Outcome, Right and Wrong.

| Stage | Field | Holds |
|---|---|---|
| brief draft | **Outcome** | what the result looks like and how it is used |
| | **Right** | a concrete example of the result working as meant |
| | **Wrong** | a concrete example it must not produce, and what the item deliberately doesn't do |
| brief review | — | adds no field: codex reviews the brief, then the owner approves it (bees "Planning a plan") |
| expand | **Today** | what the code does now and why it falls short, naming files and symbols (a line only where it will not move); for a bug, the symptom and its evidence |
| | **Approach** | the decided mechanism and where it goes, the invariants and traps it must not break, and the guidance sections that apply, by heading. A planner that cannot settle it from the code makes the item a diagnosis first |
| | **Tests** | one bullet per behaviour that proves the brief, edge and failure cases included, each naming its test class (new or existing) or, where no test fits, its command; then the `--filter` of those classes and their callers' (`--filter` matches classes, never a file name) |
| | **Score** | the item's points ("Scoring") |
| | **Done when** | the item's last line: its Tests pass and every named non-test acceptance check holds; an ordinary item's landed review is tracked separately in the status file and final gate, while a fix unit requires its clean recheck before landing (bees "Fixes") |
| plan review | — | adds no field: codex, skipped for three items or fewer (bees "Planning a plan"), over all its items (scores, where any 8 or 13 is a High finding, then Tests against the brief, then Today and Approach against the source) |

- **The brief is the owner's one gate per plan**, frozen once approved. Expansion never edits it: a
  finding that would change an Outcome or an exclusion (a Wrong, or what is out of scope) goes to
  the plan's status file as an `owner:` line with the reason and a proposed edit; every other question is settled by
  planner, codex and orchestrator without the owner.
- **Expansion runs once per plan**, over all its items, once the work it builds on has landed, so
  Today and Approach are read from the tree the items will actually change. An incomplete expansion
  cannot become `ready`.
- **An item holds everything its implementor needs**, never "detail in report-…", because a pointer
  makes every implementor reread what the planner already read.
- **Named files are a starting point, not a limit**: the implementor changes what the work needs and
  names any file outside Today and Approach in its report.
- For convergence tasks, freeze the metric, threshold, reference set and known floor in Tests
  before the loop, so acceptance cannot move; collect open owner questions in one decision packet
  with costs.

Two items may run in parallel when the files their Today and Approach name are disjoint and neither's
Tests read output the other changes.

## Review, landing and the gate

An item lands on green as **one commit** whose subject names its id, found with `git log --grep
'<ID>'`; its landed commit is then reviewed (bees "Status and acceptance", why in nono4u's ADR-020).
Review and landing are never their own rows. Plan, status and log edits ride in an item's landing
or a docs-only stage, close or handoff commit; log lines are never committed alone.

Every plan ends with a final `GATE-<n>` row (1 pt, `Depends` listing every item ID). In a plan of
large items the planner may place more `GATE-<n>` rows between items, each depending on the items
before it, so a break is caught while it is a few commits old. A gate's section is only a checklist;
the final gate's closes the plan, so it cannot close on a green suite alone:

```text
- [ ] Full suites green on the named target SHA, counts logged
- [ ] Every covered item's review verdict, or `review: skipped, codex unavailable`, in the log
- [ ] No open Critical or Major Fixes line; each open Minor line is a backlog row with priority `review`
- [ ] Plan close (bees "Plan close"): report sent, plan files deleted, OpenCode server stopped or the reason it remains running reported
Done when: the close report is sent.
```

A red gate becomes a Fixes line (bees "Fixes"), then a rerun on the repaired SHA. The plan closes
once, on a green final gate.

## Sources and snippets

- Source references are clickable relative links to the exact line: `[World.cs:92](../../Game/Assets/World.cs#L92)`,
  ranges `#L84-L112`. Paths outside the repo (e.g. `~/.claude/skills/...`) stay inline code.
- Code in a plan uses a language-tagged fence (` ```csharp `, ` ```sh `), never a bare one.

## Status file and log (plans that span sessions)

A fresh session resumes from the checklist, `<plan>.status.md` and `tools/workspace.sh list`, and
reads nothing else. The status file (bees "Status and acceptance") holds the stage, unfinished work
and `## Rules`; the log is `<plan>.log.md`; both sit beside the plan, committed with it.

**Rules** are owner rules for this plan only, edited in place; a new rule names the one it replaces,
so a reader never reconciles two. Never environment lines — machine checks are re-run per session
and live nowhere — and never rules that hold for every plan, which live once in the `bees` skill.

An unknown fact in the status file is written `unknown`, never reconstructed.

### Log

`<plan>.log.md`, append-only, one terse line per event — `- <YYYY-MM-DD HH:MM> [<ID>] <kind>:
<text>` — carrying ids, SHA, counts and verdict only; reasoning lives in the review or report file
the line points to. Kind one of `accept`, `review`, `gate`, `decision` or `escape` (a bug caught
one test level later than it should have been):

```markdown
- 2026-09-24 14:20 [STEP-05] accept: 412 green, UIStylePatchTests|UIApplyTests
- 2026-09-24 14:40 [STEP-05] review: 3b73b3a clean (review-STEP-05-r1.txt)
- 2026-09-24 15:02 decision: D8 STEP-07 replanned into STEP-07.1–07.3 in <plan>.STEP-07.md
- 2026-09-24 16:40 [STEP-05] escape: UIStylePatchTests caught at GATE-1, fixed 9c1e2d0
- 2026-09-24 17:10 [GATE-1] gate: 9c1e2d0 unity-suite GameCore 1204 · Game 2281 green
```

Take times from `date '+%F %H:%M'`, never from memory. `[<ID>] accept:` is the shape `bees-watch`
greps to hide superseded rounds.

## Deleting a plan

A plan is deleted at its close (bees "Plan close").
"Delete a plan" means the plan **and every file that travels with it**: `<plan>.md`,
`<plan>.log.md`, `<plan>.status.md`, any other `<plan>.*` beside it, and the gitignored `.work/` — without asking about
each one. List what you deleted and say that `.work/` is not recoverable, since it is gitignored.
