# Returns, the last-line contract, blockers and consults

Read when a brief or report needs more than SKILL.md "Briefing an agent" and rule 10 give: a brief
kind other than `impl`, an item without a Reach, light mode, a codex or scout brief, the BEES line's
exact form, or a blocker or consult.

## Contents

- Return format
- Reports
- Composing a brief
- Codex and scout briefs
- Repeated findings
- Standing rules
- The last line is a contract
- Blocker cap and consults

## Return format

A Claude implementor or reviewer brief carries its role's return contract
(`templates/return-implementor.txt` or `templates/return-reviewer.txt`, which `bees-brief` fills
with the report path): the full report goes to that file and the hand-back is a few lines ending in
the BEES line. Codex returns
its final message in the out-file, and you fill the same fields from the diff and `.usage`. A
suite count needs its `report:` line (SKILL.md rule 5) because a count alone can come from an
earlier run.

## Reports

Every report is read once, compact, through `bees-report` (SKILL.md rule 10), because a hand-back
or a `cat` stays in your context every later turn. It prints outcome, suite lines, sizing, what it
needs from you, blocker and options, each finding's first line, the `.usage` context, BEES and
verdict; `--finding MAJ-02,F3` adds each named finding's whole block with its fix (an id the file
lacks prints `MISSING:`).

A Claude bee's report path is absolute — a lane bee runs in another worktree —
`<repo>/docs/plans/<plan>.work/report-<unit>-<impl|fix|review|recheck>-r<N>.md`, in your scratchpad
in light mode. The `report-` prefix keeps it out of `bees-watch --dir`.

## Composing a brief

The command, its stdin and the kinds are SKILL.md "Briefing an agent"'s. The lane is `reuse`d before
dispatch because the bee only claims it.

- `--kind` picks the role's standing rules and names the files `brief-` and `report-<units>-<kind>-r<N>`. An implementor,
  reviewer or planner also gets its return contract; a consult answers directly, no report file or
  BEES line, ending `CHANGES_REQUIRED`.
- Reach copying is SKILL.md "Briefing an agent"'s. An item without a Reach (every live plan)
  gets one from a `bee-scout` first: when the section names one side of a pair (writer/reader,
  export/import, check/apply, seed/parity), the scout lists the readers, validators and lowerings of
  what changes, and its `Answer` lines become the brief's "May change" and filter.
- A fix round goes back to the implementor (SKILL.md "Briefing an agent"; `reference/budgets.md`
  "Continue, spawn or hand over") because a fresh bee re-reads what the implementor still holds;
  spawn fresh only past either line.
- `--kind plan-ac` and `--kind plan-expand` are the read-only planner at stage 1 and stage 2 of the
  `plan` skill's "Item fields by stage": each adds its stage block (`templates/planner-ac.txt`,
  `templates/planner-expand.txt`) before the planner's standing rules and return contract, because
  one owned block per stage keeps the fields and budget rules consistent. A `plan-ac` for a queue
  row or gap cluster that has no plan yet runs with `--work <plan>.work` and the row or cluster on
  stdin. You write its `Expanded` text into the plan — stage-1 drafts go to the queue's Owner list,
  an `AC back to owner` item too. Under batch A a live item scored 5 or more gets `plan-expand`, recording Reach
  and Sizing; one below 5 is sized by its implementor's first-read check, since a planner round per
  2-point item costs more than the overrun it prevents. Either way no item proceeds on an inherited
  M or `unknown`: that is a `Re-plan`.
- A `--plan` unit without a `### <ID> · ` section fails the run, so every pointer resolves.
- A phase gate a `bee-sonnet-medium` runs is `--kind gate --units GATE-<phase>`: no plan section,
  implementor rules and return contract, so its report lands in a file like any other — a
  hand-written brief lacks the heredoc line, and the Write tool refuses subagent report files.
- The brief points the agent at each unit's plan section as its acceptance, so write acceptance
  only where it departs from the section. A fix or recheck names the review file and the ids.
- `--include` adds a repo's slot block (nono4u: the workspaces lane brief) with its
  `<placeholders>` filled by `--set`; an unfilled one fails the run.
- A lane brief names skills by name or lane path; the rule lives in the repo's slot block.
- Light mode has no plan: pass `--work <scratchpad dir>` instead of `--plan`, and include the
  unit's acceptance criteria and all required verification on stdin, because no plan section
  supplies them.
- A codex brief is not built this way: it follows codex-implementor's `templates/brief.md`.

## Codex and scout briefs

