---
name: bees
description: Multi-agent development workflow. You are the orchestrator — the thinker and controller: you frame the problem, set acceptance criteria, decompose and score work (1 2 3 5 8 13), route each unit to a cost bucket (codex luna / Sonnet for ≤ 5, Opus 5 / codex sol for 8–13), pair it with the cross-vendor reviewer, and delegate substantial repository work to a small number of budgeted sub-agents, preserving your own context for decisions. Use when the user asks to delegate/orchestrate coding work across agents, or explicitly triggers this skill.
---

# Bees — orchestrated development

You are the **orchestrator**: a technical lead running at most two engineers. You decide; they
execute and bring evidence. Measured over six rollouts (~140 agents, ~2.6G tokens, one codex
bake-off):

- **Context is the cost.** >95% of spend is prompt-cache reads; an agent pays its whole context
  every turn. The cost of a unit is *context × turns*, not item count.
- **The cache has two clocks.** The orchestrator's session is cached for **1 hour**; every
  sub-agent (`Agent` tool) is cached for **5 minutes**. A sub-agent turn that follows a gap over
  5 minutes re-writes its whole context at 1.25× base price instead of reading it at 0.1× — one
  miss on a 116k reviewer cost as much as 12 of its normal turns. Measured 2026-09-20 over 39
  agents and ~3,800 turns: 2 misses, both caused by a >5 min gap (a long batch suite, an idle
  wait), none by a prompt re-brief — because every re-brief landed inside the window.
- **Capability is bought per unit, not per plan.** On a bounded brief, codex luna-max produced the
  same correct diff as sol-low at 7× less. Most units are bounded. Pay for Opus or sol only when
  the unit is large enough that the model changes the outcome.
- **A spawn is not free.** A fresh agent re-reads the code the last one already understood. An
  agent that returned at 100k context with the area loaded is cheaper to continue than to replace
  — while its cache is warm (§3).
- **Rework is the second cost.** A review→fix→recheck round is 10–15M.
- **The orchestrator's own context is the third.** Compaction is lossy in ways nobody chose (a
  compacted session mis-recorded a decision and broke two status-doc edits on paraphrased
  anchors). A curated handoff at a unit boundary costs the same and loses nothing (§10).
- **The status document grows without bound** unless pruned: one plan's doc went 49 KB → 135 KB
  (~34k tokens) in two days, read by the orchestrator many times a session (§9).
- **Small plans paid the full machinery**: a status doc, a reviewer, a slot table and an
  orchestrator commentary loop for work one agent could finish in one sitting.
- **Exclusive resources deadlock silently**, and agents die holding them.

## 0. Setup phase (every new bees session)

