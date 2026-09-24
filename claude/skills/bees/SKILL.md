---
name: bees
description: >-
  Multi-agent development workflow. You are the orchestrator — the thinker and controller: you frame the problem, set acceptance criteria, decompose and score work (1 2 3 5 8 13), route each unit to a cost bucket (codex luna / Sonnet ≤ 3, codex sol / Opus 5.5 at 5, codex sol high / Opus 5.5 for 8–13), pair it with the cross-vendor reviewer, and delegate substantial repository work to a small number of budgeted sub-agents, preserving your own context for decisions. Use when the user asks to delegate/orchestrate coding work across agents, or explicitly triggers this skill.
hooks:
  SubagentStop:
    - matcher: "bee-implementor|bee-mechanical|bee-reviewer"
      hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bees-status refresh"
  Stop:
    - hooks:
        - type: command
          command: "~/.claude/skills/bees/scripts/bees-status refresh"
---

# Bees — orchestrated development

You are the **orchestrator**: a technical lead running at most two engineers. You decide; they
execute and bring evidence. Measured over seven rollouts (~150 agents, ~2.8G tokens):

- **Context is the cost.** >95% of spend is prompt-cache reads; an agent pays its whole context
  every turn. The cost of a unit is *context × turns*, not item count. This holds for Claude and
  codex alike — both run in a 1M window and both re-read the whole session every step (a codex
  round measured 2026-09-20 read 247k of cache on its last step, on a 250k session).
- **The cache has three clocks.** The orchestrator's session is cached for **1 hour**; a Claude
  sub-agent (`Agent` tool) for **5 minutes**; a codex session (OpenCode or CLI) for **30 minutes**.
  A turn after the clock has run out re-writes the whole context at 1.25× base price instead of
  reading it at 0.1× — one miss on a 116k reviewer cost as much as 12 of its normal turns.
- **Capability is bought per unit, not per plan.** Most units are bounded and luna handles
  them. Pay for Opus or sol only when the unit is large enough that the model changes the outcome.
- **A spawn is not free, and neither is a resume.** A fresh agent re-reads the code the last one
  understood (~40–60k of onboarding). A resumed agent re-reads its whole session on every step.
  Below ~120k the resume wins; past ~200k the spawn wins on any round longer than a recheck (§3).
- **Rework is the second cost.** A review→fix→recheck round is 10–15M.
- **The orchestrator's own context is the third.** Compaction is lossy in ways nobody chose (a
  compacted session mis-recorded a decision and broke two status-doc edits on paraphrased
  anchors). A curated handoff at a unit boundary costs the same and loses nothing (§10).
- **A blocked agent costs wall-clock, not tokens — and wall-clock is the owner's.** A codex round
  waited on a permission prompt from 23:18 to the next morning (2026-09-20) because nothing
  watched it. A background task is inspected, never waited on (§4).
- **Bookkeeping is a second job unless it is derived.** A hand-kept status document went 49 KB →
  135 KB in two days; a script fed by dictated events still cost ~50 calls a session re-typing
  facts already on disk. Status is now derived from the plan, the out-files, git and one-line
  notes (§9).
- **Small plans paid the full machinery**: a status doc, a reviewer, a slot table and an
  orchestrator commentary loop for work one agent could finish in one sitting.
- **Exclusive resources deadlock silently**, and agents die holding them.

## 0. Setup phase (every new bees session)

Before scoring anything, ask the owner in one AskUserQuestion call and record the answers in
your first status line (and, in full mode, as one `decision: setup — …` note, §9):

| question | default |
|---|---|
| Implementor routing | **buckets** (§3): score 1–3 → low bucket, 5 → mid (codex sol, Opus 5.5 on the Claude side), 8–13 → high bucket, codex preferred inside each bucket unless the unit must drive an editor. Codex runs **via OpenCode by default** (`opencode-implement` — server-held session, attachable, pinned to one directory); the `codex` CLI is the fallback (§3, `codex-implementor` skill). |
| Review pairing | **cross-vendor** (§8): a Claude implementor is reviewed by codex sol medium; a codex implementor is reviewed by `bee-reviewer` (Opus 5.5 medium). |
| Review cadence | **per unit** or **at the end of the plan** (one diff review of the whole plan). |

Do not start a unit until the answers are in. They hold for the whole session; a later change
is an owner decision with an id. A session started by a handoff (§10) inherits the answers from
that note (`show --takeover` lists it) and does not re-ask.

