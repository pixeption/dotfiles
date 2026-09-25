---
name: plan
description: >-
  Format rules for any structured markdown deliverable with enumerated items — implementation plans, code audits, design reviews, review reports. Covers the header block, the triage and checklist tables at the top, stable anchored IDs, the scoring scale and phases, source links, and the status/log files that travel with a plan. Load it before writing or restructuring one of those documents, and whenever the bees skill runs a plan.
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
```

`Method` only when something was actually verified.

## Tables at the top

A triage/summary table, then the checklist table, both right after the header — **never at the
end**, even if a project's own `CLAUDE.md` says to end with a checklist.

Checklist columns for a plan:

| column | holds |
|---|---|
| `ID` | anchor link to the item's heading: `[STEP-01](#step-01--title-slug)` |
| `Item` | one line |
| `Pts` | score (below) |
| `Route` | who implements it (bees §3 bucket or a named agent/model); `-` outside bees |
| `Phase` | the session that should finish it (below) |
| `Depends` | IDs, or `-` |
| `Status` | ☐ queued · 🟡 in progress · 🔴 blocked · ✅ done |

An audit or review may use `ID | Severity | Item | Status` instead; the ID/anchor rules still hold.

## IDs and headings

- Stable, category-prefixed, sequential: `BUG-01`, `PERF-01`, `STEP-01`. Never renumber; a new
  item takes the next free number, a split takes a suffix (`STEP-03a`).
- Each item is a `### <ID> · <title>` heading. The checklist link targets GitHub's auto-slug:
  lowercase, spaces → `-`, most punctuation dropped, ` · ` and ` — ` each become `--`.
- Done: `✅` in the checklist **and** `**✅ Done <date>**` (or `Fixed`) at the end of the heading —
  which changes the slug, so update the checklist link in the same edit.
- A re-run of an audit adds a compact "Resolved since previous" table instead of rewriting history.

## Scoring and phases

Score by the work implied, not the wording (Fibonacci): 1 mechanical · 2 small, known files · 3
locate + implement + test in one area · 5 several files, a fixture, or a live run · 8 cross-area
or unknown cause · 13 a new surface with migration. Above 13, split. An item whose score you
cannot name is a read-only diagnosis item (≤ 3) that returns the split.

A **phase** is what one session should finish: ≈ 5–8 items. Phases are numbered from 1 and follow
the `Depends` order.

## Sources and snippets

- Source references are clickable relative links to the exact line: `[World.cs:92](../../Game/Assets/World.cs#L92)`,
  ranges `#L84-L112`. Paths outside the repo (e.g. `~/.claude/skills/...`) stay inline code.
- Code in a plan uses a language-tagged fence (` ```csharp `, ` ```sh `), never a bare one.

## Status and log files (plans that span sessions)

Beside `<plan>.md`, committed with it:

| file | holds | written |
|---|---|---|
| `<plan>.status.md` | the handover — overwritten, **≤ 30 lines**; never repeats per-item status (that is the checklist) | on every acceptance and before a handoff |
| `<plan>.log.md` | one line per event, append-only | as events happen |

`<plan>.status.md` template:

```markdown
# <plan title> — status

## Setup
- owner: routing buckets · review cross-vendor · cadence per unit      (answers, valid on any machine)
- Locs-Mac-Studio-5, 2026-09-24: playwright-cli ok · Chrome extension ok · opencode preflight ok · codex weekly 59%

## Now
- phase 2 · STEP-06 running (codex sol, session ses_…, pinned /Users/…/repo, last out-file impl-STEP-06-r1.txt, ctx 84k)
- editor: nono4u/Game held by STEP-06, not in Play

## Next
- STEP-07 after STEP-06

## Blocked
- none

## Resources
- nono4u feat/x @ 1a2b3c4 · uncommitted: Game/Assets/X.cs (owner WIP — never touch)
- game-core main @ 5d6e7f8 · clean
- last verification: `unity test --mode EditMode Game` → 412 passed (2026-09-24 14:10)
- open review ids: STEP-05 F3

## Keep in mind
- decision 2026-09-24: STEP-04 keeps the old column order (log: "decision: …")
```

- **Setup** holds what a new session would otherwise ask or check again. Owner answers are valid
  anywhere. Each environment line starts with the machine (`scutil --get LocalHostName`) and date: a
  session on the same machine trusts it and skips that check; on another machine it re-runs the
  environment checks only, never the owner's questions.
- A codex session is resumable only on the same server; say so when the plan may move machines.
- An unknown fact is written `unknown`, never reconstructed.

`<plan>.log.md` lines — `- <YYYY-MM-DD HH:MM> [<ID>] <kind>: <text>`, kind one of `round`,
`review`, `accept`, `decision`, `gap`, `concern`, `handoff`, or none for a plain line:

```markdown
- 2026-09-24 14:12 [STEP-05] review: codex sol r3 APPROVE (review-STEP-05-r3.txt)
- 2026-09-24 14:20 [STEP-05] accept: 412 green; reviewed at 3b73b3a
- 2026-09-24 14:25 decision: D7 phase 2 runs without a reviewer for 1-pt items
```

Take times from `date '+%F %H:%M'`, never from memory. `[<ID>] accept:` is the shape `bees-watch`
greps to hide superseded rounds.