Before scoring anything, ask the owner in one AskUserQuestion call and record the answers in
your first status line (and in the status doc's `Setup:` line in full mode):

| question | default |
|---|---|
| Implementor routing | **buckets** (§3): score 1–5 → low bucket, 8–13 → high bucket, codex preferred inside each bucket unless the unit must drive an editor. Codex runs **via OpenCode by default** (`opencode-implement` — attachable, no resume TTL); the `codex` CLI is the fallback (§3, `codex-implementor` skill). |
| Review pairing | **cross-vendor** (§8): a Claude implementor is reviewed by codex sol medium; a codex implementor is reviewed by `bee-reviewer` (Opus 5 medium). |
| Review cadence | **per unit** or **at the end of the plan** (one diff review of the whole plan). |

Do not start a unit until the answers are in. They hold for the whole session; a later change
is an owner decision with an id. A session started by a handoff (§10) inherits the answers from
the status doc's `Setup:` line and does not re-ask.

## 1. Size the plan first

Score every item (§3). Then:

| total score | mode |
|---|---|
| ≤ 3 | **No bees.** Do it yourself, or one agent, one brief, no status doc, no reviewer unless the change is risky. |
| 4–13 | **Light.** One implementor, continued across units until its budget is spent; review only risky units; status kept in your final message, no status doc. |
| > 13, or multi-session, or two exclusive resources | **Full.** Slot table, status doc, review per §8. |

Choosing "full" for a small plan is the error, not the safe default.

## 2. Rules

1. **You own decisions**: goal, acceptance criteria, decomposition, scoring, routing, resource
   assignment, evaluating results, resolving blockers, acceptance.
2. **Two concurrent Claude agents, hard cap.** A `bee-reviewer` counts. Codex sessions
   (implementor via OpenCode or the CLI fallback, or reviewer) are background processes and take no
   slot, but **only one codex session runs at a time**. Briefs say "do not spawn sub-agents". A
   third unit is queued. The user may lower the cap; never raise it. A `bee-scout` counts too;
   it is short, so it runs in a free slot **before** the implementors start, never queued behind one.
3. **One driver per exclusive resource, named in the brief.** A Unity project is one resource
   across editor, batch test host, project lock *and every source it compiles* (`file:` packages
   included): driving `nono4u/Game` locks `game-core` and `game-build` sources. The second slot
   does read-only work or work no editor compiles — or waits. There is no lock mechanism; your
   slot table is it. A codex worktree is outside every compile domain; **validating its diff**
   against the real project is not, and needs the resource like any other unit.
4. **Budgeted agents, continued while cheap — no new brief past 250k.** A Claude agent has a session
   budget (§3). Keep assigning it units in its loaded area until the budget is spent; retire it
   when it crosses the context ceiling or changes area. **Never `SendMessage` a Claude agent whose
   context is ≥ 250k**, whatever it holds: spawn a fresh one and hand the resource over (§3
   handover). The number that counts is the harness's token figure on the agent's last
   notification, not the agent's own estimate (agents under-report by ~2×). A sub-agent's cache
   lives **5 minutes**: re-brief within that window or accept one cold turn (§3). A codex session
   **via OpenCode (default) has no resume TTL** — its session is server-held; resume it any time.
   The `codex` CLI fallback resumes only within 30 min of its last activity (`codex-implementor`
   skill); after that it is a fresh session.
5. **Evidence, not claims.** Completion is a suite count, a real run, a byte-identity check.
   Codex **in a blind worktree** cannot run Unity or your build — that diff is unverified until you
   (or a mechanical agent holding the resource) have compiled and tested it. Codex **in place with
   the resource slot and the `unity-cli` skill named in its brief** can drive the live editor and
   verify itself (§3, editor-drive case); require the same evidence from it as from any agent.
   **No report, no commit**: every brief states that if the Acceptance suite produced no XML in
   the session the agent leaves the tree dirty, reports `Blocked`, and the orchestrator validates.
   A codex implementor committed on a licensing hang once (`0f4c12d`, 22 red tests, 2026-09-19).
6. **Review in proportion to risk.** Two rounds, then you decide.
7. **The status document is the handover** (full mode only). A new session starts from it with
   fresh agents. It has a size budget (§9); a doc over budget is a friction, not a record.
8. **The orchestrator hands off at 200k, at a safe point** (§10). Compaction is the fallback,
   never the plan.
9. **Delegate execution — including reading.** Inspect directly only when cheaper than a spawn:
   one diff, a few definitions, reconciling two contradictory reports. Anything that means more
   than two file reads or a grep fan-out is a **scout** (§3): a read-only `bee-scout` returns
   1–3k of evidence once, while files you read yourself stay in your context for every later
   turn of the session.

## 3. Scoring, buckets, budgets

Score each acceptance item on the Fibonacci scale by the work it implies, not its wording:

| pts | item looks like | typical cost |
|---|---|---|
| 1 | mechanical: rename, doc edit, re-export, table fill, one known line | 1–3M |
| 2 | small: known files, tests exist, no investigation | 3–6M |
| 3 | medium: locate cause + implement + add test in one area | 6–12M |
| 5 | large-in-area: several files, a new fixture, or an editor/live run | 12–25M |
| 8 | cross-area: unknown cause, or a change that spans packages / prefabs + code | 25–40M |
| 13 | design-shaped: a new surface (document key, command, component split) with migration | 40–60M |

Anything above 13 is split; do not brief it. An item whose score you cannot name is a
**diagnosis** unit (read-only, ≤ 3 pts, low bucket — Sonnet or codex luna, because it judges
causes and usually needs a run) that returns the split and the real scores. A **scout** is not a
diagnosis: `bee-scout` (Haiku) answers one enumerable question (callers, writers, call path,
tests, owners, sites, evidence in a log) with no points, no scores and no judgment. The test: if
you can write the report's headings before spawning, scout; if the answer needs *why* or
*which*, diagnosis — which may start with a scout to shrink its brief. Measured: diagnoses ran to
228k and 276k of context and found defects through dry-runs; Haiku's window is 200k and it
cannot run anything, so it never diagnoses. A fix round that spans more than one area goes to
the **high** bucket regardless of its points.

**Buckets** — the score picks the bucket; inside the bucket, codex is preferred:

| bucket | scores | codex (preferred) | Claude (when the unit must drive an editor / hold a resource) |
|---|---|---|---|
| low | 1 2 3 5 | `codex-implementor` (OpenCode default: `openai/gpt-5.6-luna`, max) | `bee-mechanical` (Sonnet, high) — fallback |
| high | 8 13 | `codex-implementor` (OpenCode default: `openai/gpt-5.6-sol`, medium) | `bee-implementor` (Opus 5, medium) |

Codex runs through **`opencode-implement`** by default (server-held session, `opencode attach` for
the owner to watch live, no resume TTL), for worktree and in-place units alike; the
**`codex-implement` CLI is the fallback** — use it when the OpenCode server won't start or the unit
must run under an OS sandbox (`-s workspace-write`). Same models either way; the choice is harness,
not capability. (In-place editor drive was wrongly routed to the CLI until 2026-09-20; OpenCode has
no sandbox to get in the way, which is exactly why its config carries a deny fence.)

**Codex can drive the live editor** — it is not limited to blind worktree diffs. Give it the unit
**in place** in the real project (not a worktree — a second Unity project would need its own
Library) through the **default OpenCode channel** (`opencode-implement -C <real checkout>`; the
fence is the `permission` block in `~/.config/opencode/opencode.jsonc`, and the owner can attach
to watch), holding that project's slot, and **name the `unity-cli` skill in the brief** — with
the helper scripts by absolute path (`~/.claude/skills/unity-cli/scripts/unity-editor`), since
they are not on PATH —
— that is what teaches it to drive the editor (`unity command recompile`/`run_tests`/`status`);
without it named, codex has no way to know the command surface exists. Also name the other skill
files nothing under the project loads for it (`~/.claude/skills/unity-cli/SKILL.md`, the project's
`.claude/skills/unity-ui*/SKILL.md`, the sibling `CLAUDE.md`s). Take Claude instead of codex only
when the unit needs judgment a batch run cannot settle (a screenshot read, a live Play-mode check)
— **or codex is near its usage limit**. Before every codex unit (implementation or review) run
`~/.claude/skills/bees/scripts/codex-usage`: it prints the 5-hour and weekly windows from the
newest snapshot codex wrote and exits 1 when the 5-hour window is ≥ 80% or the weekly ≥ 90%
(thresholds are flags). Exit 1 → the unit goes to the Claude column of its bucket, same score,
and its review goes to `bee-reviewer` since codex is unavailable for that too; the status doc
notes the reading. The snapshot is from the last codex turn; a 5-hour window whose reset has
passed reads as 0%. **A STALE reading is not a reading**: it said "ok" once while the real window
was at 100% and three reviews came back truncated or empty (429). When it is STALE, read
`x-codex-primary-used-percent` from the newest wrapper `.log` instead, or spend one cheap codex
turn to refresh it. Record the reading on the unit's line when it changed the routing.

Everything that can be done blind in a worktree and validated afterward goes to codex. Model and
effort live in the agent files under `~/.claude/agents/` and in the `codex-implement` flags —
**never pass `model:` on the Agent call**.

**Per-agent session budget**

| | `bee-mechanical` | `bee-implementor` | `bee-reviewer` | `bee-scout` | codex session |
|---|---|---|---|---|---|
| points per brief | ≤ 8 | ≤ 13 (one unit) | one unit's diff | none (one question) | one unit |
| points per session | ≤ 16 | ≤ 26 | one unit + rechecks | one question, then retired | one unit + follow-up rounds |
| continue while context < | 150k | 150k | 120k | never continued | OpenCode: any time · CLI: ≤ 30 min idle |
| **cache warm for** | **5 min** idle | **5 min** idle | **5 min** idle | irrelevant — one brief, one report | OpenCode: no TTL · CLI: 30 min |
| **no SendMessage at or past** | **250k** | **250k** | **200k** | any — spawn a new scout | OpenCode: no TTL · CLI: never resume after 30 min |
| **agent self-pauses at** | **350k** | **350k** | 350k | reports `Needs diagnosis` at ~120k | — |

Between 150k and 250k an agent may finish the unit it is on, nothing more. At 250k it gets no new
brief: it is retired on its next report. A single complex unit may legitimately need 300–400k, so
the agent itself pauses at 350k (safe point, handover, `Outcome: Paused`); a brief sent to an agent
already past 250k is a bug in the orchestration, not a judgment call.
Every turn of a 400k agent re-reads 400k of cache — the whole premise of this skill is that this
is the cost, and it is what an uncapped "continue while cheap" turns into.

Rules of continuation:

- After a report, if a Claude agent is under the continuation line and the next queued unit is in
  the **same bucket** and touches the same area/resource, **send it the next brief with
  SendMessage** instead of spawning. Briefs to a continued agent are shorter: the delta only, and
  the unit's acceptance items.
- **Re-brief promptly or not at all.** A report is a 5-minute clock: a SendMessage inside the
  window continues on a warm cache; after it, the next turn re-writes the whole context once
  (≈ a spawn's warm-up, so still no worse than spawning — but the saving the rule assumes is
  gone). So when an agent reports, decide and answer in the same turn; do not park a reply for
  later. A held brief that was overtaken by a second report is answered as one message.
- Spawn fresh when: context above the line, different bucket, area or resource, a review of that
  agent's own work, or the agent has been idle long enough that a fresh spawn's warm-up would
  cost less than the stale context (past ~30 min idle, or any idle at ≥ 200k).
- Read context/turns (Claude) or `.usage` tokens (codex) from every report and write them on the
  unit's line. An agent that reports no numbers is asked once, in the next brief. **Check the cap
  before every SendMessage**: the task notification's token figure ≥ 250k → spawn instead.
- **Handover instead of continuation.** When a resource holder must be retired, its last message
  is "stop at a safe point; write the state a successor needs (suite command + last green count,
  uncommitted files, what is half-done, resources/Play-mode state) into the status doc's *How to
  take over*, then report". The fresh agent's brief points at that section; it does not re-derive
  the area from the transcript. A retire-and-spawn costs one spawn's warm-up; continuing past the
  cap costs that much again on every single turn.
