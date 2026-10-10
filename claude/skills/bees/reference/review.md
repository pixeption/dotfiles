# Review policy

Read before briefing any reviewer or choosing one.

## Pairing

The reviewer is the **other vendor** from the implementor, so no model checks its own habits:

| implementor | reviewer | slot |
|---|---|---|
| Claude (`bee-opus-*`, `bee-sonnet-medium`) | codex via `codex-review` (`opencode-review -m openai/gpt-6.1-sol -e medium`, CLI fallback) | one (background) |
| codex, unit scored 1–5 | `bee-reviewer` | one |
| codex, unit scored 8–13 | `bee-reviewer-high` | one |

When codex is out (usage limit, 429), the review goes to the Claude reviewer for its score, and a
log line says so.

## Once per unit

| What | Review |
|---|---|
| Every expanded phase of a plan | one discovery round in plan-review mode |
| An item implemented in one piece | one review of the item, then fix → recheck under `codex-review`'s contract |
| An item split into pieces | **no per-piece review**. A serial piece is a private lane checkpoint (builds, its `Done when` holds, committed on the task branch, not integrated); a parallel piece integrates only if it leaves the target green under the post-integrate check. When the last piece lands, **one review of the complete parent change** at the parent's effort — on the lane for a serial group, before it integrates; on the target for parallel pieces, over their recorded SHAs so unrelated commits are excluded. Its fix round runs on the same lane, or on a lane from the reviewed target |
| A fix that applies the reviewer's exact fixes | orchestrator inspection ("Rechecks and the end of the loop") |
| A production diff ≤ ~5 lines with a fail-before test | orchestrator inspection (same) |

Code reviews check the change against the item's ACs. Parallel pieces sit on the target green but
unreviewed until the parent review; the parent review and the phase gate both precede anything
leaving that branch. A parent's acceptance records the complete filter, the target checks and the
review verdict for the reviewed SHA — the last piece's filter alone is not the parent's. A
whole-range review reads more than a piece review, so its recheck is a fresh session pointed at
the review file whenever the first passed 120k (`budgets.md`).

## The review

- A reviewer is fresh, read-only, holds no resource, never edits, and is never the implementor of
  the unit. Every Claude review brief carries the reviewer standing rules
  (`reference/briefs.md`).
- It covers a **quiescent tree** and states the commit or diff hash reviewed; never while another
  agent edits the same domain. Input: changed files, surrounding code, acceptance criteria,
  related tests.
- Findings are one line each with a stable id (`MAJ-02 — sentence — file:line`), severity
  **Critical / Major / Minor / Nit**; only Critical/Major block, and each carries its **fix as
  exact code or text**, so the implementor applies rather than reinterprets. A clean review is
  valid.
- The report ends with `BEES: reviews=…` directly above the verdict.
- Accepting a new document key, command or config surface takes an **end-to-end fixture through
  the real path** (apply/export/run), not only a helper's unit tests.

## Rechecks and the end of the loop

A recheck is **targeted**: the brief carries the fix commit range; the reviewer verifies the listed
findings from that diff and its stored rationale, reviews the delta and its dependencies for what
the fix introduced or exposed, and re-reads nothing else. It returns `Fixed / Partial / Open /
Regressed` id lists plus new findings continuing the id sequence. No sub-agents in a recheck; a
codex recheck runs `opencode-review --no-subagents`.

Two cases need no reviewer, because checking a small diff against a written expectation costs
less than a spawn:

- a fix round that applies a reviewer's exact fixes — inspect the fix diff yourself and tick every
  finding id against its fix text;
- a unit whose production diff is about five lines or fewer and comes with a fail-before test.

Log either as `review: orchestrator inspection`; a clean inspection closes the loop. Anything
else, including a fix that departs from the reviewer's fix text, goes to the reviewer.

There is no round cap. For codex, a clean recheck advances to the holistic final pass
`codex-review` requires, whose `APPROVE` closes the loop; for a Claude reviewer, a clean recheck
closes it. The **churn check** ends either loop early: a finding regressed twice, or new findings
outnumbering closed ones two rounds running, is a structural problem — stop, report, and re-plan
the unit rather than queue another fix round.
