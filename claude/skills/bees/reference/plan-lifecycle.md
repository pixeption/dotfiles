# Plan lifecycle: planning, mode, adoption, path maps, preflight, close

Read the passage you need when SKILL.md "Setup" sends you here: planning a plan, choosing the
mode or adopting a plan, before the session's first codex unit, scheduling a unit that takes a
pipeline where no committed consumer has gone, or closing a plan at its green final gate. A context
handoff needs only the preflight.

## Contents

- Planning a plan
- Choose the mode
- Adopting a plan
- Path maps
- Preflight
- Plan close

## Planning a plan

SKILL.md "Lifecycle" steps 1–4, from `brief draft` to `ready`; the status file's `Stage:` moves at
each step. Each review stage is at most two codex rounds, one discovery and one recheck of the
fixes, never a round 3.

1. `brief draft`: a planner drafts the brief (`--kind plan-brief`, `--work <plan>.work`) for the
   plan the owner named: usage, architecture note, and Outcome, Right, Wrong per item (`plan`
   skill "Item fields by stage").
2. `brief review`: codex round 1 over the brief (consistency, dependencies, scores); the planner
   applies the findings (`plan-brief --round 2`); codex round 2 rechecks only those ids. A High or
   Med still open after round 2 goes to the owner beside the brief. Then a Blocked
   `owner: approve the brief` line; the owner's approval writes `**Brief approved:**`, and the
   brief is frozen.
3. `expand`: once per plan, over all its items (`--kind plan-expand`): Today, Approach, Tests,
   Score (an 8 or 13 split into items ≤ 5), Done when — once the work it builds on has landed, so
   they are read from the tree the items will change.
4. `plan review`: skipped when the plan has three items or fewer (GATE rows not counted).
   Otherwise codex round 1 (`codex-review` "Planning reviews under bees"), checking the Tests against
   the brief; the orchestrator applies findings to the expansion or dispositions them; round 2
   rechecks those ids; a High or Med still open after it is ruled by the orchestrator and logged
   `decision:`. Then `ready`.

An approved brief is never edited: a finding against it is an `owner:` line with a proposed edit.

## Choose the mode

Score every item (`plan` skill "Scoring"); the mode is picked by how many units there are and how
many sessions they need:

| plan | mode |
|---|---|
| one or two units, one sitting | **No bees.** Do it yourself, or one agent, one brief, no plan checklist, no reviewer unless the change is risky. A one-line task needs no plan file and runs here or in light mode. |
| a handful of units, one session | **Light.** One implementor, continued across units until its budget is spent; review per `reference/review.md` "Once per unit", so the smaller bookkeeping mode preserves the review boundary; status in your final message, no checklist. |
| multi-session, or two exclusive resources | **Full.** A plan in the `plan` skill's format with its status file and log, rounds in its `.work/`, review per `reference/review.md`. |

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
~/.claude/skills/codex-implementor/scripts/opencode-preflight -m openai/gpt-6.1-sol-fast -C <repo the unit edits> --repo <each other repo the unit reads or edits>...
```

Exit 0 = the server is up, carries the fence, lists the model, and every `--repo` outside `-C` is
inside the fence (as given and symlink-resolved; the last matching rule wins). A repo you do not
pass is unchecked, so pass the plan's repo and every sibling the brief names, as absolute paths.
A failure restarts an idle server and checks again; a busy server is never restarted. What still
fails names the path to allow in `opencode.jsonc` — an owner edit; route those units to Claude
until then.

## Plan close

Once, at a green final gate, by the orchestrator holding the plan, after the gate runner has
handed back and exited:

1. Compose the report and keep it in the status file until it is sent.
2. Stop the OpenCode server only when no session is busy and no client is attached (the
   preflight's busy check, then its `pkill` line; `codex-round stop-server` once it exists);
   otherwise record why it remains running.
3. Delete the gitignored `<plan>.work/` and record that it is not recoverable.
4. Send the report.
5. Make the one close commit by path, deleting `<plan>.md`, `.log.md`, `.status.md` and every
   other tracked `<plan>.*`, with the report in the body. Subject:
   `docs(plans): close <plan> — <one clause>`.

Before step 5, Now names the next unfinished close step; after it no close action remains, and
the close commit is the durable completion record.

The report (about 10 lines) comes from the checklist, the status file and the log: the items
landed with their SHAs (`git log --grep '<ID>'`); the findings and their fix units (the log's
`review:` lines, the struck Fixes lines); the backlog rows added with priority `review`; the
rework count — findings whose fix changed an item that already depended on the faulty one and had
landed; and whether the server was stopped or why it remains running.