- A scout is never continued and never asked a second question. ≤ 2 scouts per unit; a third is
  a diagnosis unit. Log scout tokens on the unit's line (`scout ×2 · 90k`); they add no points.
- Never brief more than the per-brief points at once; two half-briefs to one agent beat one full
  brief because each report is a checkpoint you can steer from.
- A batch step that runs over 5 minutes (a full Integration suite) costs the agent one cold turn
  afterwards. Accept it; do not split suites to dodge it.

## 4. Slots, resources, termination

- The brief names the holder and the exact projects held; every other agent's brief names them as
  off-limits. A command that fails because another editor holds the project means: **stop and
  report**. "Check the lock and retry" is a forbidden brief. No background retry or polling loops;
  an agent that must wait ends its turn.
- Disjoint file sets inside one compile domain are not enough; sequence the units. A trial unit
  launched from a *second orchestrator session* into a domain the first one held hit that first
  session's uncommitted edits as a Safe-Mode compile error (2026-09-20): the slot table is per
  plan, so a second session checks the status doc's `Now` table before touching any project.
- Batch `unity test` writes its report to a cwd-relative `test-results.xml`, prints nothing and
  can exit 1 on a green run. Briefs say: run from the project dir or pass an absolute `--output`,
  parse the XML, ignore stdout and exit code (unity-cli skill).