- A **codex** brief gives passages, not documents (codex-implementor "What the session loads, and
  what it doesn't"), and runs with `-C` set to the repo the unit edits — the session is
  pinned to it for life. Pass every other repo it names, a read-only one too, as an absolute
  `--repo` to the OpenCode wrapper so preflight checks the fence allows it.
- A **blind-worktree** codex brief states it cannot run Unity and must report what it could not
  verify; an **in-place lane** codex brief carries the editor card and requires live verification.
- Point rather than paste (SKILL.md "Briefing an agent"): restating a section means reading it
  first.

Examples:

- Bad: "Investigate this and tell me what you think."
- Bad: "Check the lock before running the suite and retry if another agent is using it."
- Good: "You hold `lane-1` (`~/code/workspaces/lane-1`, its `Game/` and `GameCore/`). Another
  agent holds `lane-2`, and `integration` is off-limits; do not run or edit anything there. If a
  command fails because the project is held, stop and report."

A **scout brief** is one question, the area to look in, what "answered" looks like, and
"read-only, no editor, no sub-agents, stop when answered, `Needs diagnosis` if it needs a run or a
judgment". Its return is the scout format in `bee-scout.md`; paste its `Answer`/`Constraints`
lines into the implementor's brief, never the transcript.

- Bad: "Diagnose why selection breaks after undo." (a diagnosis unit)
- Good: "List every writer of `PuzzleProgress` and the tests that cover `UndoStack`; file:line each."

## Repeated findings

A review finding of a kind already seen on an earlier unit goes into the owning repo's guidance
(its `CLAUDE.md`, README or skill), and later briefs in that area link it. Left in a status note,
it is paid for again as a fix round on the next plan.

## Standing rules

The bee agent files carry only model and effort; every Claude brief carries its role's block from
`templates/`, added by `bees-brief`, never retyped:

| role | template |
|---|---|
| implementor (`bee-opus-*`, `bee-sonnet-medium`, `bee-haiku-runner`) | `~/.claude/skills/bees/templates/standing-rules-implementor.txt` |
| reviewer (`bee-reviewer`, `bee-reviewer-high`) | `~/.claude/skills/bees/templates/standing-rules-reviewer.txt` |
| consultant (`bee-consultant`, and the astra consult) | `~/.claude/skills/bees/templates/standing-rules-consultant.txt` |
| planner (`--kind plan-ac`, `--kind plan-expand`, a read-only `bee-opus-*`) | `~/.claude/skills/bees/templates/standing-rules-planner.txt` |

The consultant's terminal `CHANGES_REQUIRED` is there because `opencode-review` fails an answer
without a verdict; it carries no meaning in a consult.

## The last line is a contract

Codex and bee alike; a Claude brief's return template carries it. Every implementor brief ends with: *"Your final message's last line is exactly
`BEES: results=<unit>:<done|blocked|paused|needs-decision|replan>:<hashes|->[;…]`"* — one entry
per unit the round serves (the wrapper's `-u` list), hashes comma-separated, `-` for none: a round
that finishes F2 and blocks LV-02 ends `BEES: results=F2:done:4a31ceeb;LV-02:blocked:-`.

`replan` is the implementor's `Re-plan` return under `templates/standing-rules-implementor.txt`;
its report's `Sizing` carries the real counts, which the `plan-expand` round SKILL.md "Briefing an
agent" names rewrites with the pieces; it is logged because it means planning missed something. A planner ends
`BEES: results=<unit>:<done|partial|blocked>:-`; `partial` lists the items still `to expand`, and an
incomplete expansion never becomes `ready`.

Every review brief keeps the terminal `APPROVE`/`CHANGES_REQUIRED` as the last line and puts
`BEES: reviews=<unit>:<open-ids|->[;…]` on the line directly above it.

You read that one line, not the prose, for the outcome; a malformed one is handled as SKILL.md
"Briefing an agent" says. Commit subjects name the unit
(`feat(ui): STEP-03 …`); nothing parses them.

## Blocker cap and consults

**Two attempts, then stop.** An agent gets at most two materially different attempts at a
blocker. If the second fails it STOPs and reports `STOP. Goal / Discovered / Blocker / Tried (both
attempts) / Options (1–3) / Need from orchestrator`. It stops before any attempt on a missing
decision or a held resource. A brief that says "keep trying" or "retry until it works" is
forbidden; the implementor standing rules carry the cap.

**A capped-out blocker goes to a consultant** one tier up, same vendor, read-only, with the
consultant standing rules:

| blocked implementor | consultant |
|---|---|
| codex gpt-6.1-sol | `opencode-review -m openai/gpt-6-astra -e high` (read-only channel, background) |
| `bee-opus-*`, `bee-sonnet-medium` | `bee-consultant` (one slot) |

Run an astra consult with `--no-subagents` in a fresh session (never `-s` into the implementor or
review loop), out-file `review-<unit>-consult-r<N>.txt`, so `bees-watch --dir` sees it and its
history stays out of both loops. The consultant returns a root cause and a way through, not a
diff.

Re-brief the implementor with that answer: continue the blocked agent if it is under the
continuation line (`reference/budgets.md`), otherwise a fresh one in the same bucket whose brief
carries the STOP report and the consultant's answer. A unit blocked again after a consultant's way
through, or a `Needs owner` answer, is an **owner decision** (options with cost), never a third
silent attempt. Log the consult on the unit (`[G1] consult: astra — root cause …`).
