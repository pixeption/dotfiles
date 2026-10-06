# Returns, the last-line contract, blockers and consults

Read when writing any brief (SKILL.md "Briefing an agent" says what goes in it) or handling a
report.

## Contents

- Return format
- Reports
- Composing a brief
- Repeated findings
- Standing rules
- The last line is a contract
- Blocker cap and consults

## Return format

A Claude implementor or reviewer brief carries its role's return contract
(`templates/return-implementor.txt` or `templates/return-reviewer.txt`, which `bees-brief` fills
with the report path): the full report goes to that file and the hand-back is a few lines ending in
the BEES line. Codex returns
its final message in the out-file, and you fill the same fields from the diff and `.usage`.

A suite count is evidence only with the `report: … · finished <HH:MM>` line quoted beside it:
compare the time with the round's and never open the XML, since a count alone can come from an
earlier run.

## Reports

Every report is read once, compact, because a hand-back or a `cat` stays in your context every
later turn:

- A Claude bee's report path is absolute — a lane bee runs in another worktree —
  `<repo>/docs/plans/<plan>.work/report-<unit>-<impl|fix|review|recheck>-r<N>.md`, in your
  scratchpad in light mode. The `report-` prefix keeps it out of `bees-watch --dir`.
- Read finished reports and codex out-files with
  `~/.claude/skills/bees/scripts/bees-report <file>...`: outcome, suite lines, what it needs from
  you, blocker and options, each finding's first line, BEES and verdict, in a few lines. Open a
  file only for the detail a decision needs, and then only that part (`grep -n -A3 MAJ-02 <file>`).
- A hand-back that ignores the contract is acted on as it is; the next brief to that agent says so
  in one line.

## Composing a brief

Run `bees-brief` with only the unit's own lines on stdin, then hand the agent the path it prints
(`Read <brief> and do what it says.`):

```sh
~/.claude/skills/bees/scripts/bees-brief --plan docs/plans/<plan>.md --units DR-02,DR-01 \
  --kind impl --round 1 \
  --include .claude/skills/workspaces/templates/lane-brief.txt \
  --set lane=lane-1 --set 'task branch=task/lane-1-x' --set "full base sha=$B" \
  --set 'target branch=feat/x' <<'EOF'
Objective: <one sentence>
Decision: <each owner decision or override since the plan was written, one line each>
May change: <paths>; nothing else.
EOF
```

- `--kind` is `impl`, `fix`, `review`, `recheck`, `consult` or `gate`; it picks the role's standing rules
  and names the files `brief-` and `report-<units>-<kind>-r<N>`. An implementor or reviewer also
  gets its return contract; a consult answers directly, no report file or BEES line, ending
  `CHANGES_REQUIRED`.
- A `--plan` unit without a `### <ID> · ` section fails the run, so every pointer resolves.
- A phase gate a `bee-sonnet-medium` runs is `--kind gate --units GATE-<phase>`: no plan section,
  implementor rules and return contract, so its report lands in a file like any other — a
  hand-written brief lacks the heredoc line, and the Write tool refuses subagent report files.
- The brief points the agent at each unit's plan section as its acceptance, so write acceptance
  only where it departs from the section. A fix or recheck names the review file and the ids.
- `--include` adds a repo's slot block (nono4u: the workspaces lane brief) with its
  `<placeholders>` filled by `--set`; an unfilled one fails the run.
- Light mode has no plan: pass `--work <scratchpad dir>` instead of `--plan`, and include the
  unit's acceptance criteria and all required verification on stdin, because no plan section
  supplies them.
- A codex brief is not built this way: it follows codex-implementor's `templates/brief.md`.

## Repeated findings

A review finding of a kind already seen on an earlier unit goes into the owning repo's guidance
(its `CLAUDE.md`, README or skill), and later briefs in that area link it. Left in a status note,
it is paid for again as a fix round on the next plan.

## Standing rules

The bee agent files carry only model and effort; every Claude brief carries its role's block from
`templates/`, added by `bees-brief`, never retyped:

| role | template |
|---|---|
| implementor (`bee-opus-*`, `bee-sonnet-medium`) | `~/.claude/skills/bees/templates/standing-rules-implementor.txt` |
| reviewer (`bee-reviewer`, `bee-reviewer-high`) | `~/.claude/skills/bees/templates/standing-rules-reviewer.txt` |
| consultant (`bee-consultant`, and the astra consult) | `~/.claude/skills/bees/templates/standing-rules-consultant.txt` |

The consultant's terminal `CHANGES_REQUIRED` is there because `opencode-review` fails an answer
without a verdict; it carries no meaning in a consult.

## The last line is a contract

Codex and bee alike; a Claude brief's return template carries it. Every implementor brief ends with: *"Your final message's last line is exactly
`BEES: results=<unit>:<done|blocked|paused|needs-decision>:<hashes|->[;…]`"* — one entry per unit
the round serves (the wrapper's `-u` list), hashes comma-separated, `-` for none: a round that
finishes F2 and blocks LV-02 ends `BEES: results=F2:done:4a31ceeb;LV-02:blocked:-`.

Every review brief keeps the terminal `APPROVE`/`CHANGES_REQUIRED` as the last line and puts
`BEES: reviews=<unit>:<open-ids|->[;…]` on the line directly above it.

You read that one line, not the prose, for the outcome. A report whose line is missing,
duplicated, wrapped or names the wrong units is malformed — you decide whether the work or only
the report is repeated, never an automatic re-run. Commit subjects name the unit
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