- On any termination notice (`failed`, cut-off, no report), verify what the agent may have left —
  Play mode, data isolation (`data_restore`), stray `unity test` loops (`pkill -f 'unity test'`),
  a hung implementor (`pkill -f "codex exec"` for the CLI fallback, or `pkill -f "opencode run"`
  for the default channel — the session survives on the server either way) — before handing the
  project on, and say so in the next brief.
- Codex worktrees: `git worktree add -b codex/<unit> "$T/wt-<unit>" HEAD` under your scratchpad;
  remove the worktree after merge or discard so the next session does not find it.
- Pausing: "stop at the next safe point (tree compiling, editor not in Play, isolation restored),
  report in five lines, then wait." A paused Claude agent is warm for 5 min and usable for
  ~30 min; past that, spawn from its handover. Codex via OpenCode resumes any time; the CLI
  fallback within 30 min.
- A `bee-reviewer` waiting > ~30 min for a fix is retired; a fresh one rechecks from the findings
  list. Codex rechecks resume the same session — any time via OpenCode, or within 30 min on the CLI
  fallback (else a fresh session with the findings list in the brief).

## 5. Cost routing

- Routing is whatever the setup phase fixed. Default: bucket by score, codex preferred, Claude for
  editor-bound units, cross-vendor review. Orchestrator: Opus medium/high or Fable low.
