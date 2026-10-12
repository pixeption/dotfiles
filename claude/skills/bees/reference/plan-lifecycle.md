# Plan lifecycle: planning, mode, adoption, path maps, preflight, close

Read the passage you need when SKILL.md "Setup" sends you here: planning a queue row, choosing the
mode or adopting a plan, before the session's first codex unit, scheduling a unit that takes a
pipeline where no committed consumer has gone, or closing a plan at its green final gate. A context
handoff needs only the preflight.

## Contents

- Planning a row
- Choose the mode
- Adopting a plan
- Path maps
- Preflight
- Plan close
  - Triage
  - Pick-up
  - Retro

## Planning a row

SKILL.md "Lifecycle" steps 1–4, from `to plan` to `ready`:

1. Queue: take the first eligible row (SKILL.md "Setup"). `to plan` → a planner drafts the brief
   (`--kind plan-brief`, stage `brief draft`: usage, architecture note, and Outcome, Right, Wrong
   per item; `plan` skill "Item fields by stage"); the briefs of one group row go together.
2. Brief review, once per plan: the brief goes to the queue's Owner list, stage `brief review`. The
   next row's brief is drafted while this one runs (SKILL.md "Lifecycle"), so the list is never
   empty when a plan closes. The approved brief is frozen.
3. Expand once per plan, over all its items (`--kind plan-expand`, stage `expand`): AC, Reach,
   Verify, Score (an 8 or 13 split into items ≤ 5), Done when — once the work it builds on has landed, so Reach is
   read from the tree the items will change. A finding that would change an Outcome or an
   exclusion goes back to the Owner list with a proposed edit; every other AC question is yours,
   the planner's and codex's.
4. Plan review, stage `plan review`: one codex discovery round per expanded plan (`codex-review`
   "Plan review under bees"), checking the AC against the brief. Apply or disposition every
   finding; no High or Med open → stage `ready`.

## Choose the mode

Score every item (`plan` skill "Scoring"); the mode is picked by how many units there are and how
many sessions they need:

| plan | mode |
|---|---|
| one or two units, one sitting | **No bees.** Do it yourself, or one agent, one brief, no plan checklist, no reviewer unless the change is risky. A one-line task row (Plan `-`) runs here or in light mode, without a plan file. |
| a handful of units, one session | **Light.** One implementor, continued across units until its budget is spent; review per `reference/review.md` "Once per unit", so the smaller bookkeeping mode preserves the review boundary; status in your final message, no checklist. |
| multi-session, or two exclusive resources | **Full.** A queue row (added by the owner) and a plan in the `plan` skill's format with its Rules, Resume and log, rounds in its `.work/`, review per `reference/review.md`. |

Choosing "full" for a small plan is the error, not the safe default.

## Adopting a plan

On adopting a plan that arrives already scored, check its checklist for units that take a pipeline
where no committed consumer has gone, and schedule their path maps ("Path maps") before them: the
scoring step that would have caught them has already passed.

## Path maps

A unit that takes a pipeline somewhere no committed consumer has gone (a new kind of kit through
extract → seed → apply → parity → live parity, say) gets a **path map** first: a diagnosis that
runs a stub of the unit through every stage on one case — Play-Mode stages too (`ui_parity --live`
inside unity-live-run), since an Edit-Mode-only map misses live blockers — and lists each stage
that rejects or mis-measures it, with the owning repo. Each bug it returns is a checklist item fixed before the unit starts,
because a bug found mid-unit costs a block, a decision and a resumed session each time.

## Preflight

Machine checks (preflight, browser tools) are re-run each session and recorded nowhere, because an
environment line is stale on the next machine.

**Before the session's first codex unit**, run the preflight. The server reads
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

## Plan close

Once, when the plan's final gate is green (`plan` skill), by the orchestrator holding the plan,
before anything else is dispatched for it: triage, pick-up, retro, then the final report. A context
handoff resumes whichever of them is unfinished and never re-runs one already logged
(`reference/handoff.md`).

### Triage

1. Collect the plan's `gap:` lines (a `bee-haiku-runner` counts the log — never read it yourself,
   SKILL.md rule 10). Any gap that came up twice becomes a row.
2. Every `?` row gets one outcome: **close** (small, or a workaround — which alone never closes a
   gap whose summed cost is high; one Status line, row removed next triage), **fix** (kept for
   pick-up), or **owner** (needs a design or product decision: Status `owner: <question>` with
   options and a recommendation, named in the final report — never in the Owner list, since only
   the owner adds a row). No `?` row survives two plan closes.

### Pick-up

One batch: cluster the `fix` rows by area (one scout answers "which files does each touch?" when it
isn't obvious); take at most **3 clusters**, highest summed minutes lost first — `unknown` stays
unknown, never zero; among unknowns more `Hits`, then the lower id, or one costing scout where the
pick would be arbitrary. Mark each picked row's Status `picked: <cluster title>` in
`tooling-gaps.md` and name the clusters in the final report, never in the Owner list: only the
owner adds a queue row. The rest wait for the next plan close. Backlog items are owner-ordered and
queued only by the owner.

### Retro

The `bee-haiku-runner` counts the plan's log and you append one row per plan to
`docs/plans/retro-numbers.md`: rounds per item by outcome, review passes per item, `docs(plans)`
commits and item ids per item commit (`git log --first-parent --format=%s <from>..<to>`), fix rounds by a fresh bee vs the implementor, orchestrator `replan` log events, incomplete
expansions and mid-run splits,
out-of-scope review findings, AC sent back after approval, escapes per level, handoffs per plan,
hours a row waited in Owner, queued-but-never-started and started-without-a-row, active vs waiting
wall-clock per item and accepted items per orchestrator-hour, with their scores beside it. A missing timing is `unknown`, a
number the plan cannot produce `not applicable`, never 0. At most 3 rule changes per retro, each
a skill edit whose commit message carries its before/after numbers and the `retro-numbers.md` row;
a forecast is labelled a forecast. The final report carries the numbers, the proposed changes and
the picked clusters; the owner reads it and can veto.

Before a batch activates, write its success thresholds and comparison scope (units, sizes,
scores, concurrency and sharding) to `retro-numbers.md`, so its result can be judged.
Freeze correctness guardrails beside them: required verification recorded and no blocking
review finding open for every acceptance; a red target fixed before the next integrate;
an escape bound naming count per plan, worst severity and recovery minutes. A guardrail
breach blocks keeping the batch regardless of throughput.
Judge a batch as one, with no per-rule causal claim. Revert a batch or rule on an attributable
regression or a missed predeclared threshold over two comparable retros, never on an unchanged
aggregate alone. Too little comparable evidence is inconclusive; report it without a per-rule
conclusion.