**Before the first codex unit**, run the preflight the OpenCode wrappers run before every round.
The server reads `~/.config/opencode/opencode.jsonc` and its model catalogue **at startup only**:
a server older than the fence makes every external directory an "ask" nobody answers, one older
than an allowed directory denies it (`~/pixeption/**` was missing on 2026-09-24, so no codex unit
could reach the sibling repos), and a stale catalogue fails a round's first step on a model id
that exists.

```sh
~/.claude/skills/codex-implementor/scripts/opencode-preflight -m openai/gpt-6-sol -C <repo the unit edits> --plan <plan.md>
```

Exit 0 = the server is up, carries the fence, lists the model, and every repo in the plan's
`Repo` column outside `-C` (plus the plan's own repo) is inside the fence, as given and
symlink-resolved (the last matching fence rule wins, as in OpenCode). A failure restarts an idle
server and checks again; a server with a session busy in any directory, an unreadable session
list or an attached `opencode run`/`attach` client is never restarted. What still fails names the
path to allow in `opencode.jsonc` — an owner edit; route those units to Claude until then.

## 1. Size the plan first

Score every item (§3). Then:

| total score | mode |
|---|---|
| ≤ 3 | **No bees.** Do it yourself, or one agent, one brief, no plan checklist, no reviewer unless the change is risky. |
| 4–13 | **Light.** One implementor, continued across units until its budget is spent; review only risky units; status kept in your final message, no plan checklist. |
| > 13, or multi-session, or two exclusive resources | **Full.** A plan with the canonical checklist, rounds in its `.work/`, notes, review per §8 (§9). |

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
   does read-only work or work no editor compiles — or waits. There is no lock mechanism; your roster and the briefs' held/off-limits lines are it. A codex worktree is outside every compile domain; **validating its diff**
   against the real project is not, and needs the resource like any other unit.
4. **One session budget, both vendors: continue below 120k, finish below 200k, retire at 200k.**
   The figure is the harness's token count on a Claude agent's last notification, or
   `context_tokens` in the codex wrapper's `.usage` file — never the agent's own estimate
   (agents under-report by ~2×). Between 120k and 200k an agent may finish the unit it is on or
   do one short recheck in
   the same files, nothing new. At 200k it gets no new brief, whatever it holds: spawn fresh and
   hand the resource over (§3 handover). **A unit in a different repo or area always gets a fresh
   session**, regardless of size: the old context is dead weight, and a codex session is pinned
   to the directory it was created in — a brief for another repo trips the external-directory
   fence instead of running. Check the figure before every SendMessage or `-s` resume.
5. **Evidence, not claims.** Completion is a suite count, a real run, a byte-identity check.
   Codex **in a blind worktree** cannot run Unity or your build — that diff is unverified until you
   (or a mechanical agent holding the resource) have compiled and tested it. Codex **in place with
   the resource slot and the `unity-cli` skill named in its brief** can drive the live editor and
   verify itself (§3, editor-drive case); require the same evidence from it as from any agent.
   **No report, no commit**: every brief states that if the Acceptance suite produced no XML in
   the session the agent leaves the tree dirty, reports `Blocked`, and the orchestrator validates.
   A codex implementor committed on a licensing hang once (`0f4c12d`, 22 red tests, 2026-09-19).
6. **A background task is inspected, never waited on.** A codex round whose `.log` has not grown
   in ~20 minutes is checked, not trusted: pending permission asks on the server, the session's
   BUSY state, the editor's state. The checks are local calls and cost no tokens (§4). Sleeping
   until a notification arrives is how one round lost a night.
7. **Review in proportion to risk.** Fix rounds continue until the recheck is clean; a codex
   review then runs the final holistic pass `codex-review` requires. The churn check in §8, not a
   round count, stops a loop that is not converging.
8. **Status is derived, never dictated** (full mode only): the plan's checklist, the rounds in
   its `.work/`, `Bees-Unit:` trailers and one-line notes are the whole record; `bees-status show`
   renders it and the hooks write the plan's `Status` column (§9). You type only notes —
   decisions and acceptances. A new session starts from `show --takeover` with fresh agents.
9. **The orchestrator hands off at 200k, at a safe point** (§10). Compaction is the fallback,
   never the plan.
10. **Delegate execution — including reading.** Inspect directly only when cheaper than a spawn:
    one diff, a few definitions, reconciling two contradictory reports. Anything that means more
    than two file reads or a grep fan-out is a **scout** (§3): a read-only `bee-scout` returns
    1–3k of evidence once, while files you read yourself stay in your context for every later
    turn of the session. The same rule covers the plan's status and wrapper logs: `bees-status
    show` and `bees-watch` print a few lines; a Read of a `.log` is paid every turn after.

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
| low | 1 2 3 | `codex-implementor` (OpenCode default: `openai/gpt-6-luna`, max) | `bee-mechanical` (Sonnet, high) — fallback |
| mid | 5 | `codex-implementor` (OpenCode default: `openai/gpt-6-sol`, medium) | `bee-implementor` (Opus 5.5, medium) |
| high | 8 13 | `codex-implementor` (`openai/gpt-6-sol`, **high** — pass `-e high`) | `bee-implementor` (Opus 5.5, medium) |

Codex runs through **`opencode-implement`** by default (server-held session, `opencode attach` for
the owner to watch live), for worktree and in-place units alike; the **`codex-implement` CLI is
the fallback** — use it when the OpenCode server won't start or the unit must run under an OS
sandbox (`-s workspace-write`). Same models either way; the choice is harness, not capability.
(In-place editor drive was wrongly routed to the CLI until 2026-09-20; OpenCode has no sandbox to
get in the way, which is exactly why its config carries a deny fence.)

**Codex can drive the live editor** — it is not limited to blind worktree diffs. Give it the unit
**in place** in the real project (not a worktree — a second Unity project would need its own
Library) through the **default OpenCode channel** (`opencode-implement -C <real checkout>`; the
fence is the `permission` block in `~/.config/opencode/opencode.jsonc`, and the owner can attach
to watch), holding that project's slot, and **name the `unity-cli` skill in the brief** — with
the helper scripts by absolute path (`~/.claude/skills/unity-cli/scripts/unity-editor`), since
they are not on PATH — that is what teaches it to drive the editor (`unity command
recompile`/`run_tests`/`status`); without it named, codex has no way to know the command surface
exists. Also name the other skill files nothing under the project loads for it
(`~/.claude/skills/unity-cli/SKILL.md`, the project's `.claude/skills/unity-ui*/SKILL.md`, the
sibling `CLAUDE.md`s). Take Claude instead of codex only when the unit needs judgment a batch run
cannot settle (a screenshot read, a live Play-mode check) — **or codex is near its usage limit**.
Before every codex unit (implementation or review) run `~/.claude/skills/bees/scripts/codex-usage`:
it reads the usage windows from the newest snapshot codex wrote, names each by its length, and
ends in a `ROUTE:` line. The plan has only a **weekly** window (no 5-hour limit since 2026-09-24);
a 5-hour window is still read if a plan reports one. Exit 1 when the weekly window is ≥ 90% (a
5-hour one ≥ 80%; thresholds are flags) → the unit goes to the Claude column of its bucket, same
score, and its review goes to `bee-reviewer` since codex is unavailable for that too; a note
records the reading. The snapshot is from the last codex turn; a window whose reset has passed
reads as 0%. **A STALE reading is not a reading**: it said "ok" once while the real window was at
100% and three reviews came back truncated or empty (429). So a snapshot older than two hours
prints `ROUTE: unknown` and exits 2, as does no snapshot: spend one cheap codex turn
(`codex exec --skip-git-repo-check --sandbox read-only "reply ok" < /dev/null` — OpenCode rounds
write no snapshot) and re-run. Note the reading on the unit
(`note <unit> "decision: codex weekly window 92% → bee-mechanical"`) when it changed the routing. OpenCode reports `cost: 0` for every round — the plan is metered by the
usage windows, and the token figures are for the budget rule only.

Everything that can be done blind in a worktree and validated afterward goes to codex. Model and
effort live in the agent files under `~/.claude/agents/` and in the `codex-implement` flags —
**never pass `model:` on the Agent call**.

**Per-agent session budget** — one rule for both vendors (rule 4), plus each vendor's clock:

| | `bee-mechanical` | `bee-implementor` | `bee-reviewer` | `bee-scout` | codex session |
|---|---|---|---|---|---|
| points per brief | ≤ 8 | ≤ 13 (one unit) | one unit's diff | none (one question) | one unit |
| points per session | ≤ 16 | ≤ 26 | one unit + rechecks | one question, then retired | one unit + follow-up rounds |
| continue freely below | 120k | 120k | 120k | never continued | 120k (`.usage` `context_tokens`) |
| finish / one recheck below | 200k | 200k | 200k | — | 200k |
| **no new brief at or past** | **200k** | **200k** | **200k** | any — spawn a new scout | **200k**, or any other directory |
| **cache warm for** | **5 min** idle | **5 min** idle | **5 min** idle | irrelevant | **30 min** idle |
| resumable after the cache | one cold turn | one cold turn | one cold turn | — | OpenCode: any time, same `--dir`, one cold turn · CLI: never |
| **agent self-pauses at** | **350k** | **350k** | 350k | reports `Needs diagnosis` at ~120k | — |

A single complex unit may legitimately need 300–400k, so the agent itself pauses at 350k (safe
point, handover, `Outcome: Paused`); a brief sent to an agent already past 200k is a bug in the
orchestration, not a judgment call. Every turn of a 400k agent re-reads 400k of cache — the whole
premise of this skill is that this is the cost, and it is what an uncapped "continue while cheap"
turns into. The arithmetic behind the lines: a 20-step round on a 250k session reads ~5M of
cache (~500k full-price-equivalent at 0.1×); the same round in a fresh session pays ~50k of
onboarding at full price and then reads a prefix that starts small (~150–200k equivalent).
Break-even sits near 120–150k for anything longer than a recheck.

Rules of continuation:

- After a report, if an agent is under the continuation line and the next queued unit is in the
  **same bucket** and touches the same area/resource, **continue it** — SendMessage to a Claude
  agent, `-s <session>` to a codex session — instead of spawning. Briefs to a continued agent are
  shorter: the delta only, and the unit's acceptance items.
- **Re-brief inside the clock or not at all.** A report starts the agent's cache clock: 5 minutes
  for Claude, 30 for codex. Inside it a continuation reads a warm cache; after it, the next turn
  re-writes the whole context once — on a 200k agent that one cold turn costs more than a fresh
  spawn's onboarding. So when an agent reports, decide and answer in the same turn; do not park
  a reply. Past the clock, continue only an agent under ~100k; otherwise spawn.
- Spawn fresh when: context at or past 200k, different bucket, area, resource or repo, a review
  of that agent's own work, or the cache is cold and the context is over ~100k.
- Read context from every report: codex's lands in `.usage` by itself; a Claude bee's is the
  harness notification's figure, saved with its report by `capture-bee --ctx` (§9). An agent that
  reports no numbers is asked once, in the next brief. For an OpenCode-channel unit, a `compacted` key in `.usage`
  (surfaced in the wrapper's own stderr line) means the server auto-summarized the session at
  ~270k: `context_tokens` afterward is the real, smaller size — record it as-is — but treat the
  agent as if freshly spawned re: recall, since everything before the compaction is now a summary,
  not the original detail (codex-implementor's `extract-opencode-usage`).
- **Handover instead of continuation.** When a resource holder must be retired, its last message
  is "stop at a safe point; write the state a successor needs (suite command + last green count,
  uncommitted files, what is half-done, resources/Play-mode state) in your report"; you turn its facts
  into `handoff:` notes (§9). The fresh agent's brief carries that text; it does not re-derive
  the area from the transcript. A retire-and-spawn costs one spawn's warm-up; continuing past the
  cap costs that much again on every single turn.
- A scout is never continued and never asked a second question. ≤ 2 scouts per unit; a third is
  a diagnosis unit. Note scout tokens on the unit (`note <unit> "scout ×2 · 90k"`); they add no points.
- Never brief more than the per-brief points at once; two half-briefs to one agent beat one full
  brief because each report is a checkpoint you can steer from.
- A batch step that runs over the agent's cache clock (a full Integration suite on a Claude agent)
  costs it one cold turn afterwards. Accept it; do not split suites to dodge it.

## 4. Slots, resources, termination, watching

- The brief names the holder and the exact projects held; every other agent's brief names them as
  off-limits. A command that fails because another editor holds the project means: **stop and
  report**. "Check the lock and retry" is a forbidden brief. No background retry or polling loops;
  an agent that must wait ends its turn.
- Disjoint file sets inside one compile domain are not enough; sequence the units. A trial unit
  launched from a *second orchestrator session* into a domain the first one held hit that first
  session's uncommitted edits as a Safe-Mode compile error (2026-09-20): the slot table is per
  plan, so a second session runs `bees-status --plan <plan.md> show --takeover` (repo HEADs,
  uncommitted paths, live sessions) before touching any project.
- Batch `unity test` writes its report to a cwd-relative `test-results.xml`, prints nothing and
  can exit 1 on a green run. Briefs say: run from the project dir or pass an absolute `--output`,
  parse the XML, ignore stdout and exit code (unity-cli skill).
- **Watching a codex round.** Never tail or Read the wrapper's `.log`. Run
  `~/.claude/skills/bees/scripts/bees-watch <out-file>...` (or `--dir docs/plans/<plan>.work`): one line
  per round — running/finished, minutes since the log last grew, BUSY/idle, context tokens,
  session id — and a flag, exit 1, when something needs you. BUSY is the server's status for the
  round's directory (`/session/status` is scoped per directory) or a live wrapper mid-step:
  - `ASK WAITING` — a permission ask nobody headless can answer. Answer it through the attach TUI
    if the pattern is inside the fence's allowlist; otherwise kill the run and re-brief. Then fix
    the cause: the server predates the fence (§0), or the session was resumed for a directory it
    is not pinned to (rule 4).
  - `STALE` — no log growth in 20 minutes and not BUSY: the run died. `quiet but BUSY` is a long
    tool call (a Unity suite can legitimately be silent for 20 minutes) and is left alone.
  - `failed (…)` — the wrapper finished but the out-file is empty or carries its `Blocked:` line
    (an `error` event, a rejected permission ask, a non-zero `opencode run` exit, no final message,
    a final step that did not stop, a review without a verdict; the wrapper also exited 1).
    `DEAD` — the wrapper's PID (`.pid`) is gone and it never wrote `.usage`.
  Then check the editor's state, if the unit held a project. A stuck round is reported to the
  owner in one line with what `bees-watch` printed; it is never left for the next session.
- On any termination notice (`failed`, cut-off, no report), verify what the agent may have left —
  Play mode, data isolation (`data_restore`), stray `unity test` loops (`pkill -f 'unity test'`),
  a hung implementor (`pkill -f "codex exec"` for the CLI fallback, or `pkill -f "opencode run"`
  for the default channel — the session survives on the server either way) — before handing the
  project on, and say so in the next brief.
- Codex worktrees: `git worktree add -b codex/<unit> "$T/wt-<unit>" HEAD` under your scratchpad;
  remove the worktree after merge or discard so the next session does not find it.
- Pausing: "stop at the next safe point (tree compiling, editor not in Play, isolation restored),
  report in five lines, then wait." A paused agent is warm for its cache clock (5 min Claude,
  30 min codex) and worth continuing under ~100k after it; past that, spawn from its handover.
- A `bee-reviewer` waiting > ~30 min for a fix is retired; a fresh one rechecks from the findings
  list and the fix diff. A codex reviewer's recheck resumes the same OpenCode session at any time
  (no TTL); only the CLI fallback has the 30-minute cliff, after which a fresh session with the
  findings list and the fix diff in the brief is cheaper than the cold re-read.

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
  that is ready goes now, inside the cache clock (§3) — "batch it with the next thing" is how a
  warm agent goes cold.
- Stop starting units at ~80% of the known spend budget; a cut-off must never find an agent
  mid-editor-session.

## 6. Lifecycle

1. Understand. 2. Acceptance criteria (behaviour, edge cases, tests, build, API constraints).
3. Score; bucket; pick the mode (§1). 4. Investigate only for a decision you must make first —
through a scout when it is more than two reads; a diagnosis unit when it needs a run or a
judgment. 5. Roster: **resources → holders → slots → order**, units grouped by area and bucket so
one agent can take several. 6. Delegate; continue or spawn per §3. 7. Review per §8; evaluate;
delegate fixes; recheck. 8. Accept against the criteria. 9. Report; note decisions and acceptances
(full mode) — everything else is derived. 10. At every pause, decision or acceptance: check your own context against §10.

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
there) and is run with `-C` set to the repo the unit edits — a session is pinned to that
directory for its whole life. Every repo it names must be inside the OpenCode fence; the wrapper's
preflight checks the plan's `Repo` column (§0), so list a sibling the unit only reads there too or
run the preflight by hand. A **worktree** codex brief states it cannot run Unity and must
report what it could not verify; an **in-place** codex brief instead names the `unity-cli` skill
(§3) and requires it to verify in the live editor like any other agent.

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
BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->[;…]
```

**The last line is a contract, codex and bee alike.** Every implementor brief ends with: *"Your
final message's last line is exactly `BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->[;…]`"*
— one entry per unit the round serves (the wrapper's `-u` list), hashes comma-separated, `-` for
none: a round that finishes F2 and blocks LV-02 ends `BEES: results=F2:done:4a31ceeb;LV-02:blocked:-`.
Every review brief keeps the terminal `APPROVE`/`CHANGES_REQUIRED` as the last line and puts
`BEES: reviews=<unit>:<open-ids|->[;…]` on the line directly above it. `bees-status` greps that one
line and parses no prose; a report whose line is missing, duplicated, wrapped or names the wrong
units renders `malformed result` with its path — you decide whether the work or only the report
is repeated, never an automatic re-run.

**Every commit names its units.** The brief also says: *"Every commit carries one
`Bees-Unit: <plan-slug>/<unit>` trailer per unit it serves"* (`git commit --trailer
"Bees-Unit: skills-docs-rewrite-v3/F2"`; the slug is the plan's basename without the leading
`YYYY-MM-DD-` and `.md`, because unit ids recur across plans). Only the exact trailer value in
the row's `Repo` marks a unit landed — never the subject or body. Amend and rebase keep trailers;
a squash must carry them over, or the unit stops counting as landed.

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
Claude → `bee-implementor` (Opus 5.5) — with a fresh agent whose brief carries the blocked agent's
`Discovered` and `Tried` so the stronger model starts where the weaker one stopped, not from
scratch. If the top bucket is already blocked twice, it becomes an **owner decision** (options with
cost), never a third silent attempt.

## 8. Review

The reviewer is the **other vendor** from the implementor, so no model checks its own habits:

| implementor | reviewer | slot |
|---|---|---|
| Claude (`bee-mechanical`, `bee-implementor`) | codex gpt-6-sol, medium, via `codex-review` (OpenCode `opencode-review` by default, CLI fallback; `-e medium`) | none (background) |
| codex (luna or sol) | `bee-reviewer` (Opus 5.5, medium) | one Claude slot |

Cadence is what the owner chose in setup: per unit, or one diff review of the whole plan at the
end (then the reviewer is chosen by the vendor that implemented **most points**). A reviewer is
fresh, read-only, holds no resource, never edits, never the implementor of the unit. The review
covers a **quiescent tree** and states the commit or diff hash reviewed; never while another agent
edits the same domain. Input: changed files, surrounding code, acceptance criteria, related tests.
The report ends with the `BEES: reviews=…` line above the verdict (§7). Findings one line each
with a stable id (`MAJ-02 — sentence — file:line`), severity
**Critical / Major / Minor / Nit**; only Critical/Major block, and each finding carries its
**fix as exact code or text**, so the implementor applies rather than reinterprets. A recheck is
**targeted**: the brief carries the fix commit range, the reviewer verifies the listed findings
from that diff and its own stored rationale, reviews the delta and its dependencies for what the
fix introduced or exposed, and re-reads nothing else. It returns four id lists —
`Fixed / Partial / Open / Regressed` — plus new findings continuing the id sequence. No sub-agents
in a recheck; a codex recheck runs `opencode-review --no-subagents`. There is no round cap. For
codex, a clean recheck advances to the required holistic final pass, whose `APPROVE` closes the
loop; for `bee-reviewer`, a clean recheck closes it. The **churn check** ends either loop early: a
finding regressed twice, or new findings outnumbering closed ones two rounds running, is a
structural problem — stop, report, and re-plan the unit rather than queue another fix round. A
clean review is valid. Acceptance of a new document key, command or config surface includes an
**end-to-end fixture through the real path** (apply/export/run), not only a helper's unit tests.
When codex is out (usage limit, 429), the review goes to `bee-reviewer` and a note says so.

## 9. Status is derived (full mode)

There is no status document and nothing to dictate. `~/.claude/skills/bees/scripts/bees-status`
computes the board on demand from four things that exist anyway, and writes one thing back: the
plan's own `Status` column.

| fact | derived from |
|---|---|
| units, points, route, phase, dependencies | the plan's `## Checklist` — `ID`, `Item`, `Repo`, `Pts`, `Route`, `Phase`, `Depends`, `Status`; one row per unit, `Repo` relative to the plan's repo, comma-separated when the unit lands in several |
| rounds, outcome, context, session, pinned directory | out-files in `docs/plans/<plan>.work/` (gitignored) and their `.usage`/`.session`/`.cwd` |
| landed | `Bees-Unit: <plan-slug>/<unit>` trailers on `HEAD` in **every** repo of the row's `Repo` (§7) |
| decisions, acceptance, gaps, concerns, handoff facts | `docs/plans/<plan>.notes.md`, one line each |

A plan reviewed with another checklist shape (`| ID | Deliverable | Depends on | Status |`) is
converted, not retyped: `bees-status --plan <plan.md> init [--repo <rel>]` rewrites the table to
these columns, keeping IDs, links, items, dependencies and any extra column; it fills `?` for
`Pts`/`Route` (yours to set), `1` for `Phase`, `--repo` (default `.`) for `Repo`, and names the
units that still need a `### <ID> · ` heading (the ✅ marker lands there).

**Rounds.** Every codex wrapper takes `-u <unit>` (repeatable) and `-o docs/plans/<plan>.work/`,
which names the file `impl-<unit>[+<unit>…]-r<N>.txt` or `review-…`; anything else fails before a
file is written. A Claude bee has no wrapper: after its Agent result, save the report — a copy,
not a transcription — with the harness notification's context figure, never the agent's own.
Capture after the **final** `completed` task-notification: a bee can hand its report back, or send
an interim notification while its background work is pending, before that one arrives, and the
earlier figure is low (257,888 vs the final 294,032 on one bee, 2026-09-24):

```sh
bees-status --plan <plan.md> capture-bee -u G1 [-u G2] --role impl|review --ctx 118000 <<'REPORT'
<the bee's report, verbatim>
REPORT
```

`.work/` is never copied or synced: its mtimes are the round times the status is ordered by.

**Notes are the only thing you type.** One line, optional unit, first token picks the kind —
`accept:`, `decision:`, `gap:`, `concern:`, `blocked-on:`, `handoff:`; anything else is a plain
log line. A note that needs more than one line is a checklist row.

```sh
bees-status --plan <plan.md> note G1 "accept: 412 green; bee-reviewer clean at 3b73b3a"   # the only way to ✅
bees-status --plan <plan.md> note "decision: D7 one budget, both vendors: continue < 120k, none ≥ 200k"
bees-status --plan <plan.md> note B4 "handoff: editor closed; unity test … 412 green; Assets/X.cs uncommitted"
```

**Reading.** `BEES_PLAN=<plan.md>` saves the flag.

```sh
bees-status --plan <plan.md> show              # board: status, rounds, context per role, open review ids, diagnostics, Next (every ready unit)
bees-status --plan <plan.md> show --log        # notes, rounds and trailer commits in time order
bees-status --plan <plan.md> show --takeover   # repo HEADs, sessions + pinned dirs, unfinished units, tagged notes, phase + handoff line
```

The `Status` column is written by the tool, never by hand: ☐ queued · 🟡 attempted (a round
exists without a completed result, `paused`, `done, trailer missing`, `done, unmerged on <branch>` —
the trailered commit is on another ref such as a worktree branch, merge it — or `landed in part`,
a trailer in only some of the row's repos) · 🔴 blocked /
needs-decision · 🔵 landed (a trailer; `(review open)` while the newest valid review after it
names open ids for the unit) · ✅ accepted (an `accept:` note; the heading gets
`**✅ Done <date>**`). A report without its `BEES:` line shows as `malformed result` with its
path on the board — you decide whether the work or only the report is repeated. A failed codex
review (its wrapper's `Blocked:` out-file, ending `BEES: results=<unit>:blocked:-`) shows as
`review blocked` and never counts as a verdict.

**Refresh is automatic.** Each wrapper's exit runs `show --write` for its plan; a bee's
`SubagentStop` and every `Stop` (this skill's hooks) run it for each plan this Claude session wrote
a round, a capture or a note to (`.work/.sessions/<session id>`, from `CLAUDE_CODE_SESSION_ID`,
which a bee's shell shares) — never for a plan only another session is working on
(a `Stop` once rewrote a finished plan's rows after its repo's history was reset without
trailers). Writes are serialised per plan by a lock on `.work/.lock`. An `accept:` note is final
whatever git says later, so note it for every finished unit, and a squash or reset of a unit's
commits carries their `Bees-Unit:` trailers (§7). Run `show` yourself only to read the board. Commit the plan and its
notes file at every pause, decision or acceptance; nothing else needs committing.

## 10. The orchestrator's own context: hand off at 200k

The orchestrator is a session like any agent and pays its context every turn. Its cache is warm
for 1 hour, so idle gaps are not the risk; **size** is. The limit is **200k**, checked at every
pause, decision or acceptance (§6 step 10) from the harness's figure, not a guess.

At or past 200k, at the **next safe point**:

1. Start nothing new. Let running units reach a report; a reviewer mid-recheck finishes.
2. Bring the slot table to empty, or to a state the successor can pick up without this
   session's notifications: every running agent has reported and been retired with a handover
   (§3), or is a codex session under 200k the successor can resume by id in the same directory.
3. Note what no file derives — `handoff:` (editor state, verify command and last green count,
   half-done work, protected owner WIP paths, codex window reset time), `blocked-on:`,
   `concern:` — and commit the plan and its notes file.
4. Hand off with the takeover (**Phases** below): `show --takeover` prints its `Handoff:` line,
   the exact pipe into the `handoff` skill's script. Confirm the successor is up and report the
   tab name to the owner. This session stays open as a fallback and starts nothing.

Why not compaction: a compaction fires whenever the window fills, usually mid-unit with agents
running, and its summary is lossy in ways nobody chose. A handoff at a safe point is written by
the session that still knows everything, and `show --takeover` is already the handover. The
cost is the same order (a fresh system prefix plus the message). Compaction stays enabled as the
fallback for a single unit that overruns the window before a safe point; when it happens, the
first action after it is `bees-status --plan <plan.md> show --takeover` and `bees-watch`, not
trusting the summary.

**Phases.** The plan's checklist has a `Phase` column that groups rows into what one orchestrator
session should finish (≈ 5–8 units). When every unit in phase N is ✅, run
`~/.claude/skills/bees/scripts/bees-status --plan <plan.md> show --takeover | ~/.claude/skills/handoff/scripts/spawn-handoff.sh --cwd <repo> --task "<plan> phase N+1" --model <exact current model id>`
— the script is not on PATH and reads the message from stdin. If your context passes the one
threshold above before that, hand off the same way with `--task "<plan> phase N continued"`; the
takeover names the first unfinished unit and the phase is not complete. The takeover's `Phase:`
and `Handoff:` lines print both, ready to run. You decide a phase is done — it happens a few
times per plan, so no hook and no persisted phase state.

A handoff is never done with two agents mid-unit: the successor cannot receive their task
notifications, and the old session is then the only one that can. Retire them first.

## 11. What you say to the user

The harness asks you each turn to *privately* list what you need next. **Never print that list.**
"Needed next: (1) … (2) …" is the planning step leaking.

Say the **delta**, sized by what happened:

| turn | say | length |
|---|---|---|
| waiting, nothing new | `Waiting on codex (G1 round 3, log growing) and slot 2 (B4).` | 1 line |
| an agent reported | unit (pts · bucket · who) · outcome · commit/suite · one clause of substance · continued or retired, and why | 2–3 lines |
| a round went quiet | what §4's checks found and what you did about it | 1–2 lines |
| owner decision or blocker | question, options with cost, your recommendation | ≤ 6 lines |
| pause or session end | the board's changed rows, `Next`, uncommitted state | ≤ 10 lines |
| handoff | tab name, first unit the successor starts on, "this session stays open" | 3 lines |
| completion | what changed, decisions by id, verification, review status, open risks, what the user must decide | as needed |

Each fact once, ever. Dependencies as "after X". Numbers on the unit's line, not woven through
sentences.

Should read like:

> G1 (3 · low · codex luna) round 3 landed at `3b73b3a`: one projected-basis helper replaces two
> walk fallbacks, closes CX-03/04 with fail-before tests. bee-reviewer recheck running in slot 1.
> Slot 2 is at 110k with the board loaded, so it continues into B4 (8 · high) rather than a fresh
> spawn.