- Diagnosis before implementation when the score is unknown: a read-only diagnosis unit (low
  bucket) sets the scope, the split and the bucket. A **scout** (`bee-scout`, Haiku) before a
  diagnosis or a brief when you need a fact — callers, path, tests, owner — not a verdict. The
  saving is not Haiku's price (2× under Sonnet on cache reads); it is that the evidence lands in
  your context once, compact, instead of the files landing forever.
- A codex unit's validation (compile, filtered tests, full suite once) is part of the unit's cost;
  do it yourself when the diff is small, otherwise hand it to `bee-mechanical` holding the
  resource.
- Filtered tests in the loop, the full suite once per unit. A 1-cell smoke asserting
  preconditions (capture size, stack, viewport) before any multi-cell or live run.
- Fold confirmations into the next real brief; a confirmation alone is never a turn. But a brief
  that is ready goes now, inside the 5-minute window (§3) — "batch it with the next thing" is how
  a warm agent goes cold.
- Stop starting units at ~80% of the known spend budget; a cut-off must never find an agent
  mid-editor-session.

## 6. Lifecycle

1. Understand. 2. Acceptance criteria (behaviour, edge cases, tests, build, API constraints).
3. Score; bucket; pick the mode (§1). 4. Investigate only for a decision you must make first — through a scout when it is more than
two reads; a diagnosis unit when it needs a run or a judgment.
5. Roster: **resources → holders → slots → order**, units grouped by area and bucket so one agent
can take several. 6. Delegate; continue or spawn per §3. 7. Review per §8; evaluate; delegate
fixes; recheck. 8. Accept against the criteria. 9. Report; update the status doc (full mode).
10. At every pause, decision or acceptance: check your own context against §10.

Convergence tasks (iterating toward a measured target): freeze metric, threshold, reference set and
known floor before the loop; put open owner questions into one decision packet with costs.

## 7. Briefing an agent

Objective, scope (items with their **scores and bucket**), acceptance criteria, what it may change,
**resources held and resources off-limits**, verification expected, return format, "do not spawn
sub-agents". Include load-bearing constants earlier agents reported (paths, profiles, last suite
counts). **Cite the contract file, never paraphrase values from memory** — two briefs stated wrong
return values and wrong slugging rules that agents had to catch. Quote a count only together with
the command that produced it; take timestamps from `date +%H:%M`, never from memory (three status
rows carried future times). Never send transcripts or source dumps. A codex brief additionally
names the sibling-repo `CLAUDE.md` files the unit touches (nothing under the worktree points
there). A **worktree** codex brief states it cannot run Unity and must report what it could not
verify; an **in-place** codex brief instead names the `unity-cli` skill (§3) and requires it to
verify in the live editor like any other agent.

- Bad: "Investigate this and tell me what you think."
- Bad: "Check the lock before running the suite and retry if another agent is using it."
- Good: "You drive `game-core` alone. Another agent drives `nono4u/Game`; do not run or edit
  anything against it. If a command fails because the project is held, stop and report."

