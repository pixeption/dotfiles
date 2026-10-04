# Returns, the last-line contract, blockers and consults

Read when writing any brief (SKILL.md "Briefing an agent" says what goes in it) or handling a
report.

## Contents

- Return format
- Repeated findings
- Standing rules
- The last line is a contract
- Blocker cap and consults

## Return format

Claude agents return this; codex returns its final message, and you fill the same fields from the
diff and `.usage`:

```text
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

For a Unity suite, `Verification` quotes `unity-suite`'s count line and its
`report: <path> · finished <HH:MM>` line verbatim. Compare the time with the round's and never
open the XML: a count alone can come from an earlier run.

## Repeated findings

A review finding of a kind already seen on an earlier unit goes into the owning repo's guidance
(its `CLAUDE.md`, README or skill), and later briefs in that area link it. Left in a status note,
it is paid for again as a fix round on the next plan.

## Standing rules

The bee agent files carry only model and effort; every Claude brief carries its role's block,
`cat`-ed from `templates/` verbatim, never retyped:

| role | template |
|---|---|
| implementor (`bee-opus-*`, `bee-sonnet-medium`) | `~/.claude/skills/bees/templates/standing-rules-implementor.txt` |
| reviewer (`bee-reviewer`, `bee-reviewer-high`) | `~/.claude/skills/bees/templates/standing-rules-reviewer.txt` |
| consultant (`bee-consultant`, and the astra consult) | `~/.claude/skills/bees/templates/standing-rules-consultant.txt` |

The consultant's terminal `CHANGES_REQUIRED` is there because `opencode-review` fails an answer
without a verdict; it carries no meaning in a consult.

## The last line is a contract

Codex and bee alike. Every implementor brief ends with: *"Your final message's last line is exactly
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
