# Session budgets and continuation

## Contents

- Per-agent budget table
- Why the lines sit where they do
- Continue, spawn or hand over

## Per-agent budget table

One rule for both vendors (SKILL.md "Rules", the session budget), plus each vendor's cache clock:

| | `bee-opus-*`, `bee-sonnet-medium` | `bee-reviewer*`, `bee-consultant` | `bee-scout` | codex session |
|---|---|---|---|---|
| units per brief | one | one unit's diff / blocker | none (one question) | one |
| units per session | as many as fit under the context lines below | one unit + rechecks | one question, then retired | one unit + follow-up rounds |
| continue freely below | 160k | 160k | never continued | 160k (`.usage` `context_tokens`) |
| finish / one recheck below | 200k | 200k | — | 200k |
| **no new brief at or past** | **200k** | **200k** | any — spawn a new scout | **200k**, or any other directory |
| **cache warm for** | **5 min** idle | **5 min** idle | irrelevant | **30 min** idle |
| resumable after the cache | one cold turn | one cold turn | — | OpenCode: any time, same `--dir`, one cold turn · CLI: never |
| **agent self-pauses at** | **350k** | 350k | reports `Needs diagnosis` at ~120k | — |

## Why the lines sit where they do

A single complex unit may legitimately need 300–400k, so the agent itself pauses at 350k (safe
point, handover, `Outcome: Paused`); a brief sent to an agent already past 200k is a bug in the
orchestration, not a judgment call. Every turn of a 400k agent re-reads 400k of cache.

The arithmetic: a 20-step round on a 250k session reads ~5M of cache (~500k full-price-equivalent
at 0.1×); the same round in a fresh session pays ~50k of onboarding at full price and then reads a
prefix that starts small (~150–200k equivalent). Break-even sits near 120–150k for anything longer
than a recheck. A turn after the cache clock has run out re-writes the whole context at 1.25× base
price instead of reading it at 0.1×.

## Continue, spawn or hand over

- **Continue** when the agent is under the continuation line and the next queued unit routes to the
  **same agent** (a Claude bee of the same name; any codex session, since `-e` is per round) and
  touches the same area/resource — SendMessage to a Claude agent, `-s <session>` to a codex
  session. The brief is the delta only, and the unit's acceptance items.
- **Re-brief inside the clock or not at all.** A report starts the agent's cache clock: 5 minutes
  for Claude, 30 for codex. Inside it a continuation reads a warm cache; after it, the next turn
  re-writes the whole context once — on a 200k agent that costs more than a fresh spawn's
  onboarding. So when an agent reports, decide and answer in the same turn. Past the clock,
  continue only an agent under ~100k; otherwise spawn.
- **Spawn fresh** when: context at or past 200k; a different Claude agent, area, resource or repo;
  a review of that agent's own work; or the cache is cold and the context is over ~100k.
- **Read context from every report.** Codex's lands in `.usage` by itself. A Claude bee's is the
  `<subagent_tokens>` on its **final** `completed` notification — the last turn's context, not a
  cumulative total; an interim notification reads low. It goes in the unit's log line. An agent
  that reports no numbers is asked once, in the next brief.
- **Compaction (OpenCode only).** A `compacted` key in `.usage` (also in the wrapper's stderr line)
  means the server summarized the session at ~270k: record the smaller `context_tokens` as-is, but
  treat the agent as freshly spawned for recall (codex-implementor's `extract-opencode-usage`).
- **Hand over instead of continuing** when a resource holder must be retired. Its last message is
  "[bees:handover] stop at a safe point; write the state a successor needs (suite command + last
  green count, uncommitted files, what is half-done, resources/Play-mode state) in your report" —
  the prefix lets it past the 200k refusal (`bees-budget` mod, `opencode-budget`); you put its
  facts in status.md's Now/Resources. The fresh agent's brief carries that text; it does not
  re-derive the area from the transcript.
- **Scouts** are never continued and never asked a second question. ≤ 2 scouts per unit; a third
  is a diagnosis unit. Log scout tokens on the unit (`[G1] scout ×2 · 90k`); they add no points.
- **One unit per brief.** Two half-briefs to one agent beat one full brief, because each report is
  a checkpoint you can steer from. A continued agent keeps its name, so its effort is fixed: a
  1-point unit may continue on a `bee-opus-high` that already holds the area, but a 5-point unit
  never continues on a `bee-opus-low` — spawn the row the difficulty names.
- A batch step that runs past the agent's cache clock (a full Integration suite on a Claude agent)
  costs it one cold turn afterwards. Accept it; do not split suites to dodge it.