A **scout brief** is one question, the area to look in, what "answered" looks like, and
"read-only, no editor, no sub-agents, stop when answered, `Needs diagnosis` if it needs a run or
a judgment". Its return is the scout format in `bee-scout.md`; you paste the `Answer`/`Constraints`
lines into the implementor's brief — never the scout's transcript.

- Bad: "Diagnose why selection breaks after undo." (a diagnosis unit)
- Good: "List every writer of `PuzzleProgress` and the tests that cover `UndoStack`; file:line each."

Return format (Claude agents; codex returns its final message, you fill the same fields from the
diff and `.usage`):

```
Outcome: Done | Blocked | Needs decision | Paused
Findings: only what the orchestrator needs; each claim backed by a file/symbol, command or test run.
Changes: files/symbols + short why.
Verification: builds/tests/runs + results; what was NOT verified and why.
Resources: projects driven; Play-mode state before/after; isolation restored.
Cost: context now / turns / elapsed.
Concerns: risks, assumptions, regressions.
Need from orchestrator: only if a decision is required.
```

Implementors classify every failure (introduced / pre-existing with evidence / unknown), add tests,
no opportunistic refactors. A compile break in another agent's file is reported once.

**Blocker cap — two attempts, then stop.** An agent gets **at most two materially different
attempts** at a blocker. If the second fails, it does **not** try a third: it **STOPs and reports**
with `STOP. Goal / Discovered / Blocker / Tried (both attempts) / Options (1–3) / Need from
orchestrator`. It also stops immediately — before any attempt — on a missing decision or a held
resource. A brief that says "keep trying" or "retry until it works" is forbidden; the two-attempt
cap is stated in every brief. This bounds the *context × turns* cost of an agent spinning on
something the model can't crack.

**Orchestrator escalates a capped-out blocker to a higher bucket.** When an agent returns
`Blocked` after its two attempts, that is a signal the unit was under-bucketed, not that the agent
failed. Re-route it **up one bucket / a stronger model** — codex luna → codex sol, or a low-bucket
Claude → `bee-implementor` (Opus 5) — with a fresh agent whose brief carries the blocked agent's
`Discovered` and `Tried` so the stronger model starts where the weaker one stopped, not from
scratch. If the top bucket is already blocked twice, it becomes an **owner decision** (options with
cost), never a third silent attempt.

## 8. Review

The reviewer is the **other vendor** from the implementor, so no model checks its own habits:

| implementor | reviewer | slot |
|---|---|---|
| Claude (`bee-mechanical`, `bee-implementor`) | codex gpt-5.6-sol, medium, via `codex-review` (OpenCode `opencode-review` by default, CLI fallback; `-e medium`) | none (background) |
| codex (luna or sol) | `bee-reviewer` (Opus 5, medium) | one Claude slot |

Cadence is what the owner chose in setup: per unit, or one diff review of the whole plan at the
end (then the reviewer is chosen by the vendor that implemented **most points**). A reviewer is
fresh, read-only, holds no resource, never edits, never the implementor of the unit. The review
covers a **quiescent tree** and states the commit or diff hash reviewed; never while another agent
edits the same domain. Input: changed files, surrounding code, acceptance criteria, related tests.
Findings one line each with a stable id (`MAJ-02 — sentence — file:line`), severity
**Critical / Major / Minor / Nit**; only Critical/Major block. Recheck returns three id lists:
`Fixed / Partial / Open`, scoped to the listed findings plus anything the fix introduced. A clean
review is valid. Acceptance of a new document key, command or config surface includes an
**end-to-end fixture through the real path** (apply/export/run), not only a helper's unit tests.
When codex is out (usage limit, 429), the review goes to `bee-reviewer` and the unit line says so.

## 9. The status document (full mode)

`docs/plans/<plan>-status.md`, next to the plan. A **dashboard with a log, not a diary**: each
update overwrites the current state and appends one log row. Edit once per report; commit at
pause, decision or acceptance. **Every unit carries its score, bucket and implementor wherever it
is named** — the triage table, the `Now` table, the unit heading and the log row — so a reader
never has to infer why a model was chosen.

**Size budget: 40 KB (~10k tokens).** The orchestrator reads this file many times a session and
carries it in context; every byte is paid on every turn after the read. It is kept under budget by
construction, not by occasional cleanup:

