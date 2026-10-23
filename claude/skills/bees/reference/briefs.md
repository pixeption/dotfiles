# Briefs, continuations and advice

Read when a brief or report needs more than SKILL.md "Briefing an agent" and "Rules" give: a brief
kind other than `impl`, light mode, a scout brief, a continue-or-spawn decision, or a blocker or a
question for the owner.

## Reports

`bees-report` (SKILL.md "Rules") prints outcome, suite lines, needs, blocker and options, each
finding's first line, the `.usage` context, BEES and verdict; `--finding MAJ-02,F3` adds those
whole blocks (an id the file lacks prints `MISSING:`). A Claude bee's report path is absolute,
since a lane bee runs in another worktree:
`<repo>/docs/plans/<plan>.work/report-<unit>-<kind>-r<N>.md`, in your scratchpad in light mode; the
`report-` prefix keeps it out of `bees-watch --dir`.

## Composing a brief

The lane is `reuse`d before dispatch because the bee only claims it.

- `--kind` picks the role's standing rules and return contract and names the `brief-` and `report-`
  files. An advisor writes its answer to its report file, no BEES line, ending `CHANGES_REQUIRED`
  only because `codex-round review` fails an answer without a verdict.
- `--kind plan-brief` and `--kind plan-expand` are the read-only planner at the `plan` skill's
  `brief draft` and `expand` stages ("Item fields by stage"), each adding its stage block
  (`templates/planner-brief.txt`, `templates/planner-expand.txt`), so one block owns each stage.
- A `--plan` unit without a `### <ID> · ` section fails the run, so every pointer resolves.
- A run (a gate's suites, a baseline) is `--kind run --units GATE-<n>`, stdin naming the slot, target SHA
  and commands, carrying codex-implementor's `templates/run-contract.md` and no plan section.
- `--kind fix` and `--kind recheck` take `--work <plan>.work`, since a fix unit has no section. A
  review-finding fix's stdin carries `Fixes:`, `Review:` (report, finding ids) and `Filter:` (the
  original item's); a gate repair's `Fixes:`, `Gate:` (gate evidence, tested SHA, failing checks)
  and `Filter:` (the repair's verification). A gate repair of unknown cause is a diagnosis first,
  which supplies the cause and a scoped repair; its recheck judges the repair against that evidence.
- `--include` adds a repo's slot block (nono4u: the workspaces lane brief), its `<placeholders>`
  filled by `--set`; an unfilled one fails the run.
- Light mode: `--work <scratchpad dir>` instead of `--plan`, with the unit's acceptance and all
  required verification on stdin, because no plan section supplies them.

## Continue or spawn

- **Continue** while the mod allows it and the next unit routes to the same agent and area:
  SendMessage to a Claude bee; the brief is the delta.
- **Re-brief inside the cache clock or not at all** (5 minutes, from its report):
  after it the next turn re-writes the whole context, so decide and answer in the same turn.
- **Spawn fresh** otherwise: the mod refuses the agent, another agent, area, resource or repo, or a
  review of its own work. A retiring holder's last message may start `[bees:handover]` to pass the
  refusal. A `handoff` result's successor is a fresh agent of the same type on the same unit at the next
  round, holding its slot by handover, briefed with `Piece: continue from <handoff file>` — never a
  replan, a split or a decision taken for it.

## Scout briefs

One question, the area to look in, what "answered" looks like, and "read-only, no editor, no
sub-agents, stop when answered, `Needs diagnosis` if it needs a run or a judgment". Paste its
`Answer`/`Constraints` lines (`bee-scout.md`) into the implementor's brief, never the transcript.

- Bad: "Diagnose why selection breaks after undo." (a diagnosis unit)
- Good: "List every writer of `PuzzleProgress` and the tests that cover `UndoStack`; file:line each."

## Repeated findings

A review finding of a kind already seen on an earlier unit goes into the owning repo's guidance
(its `CLAUDE.md`, README or skill), and later briefs in that area link it; left in a status note,
it is paid for again as a fix round on the next plan.

## Standing rules

The bee agent files carry only model and effort; `bees-brief` adds the role's block,
`~/.claude/skills/bees/templates/standing-rules-<role>.txt`, never retyped: `implementor`
(`bee-opus-*`), `reviewer` (`review`, `recheck`), `advisor` (`advise`, "Consults") or `planner`
(`plan-brief`, `plan-expand`, a read-only `bee-opus-*`).

## Consults

A question for the owner — a capped blocker, a `Needs decision` — goes to the advisors first,
because a lane must never wait on the owner. Reuse a matching `decision:` line from the plan log
unless new evidence changes the question; otherwise, in order:

1. `bee-opus-high`, read-only, `--kind advise`.
2. If it cannot decide: a `Blocked` `owner:` line; the lane is released or handed to the next ready
   item, and other work continues.

An advisor decides only within the approved brief and the owner's rules; a question needing either
changed comes back `Cannot decide`. Log each answer `- <date> [<ID>] decision: <answer> (<report>)`, then re-brief per "Continue or spawn" with the STOP report and
the decision. A unit blocked again after an advised way through gets a `Blocked` `owner:` line.
