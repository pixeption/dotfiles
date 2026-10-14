# Returns, the last-line contract, blockers and advice

Read when a brief or report needs more than SKILL.md "Briefing an agent" and rule 10 give: a brief
kind other than `impl`, an item without Today and Approach, light mode, a codex or scout brief, the BEES line's
exact form, or a blocker or a question for the owner.

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
or a `cat` stays in your context every later turn. It prints outcome, suite lines, what it
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
  reviewer or planner also gets its return contract; an advisor writes its answer to its report file, no
  BEES line, ending `CHANGES_REQUIRED`, since the decision log points to the answer.
- "Start at" and the filter are SKILL.md "Briefing an agent"'s. An item without Today and Approach
  (a plan expanded before them) gets its starting points from a `bee-scout` first: the scout lists
  the files and symbols that hold what changes and the test classes that exercise them, and its
  `Answer` lines become the brief's "Start at" and filter.
- A fix round goes back to the implementor (SKILL.md "Briefing an agent"; `reference/budgets.md`
  "Continue, spawn or hand over") because a fresh bee re-reads what the implementor still holds;
  spawn fresh only past either line.
- `--kind plan-brief` and `--kind plan-expand` are the read-only planner at the `brief draft` and
  `expand` stages of the `plan` skill's "Item fields by stage": each adds its stage block
  (`templates/planner-brief.txt`, `templates/planner-expand.txt`) before the planner's standing
  rules and return contract, because one owned block per stage keeps the fields and budget rules
  consistent. A `plan-brief` for an owner-added queue row that has no plan yet runs with
  `--work <plan>.work` and the row on stdin. You write its `Expanded` text into the plan
  — the queued row's brief goes to the Owner list for `brief review`, a `Back to owner` item too.
  An implementor treats the item's score as an estimate and never re-sizes it
  (`templates/standing-rules-implementor.txt`).
- A `--plan` unit without a `### <ID> · ` section fails the run, so every pointer resolves.
- A gate a codex runner session runs is `--kind gate --units GATE-<n>`: no plan section,
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
| implementor (`bee-opus-*`) | `~/.claude/skills/bees/templates/standing-rules-implementor.txt` |
| reviewer (`--kind review`, `--kind recheck`) | `~/.claude/skills/bees/templates/standing-rules-reviewer.txt` |
| advisor (`--kind advise`: `bee-opus-high`, then Sol; "Blocker cap and consults") | `~/.claude/skills/bees/templates/standing-rules-advisor.txt` |
| planner (`--kind plan-brief`, `--kind plan-expand`, a read-only `bee-opus-*`) | `~/.claude/skills/bees/templates/standing-rules-planner.txt` |

The advisor's terminal `CHANGES_REQUIRED` is there because `opencode-review` fails an answer
without a verdict; it carries no meaning in advice.

## The last line is a contract

Codex and bee alike; a Claude brief's return template carries it. Every implementor brief ends with: *"Your final message's last line is exactly
`BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->[;…]`"* — one entry
per unit the round serves (the wrapper's `-u` list), hashes comma-separated, `-` for none: a round
that finishes F2 and blocks LV-02 ends `BEES: results=F2:done:4a31ceeb;LV-02:blocked:-`.

A planner ends `BEES: results=<unit>:<done|partial|blocked>:-`; `partial` lists the items still
`to expand`, an incomplete expansion never becomes `ready`, and only the items under `Back to
owner` wait on the owner.

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

**A question for the owner goes to the advisors first** — a capped blocker, an implementor's
`Needs decision` — because a lane must never wait on the
owner. First grep the plan log's `decision:` lines and reuse a matching answer unless new evidence
changes the question. Otherwise, in order:

1. An Opus 5.5 high advisor: `bee-opus-high`, read-only, `--kind advise`.
2. If it cannot decide, a Sol high advisor on the same brief: `opencode-review -m
   openai/gpt-6.1-sol-fast -e high --no-subagents` in a fresh session (never `-s` into the implementor
   or review loop), out-file `review-<unit>-advice-r<N>.txt`, so `bees-watch --dir` sees it.
3. If neither decides: one line in the queue's Owner list; the item is 🔴, its lane is released or
   handed to the next ready item, and other work continues.

An advisor decides only within the approved brief and the owner's rules (the plan's Rules, the
standing owner rules); a question that needs either changed comes back `Cannot decide` and goes to
the Owner list. Log each answer `- <date> [<ID>] decision: <answer> (advisor <opus|sol>,
<report or out-file>)`.

Re-brief the implementor with the decision: continue the blocked agent if it is under the
continuation line (`reference/budgets.md`), otherwise a fresh one in the same bucket whose brief
carries the STOP report and the decision. A unit blocked again after an advised way through goes to
the next step of the chain, never a third silent attempt.