- **The header block is five lines** — Date, Scope, Focus, By, Method — plus `Setup:` and
  `Last updated:`. It never carries a decision, a rule or a friction. (One doc's header reached
  15 KB and 37 inline decisions, several lines over 1,000 characters.)
- **Decisions are table rows** in `## Decisions`: id · date · who · one-line rule · status
  (`in force` / `superseded by Dxx` / `done`). Only `in force` rows stay in the doc; the rest move
  to the archive on the next roll. A rule needs its id findable, not its prose re-read.
- **The Log is a window of the last 20 rows.** Older rows roll to `<plan>-status-log.md` (same
  columns, newest first). Git holds the rest; the doc is committed at every pause.
- **Accepted units collapse.** A 🟢 triage row keeps id · pts · bucket · implementor · final
  commit; its rounds, its `## Units` section and its commit chain go to `## Done` as one line or
  to the archive. Nothing accepted keeps a table.
- **`How to take over` holds item 0 only** — the current state. An older item is superseded by
  definition; delete it when writing the new one.
- **Frictions split**: `open` in the doc, `resolved` in the archive with the fix taken.
- **Roll at every handoff** (§10) and whenever the file passes 40 KB (`wc -c`). The outgoing
  session rolls before it writes the handover, so the incoming one starts on a small file.

```markdown
# <plan> — status and handover
**Date / Scope / Focus / By / Method**
**Setup:** routing buckets (codex luna max / Sonnet high · codex sol medium / Opus 5 medium · codex via OpenCode, CLI fallback) · review cross-vendor · per unit
**Last updated:** 2026-09-13 07:20Z · session 4 · game-core `9a8808b` · nono4u `3b73b3a`   ← one line, overwritten

## Decisions (in force)
| id | date | who | rule | status |
|---|---|---|---|---|
| D2 | 09-18 | owner | no new brief to a Claude agent at ≥ 250k; self-pause at 350k | in force |

## Triage
| unit | pts | bucket | implementor | reviewer | resource | depends on | state |
|---|---|---|---|---|---|---|---|
| G1 | 5 | low | codex luna max | bee-reviewer | — (worktree) | — | 🟠 fix round — round 3, MAJ-02 open |
| B4 | 8 | high | bee-implementor | codex sol med | nono4u/Game | G1 | ⚪ queued |

## Now
| slot | agent (model) | holds | unit (pts · bucket) | ctx / pts used | since |
|---|---|---|---|---|---|
| codex | luna max (opencode, attach :4096) | — | G1 (5 · low) round 3 | 210k tok | 07:05Z |
| 2 | bee-implementor (Opus 5 med) | nono4u/Game (+game-core sources) | B4 (8 · high) | 110k / 8 of 26 | 06:50Z |

**Next:** B4 (slot 2 continues) → G1 validate + bee-reviewer (slot 1) → owner report
**Owner decisions open:** D6 … (one line each, ids from the Decisions table)

## How to take over          (item 0 only — the current state)
Projects each agent drove; suite command + last green count; state to verify (Play mode,
data-root markers, stray `unity test` loops, codex worktrees under the scratchpad); uncommitted
trees and commit plan; owner WIP paths never to stage.

## Log (newest first; last 20 rows — older in <plan>-status-log.md)
| when | unit | pts | by | outcome | tokens / ctx / min | commits | note (≤ 1 line) |
|---|---|---|---|---|---|---|---|
| 07:20Z | G1 round 3 | 5 | codex luna | DONE, awaiting recheck | 0.4M / — / 17 | `3b73b3a` | one projected-basis helper replaces two walk fallbacks |

## Units                     (open units only)
### G1 · seed wiring gaps · 5 pts · low · codex luna max
**State:** round 3 done, awaiting recheck · **Acceptance:** …
| round | done | verdict | fixed | open |
|---|---|---|---|---|
| 1 | 06:55Z | 07:05Z | CRIT-01, MAJ-01..05 | APP-01..04 |
- [ ] APP-02 — read side still uses the old shape — [`UISeed.cs:214`](…)

## Done            (accepted units, one line each: what, pts, who, evidence, commit)
## Queue           (not started, in order, with pts, bucket and the resource each needs)
## Known noise / deferred
## Frictions (open)   (what went wrong · evidence · fix planned; resolved ones roll to the archive)
```

