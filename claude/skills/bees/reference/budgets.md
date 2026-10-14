# Session budgets and continuation

## Contents

- What the rules protect
- Per-agent budget table
- Why the lines sit where they do
- Continue, spawn or hand over

## What the rules protect

- **Context is the cost.** Nearly all spend is prompt-cache reads, and an agent pays its whole
  context every turn, so a unit costs *context × turns*, for Claude and codex alike.
- **The cache has three clocks**: the orchestrator 1 hour, a Claude sub-agent 5 minutes, a codex
  session 30 minutes. A turn after its clock re-writes the whole context at 1.25× instead of
  reading it at 0.1×.
- **Capability is bought per unit.** Most units are bounded and sol at medium handles them; higher
  effort only where it changes the outcome, a stronger model only as an advisor on a question for
  the owner ([`briefs.md`](briefs.md) "Blocker cap and consults").
- **Neither a spawn nor a resume is free.** A fresh agent pays ~40–60k of onboarding; a resumed
  one re-reads its session every step. Below ~100k the resume wins, past it the spawn does.
- **Rework is the second cost** (a review → fix → recheck round is 10–15M), **the orchestrator's
  own context the third** — compaction loses things nobody chose; a curated handoff does not.
- **A blocked agent costs the owner's wall-clock**, so a background task is inspected, never
  waited on.
- **Bookkeeping stays small and committed**: the queue and two files per plan, nothing derived.
- **Exclusive resources deadlock silently**, and agents die holding them.

## Per-agent budget table

One rule for both vendors (SKILL.md "Rules", the session budget), plus each vendor's cache clock:

| | `bee-opus-*` | an advisor (`bee-opus-high`) | `bee-scout` | codex session |
|---|---|---|---|---|
| units per brief | one | one unit's question | none (one question) | one |
| units per session | as many as fit under the context lines below | one unit + follow-ups | one question, then retired | one unit + follow-up rounds |
| continue freely below | 100k | 100k | never continued | 100k (`.usage` `context_tokens`); a review session 120k, 150k for a follow-up (`codex-review` "One session for the whole loop") |
| finish the current round below | 250k | 250k | — | 250k |
| **no new brief at or past** | **100k** | **100k** | any — spawn a new scout | **100k** (review: 120k / 150k), or any other directory |
| **cache warm for** | **5 min** idle | **5 min** idle | irrelevant | **30 min** idle |
| resumable after the cache | one cold turn | one cold turn | — | OpenCode: any time, same `--dir`, one cold turn · CLI: never |
| warned at | 200k (hook) | 200k (the advisor's hook) | — | — |
| **agent self-pauses at** | **250k (hook)** | **250k**, returning the unfinished round (its standing rules) | reports `Needs diagnosis` at ~100k | — |

**A smaller window or a coming compaction pauses earlier.** An agent pauses before its model window
fills and before a compaction it can see
coming. A compacted session — Claude, or OpenCode's summary at ~270k, flagged by a `compacted` key
in `.usage` and the wrapper's stderr line — counts as freshly spawned for recall whatever its new
size: record the smaller `context_tokens` as-is (codex-implementor's `extract-opencode-usage`).

## Why the lines sit where they do

A sub-agent that needs more than 250k pauses there (safe point, handover, `Outcome: Paused`), warned
at 200k by its context hook (`bee-context-nudge`), and its successor starts from the pause report. A
brief sent to an agent at or past 100k is a bug in the orchestration, not a judgment call. Every turn
of a 400k agent re-reads 400k of cache.

The arithmetic: a 20-step round on a 100k session reads ~2M of cache (~0.2M full-price-equivalent
at 0.1×); the same round in a fresh session pays ~50k of onboarding at full price and then reads a
prefix that starts small (~0.2M equivalent in all). Break-even sits near 100k for anything longer
than a recheck, and on a 250k session the resumed round costs ~0.5M equivalent, over twice the
fresh one. A turn after the cache clock has run out re-writes the whole context at 1.25× base
price instead of reading it at 0.1×.

## Continue, spawn or hand over

- **Continue** when the agent is under the continuation line and the next queued unit routes to the
  **same agent** (a Claude bee of the same name; any codex session, since `-e` is per round) and
  touches the same area/resource — SendMessage to a Claude agent, `-s <session>` to a codex
  session. The brief is the delta only, and the unit's acceptance items.
- **Re-brief inside the clock or not at all.** A report starts the agent's cache clock: 5 minutes
  for Claude, 30 for codex. Inside it a continuation reads a warm cache; after it, the next turn
  re-writes the whole context once — near the 100k line that costs more than a fresh spawn's
  onboarding. So when an agent reports, decide and answer in the same turn.
- **Spawn fresh** when: context at or past 100k; a different Claude agent, area, resource or repo;
  or a review of that agent's own work.
- **Read context from every report.** Codex's lands in `.usage` by itself. A Claude bee's is the
  `<subagent_tokens>` on its **final** `completed` notification — the last turn's context, not a
  cumulative total; an interim notification reads low. It goes in the unit's log line. An agent
  that reports no numbers is asked once, in the next brief.
- **Hand over instead of continuing** when a resource holder must be retired. Its last message is
  "[bees:handover] stop at a safe point; write the state a successor needs (suite command + last
  green count, uncommitted files, what is half-done, resources/Play-mode state) in your report" —
  the prefix lets it past the 100k refusal (`bees-budget` mod, `opencode-budget`); you put its
  facts in the plan's `## Resume` (`plan` skill "Rules, Resume and log"). The fresh agent's brief
  carries that text; it does not re-derive the area from the transcript.
- **A paused agent** is succeeded by a fresh agent on the same item, briefed from its pause report —
  never a replan or a split, since a full context is not new scope.
- **Scouts** are never continued and never asked a second question. ≤ 2 scouts per unit; a third
  is a diagnosis unit. Log scout tokens on the unit (`[G1] scout ×2 · 90k`); they add no points.
- **One unit per brief.** Two half-briefs to one agent beat one full brief, because each report is
  a checkpoint you can steer from. A continued agent keeps its name, so its effort is fixed: a
  1-point unit may continue on a `bee-opus-high` that already holds the area, but a 5-point unit
  never continues on a `bee-opus-low` — spawn the row the score names.
- A batch step that runs past the agent's cache clock costs it one cold turn afterwards, a full
  re-write of its context. Implementor verification follows `reference/routing.md` "Cost routing", so the test
  policy has one owner; a long run is accepted, never split to dodge the clock.
