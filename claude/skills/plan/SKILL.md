---
name: plan
description: >-
  Formats structured Markdown plans, audits and reviews with summary tables, stable item IDs, scoring, phases, source links and companion status/log files. Use when writing, restructuring or deleting a structured Markdown deliverable with enumerated items, or when bees runs a plan.
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
| `Size` | S · M · L, a guess at how much of one agent's session it takes (below) |
| `Route` | who implements it (a bees "Routing" bucket or a named agent/model); `-` outside bees |
| `Phase` | the session that should finish it (below) |
| `Depends` | IDs, or `-` |
| `Status` | ☐ queued · 🟡 in progress · 🔴 blocked · ✅ done |

An audit or review may use `ID | Severity | Item | Status` instead; the ID/anchor rules still hold.

## IDs and headings

- Stable, category-prefixed, sequential: `BUG-01`, `PERF-01`, `STEP-01`. Never renumber; a new
  item takes the next free number, a split takes a suffix (`STEP-03a`).
- Each item is a `### <ID> · <title>` heading. The checklist link targets GitHub's auto-slug:
  lowercase, spaces → `-`, most punctuation dropped, ` · ` and ` — ` each become `--`.
- Done: `✅` in the checklist's Status cell, nowhere else. The heading never changes, so its
  anchor link stays valid.
- A re-run of an audit adds a compact "Resolved since previous" table instead of rewriting history.

## Scoring and phases

Score the **difficulty** of the item — how much reasoning it takes to get right — not its size
(Fibonacci). Length, file count, suite runs and information gathering do not raise a score; a
long mechanical task is still a 1.

| Pts | Difficulty |
|---|---|
| 1 | mechanical: the change is fully specified; run a suite, collect output, rename, apply a given diff |
| 2 | routine: known pattern in known files, nothing to design, failure modes obvious |
| 3 | one design choice inside one area; locate the right place, implement, test |
| 5 | several interacting parts or a non-obvious invariant; a wrong choice is not caught by the suite |
| 8 | unknown cause, cross-area trade-offs, or a design with more than one defensible answer |
| 13 | new architecture or a contract change with migration, where mistakes are expensive to undo |

Above 13, split. Size is handled by splitting (below), never by the score. An
item whose score you cannot name is a read-only diagnosis item (3) that returns the split.

## Sizing and splitting

An implementor has a hard 200k context cap, and a unit that hits it pauses and its successor rebuilds
the context, so size every item by counting, not by feel. A **run** is anything that puts output
into the agent's context: a filtered suite run, an editor or browser session, a live/Play-mode
check, a golden re-capture, a rebase that may conflict, a review round.

| Size | Takes |
|---|---|
| S | one area, a few files, at most one run |
| M | one area, at most three runs |
| L | anything more: a second area, a fourth run, or a list of changes joined by "and" — split it before the run |

An area is one package or folder the agent must understand (a model and its reader, a seed, a live
runner, a game view), not one file. When unsure between two sizes, take the larger: estimates run
low, and an overrun costs a whole successor session.

Split an L into pieces that are each S or M. Every piece:

- leaves the tree building and its suites green, so it is reviewed and accepted alone;
- has its own `Done when` — a piece you cannot write one for is not a piece;
- follows a seam: contract or model first, then its callers; one screen, case or area at a time;
  a mechanical migration in batches; a read-only diagnosis before the fix it scopes; a bulk
  re-seed or golden re-capture as its own piece after the code it reflects.

Never split "code" from "its tests", or into halves that need each other's uncommitted work.

**Sub-items or new items.** Pieces that read the same files are sub-items, `STEP-07a`, `STEP-07b`:
one agent carries its warm context from one to the next. Pieces in different areas, or that can run
in parallel, are new items with the next free number. Sub-items replace the parent's checklist row,
each with its own `Pts`, `Size` and `Depends`; the parent's `### STEP-07` section keeps the shared
context, each sub-item gets its own `### STEP-07a · <title>` section.

A **phase** is what one session should finish: ≈ 5–8 items. Phases are numbered from 1 and follow
the `Depends` order.

Every item section ends with a `Done when:` line. An item's review is its own last step — one
sentence in the shared context ("each piece ends with a review; accepted only on APPROVE"), never a
`REV-nn` row per item, which doubles the checklist without adding work to track. Other work that ships
a unit — closing its editors, integrating its lane — is its own S row or the unit's last step, never
folded into a gate.

Every phase ends with a `GATE-<n>` row, `<n>` its phase number (1 pt, `Depends` listing each of the
phase's item IDs), whose section is only this checklist, so the phase cannot close on a green suite
alone:

```text
- [ ] Full suites green on the target, counts logged
- [ ] Status file written for the pause
- [ ] Handoff to a fresh session for the next phase (bees reference/handoff.md); the successor waits
      for the owner's go when the owner scoped the session to this phase
Done when: the successor's tab is named, or the final message says why no handoff ran.
```

## Sources and snippets

- Source references are clickable relative links to the exact line: `[World.cs:92](../../Game/Assets/World.cs#L92)`,
  ranges `#L84-L112`. Paths outside the repo (e.g. `~/.claude/skills/...`) stay inline code.
- Code in a plan uses a language-tagged fence (` ```csharp `, ` ```sh `), never a bare one.

## Status and log files (plans that span sessions)

Beside `<plan>.md`, committed with it:

| file | holds | written |
|---|---|---|
| `<plan>.status.md` | the handover — overwritten, **≤ 30 lines**; never repeats per-item status (that is the checklist) | at a pause, before a handoff, and when a resource changes holder — not on every acceptance, which the checklist and the log record |
| `<plan>.log.md` | one line per event, append-only | as events happen |

`<plan>.status.md` starts as a copy of [`templates/status.md`](templates/status.md)
(`cat ~/.claude/skills/plan/templates/status.md`), an example to overwrite line by line:

- **Setup** holds what a new session would otherwise ask or check again. Owner answers are valid
  anywhere. Each environment line starts with the machine (`scutil --get LocalHostName`) and date: a
  session on the same machine trusts it and skips that check; on another machine it re-runs the
  environment checks only, never the owner's questions.
- **Resources** lists each slot by name with its holder or `free` — a slot is what bees "Rules"
  (rule 3) names, and what it covers is unity-cli "One driver per project". It keeps one
  last-verification entry per slot and suite. Older runs live only in the log, so the file stays
  inside its line limit.
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

## Deleting a plan

"Delete a plan" means the plan **and every file that travels with it**: everything named
`<plan>.*` beside it — `.status.md`, `.log.md`, `.handoff.md`, `.notes.md`, the gitignored
`.work/` — without asking about each one. List what you deleted and say that `.work/` is not
recoverable, since it is gitignored.