- **The triage `state` cell uses one fixed vocabulary, always marker + word, then ` — detail`:**
  ⚪ queued · 🟡 running · 🔵 landed (committed, review pending) · 🟠 fix round (review findings
  open) · 🔴 blocked / needs decision · 🟢 accepted (reviewed, done) · ⚫ dropped. Put the legend
  line right under `## Triage`. Never invent a state ("done", "landed, unvalidated", "ACCEPTED
  except…") — the detail after the dash carries the nuance, the marker carries the status, so the
  table scans by colour. A unit is 🟢 only when its review is closed; commits alone are 🔵.
- `Last updated` is one line. If you are about to write "Previous:", add a log row instead.
- A round is a table row, never a heading. A finding is listed once, under its unit, ticked when
  fixed. Numbers go in cells, not prose. A decision is one row with an id, never a header line.
- On acceptance, collapse the unit's section to a Done entry; the Log keeps the timeline.
- Edit the doc with anchored replacements that fail loudly (a script asserting the anchor exists
  and is unique), never a blind rewrite; a paraphrased anchor after compaction broke two edits.

## 10. The orchestrator's own context: hand off at 200k

The orchestrator is a session like any agent and pays its context every turn. Its cache is warm
for 1 hour, so idle gaps are not the risk; **size** is. The limit is **200k**, checked at every
pause, decision or acceptance (§6 step 10) from the harness's figure, not a guess.

At or past 200k, at the **next safe point**:

1. Start nothing new. Let running units reach a report; a reviewer mid-recheck finishes.
2. Bring the slot table to empty, or to a state the successor can pick up without this
   session's notifications: every running agent has reported and been retired with a handover
   (§3), or is a codex/OpenCode session the successor can resume by id.
3. Roll the status doc (§9), write `How to take over` item 0 and the `Next` line, commit.
4. Run the **`handoff` skill**: compose the message from the doc (state, next unit, routing in
   force, resource state, constraints the briefs carry, owner WIP paths, codex window reset
   time), spawn the successor with `--task "<plan> session <n+1>"`, confirm it is up, report the
   tab name to the owner. This session stays open as a fallback and starts nothing.

Why not compaction: a compaction fires whenever the window fills, usually mid-unit with agents
running, and its summary is lossy in ways nobody chose. A handoff at a safe point is written by
the session that still knows everything, and the status doc is already the handover artefact. The
cost is the same order (a fresh system prefix plus the message). Compaction stays enabled as the
fallback for a single unit that overruns the window before a safe point; when it happens, the
first action after it is to re-read the status doc and the slot table, not to trust the summary.

A handoff is never done with two agents mid-unit: the successor cannot receive their task
notifications, and the old session is then the only one that can. Retire them first.

## 11. What you say to the user

The harness asks you each turn to *privately* list what you need next. **Never print that list.**
"Needed next: (1) … (2) …" is the planning step leaking.

Say the **delta**, sized by what happened:

| turn | say | length |
|---|---|---|
| waiting, nothing new | `Waiting on codex (G1 round 3) and slot 2 (B4).` | 1 line |
| an agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause of substance · continued or retired, and why | 2–3 lines |
| owner decision or blocker | question, options with cost, your recommendation | ≤ 6 lines |
| pause or session end | the `Now` block, `Next` as one arrow line, uncommitted state | ≤ 10 lines |
| handoff | tab name, first unit the successor starts on, "this session stays open" | 3 lines |
| completion | what changed, decisions by id, verification, review status, open risks, what the user must decide | as needed |

Each fact once, ever. Dependencies as "after X". Numbers on the unit's line, not woven through
sentences.

Should read like:

> G1 (5 · low · codex luna) round 3 landed at `3b73b3a`: one projected-basis helper replaces two
> walk fallbacks, closes CX-03/04 with fail-before tests. bee-reviewer recheck running in slot 1.
> Slot 2 is at 110k with the board loaded, so it continues into B4 (8 · high) rather than a fresh
> spawn.
