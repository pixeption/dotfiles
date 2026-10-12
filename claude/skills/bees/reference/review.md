# Review policy

Read before briefing any reviewer or choosing one.

## Pairing

The reviewer is the **other vendor** from the implementor, so no model checks its own habits:

| implementor | reviewer | slot |
|---|---|---|
| Claude (`bee-opus-*`, `bee-sonnet-medium`) | codex via `codex-review` (`opencode-review -m openai/gpt-6.1-sol -e medium`, CLI fallback) | one (background) |
| codex | `bee-reviewer` | one |

When a codex review round fails on a usage limit (429, limit reached), the review goes to the Claude reviewer for its score, and a
log line says so.

## Once per unit

| What | Review |
|---|---|
| Every expanded plan | one discovery round in plan-review mode, over all its items |
| Every item | one review after its build, on its lane before it lands, then fix → recheck under `codex-review`'s contract |
| A fix that applies the reviewer's exact fixes | orchestrator inspection ("Rechecks and the end of the loop") |
| A production diff ≤ ~5 lines | orchestrator inspection (same) |

Code reviews check the change against the item's ACs. An item's acceptance records its filter
and the review verdict for the reviewed lane SHA. A recheck is a fresh session pointed at the review
file whenever the first passed 100k (`budgets.md`).

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
- An Integration test (AssetDatabase, prefabs, scenes, rendering, Play Mode) that a plain test
  could replace is a finding, its fix the plain test, because Integration tests dominate suite time.
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
- a unit whose production diff is about five lines or fewer.

Log either as `review: orchestrator inspection`; a clean inspection closes the loop. Anything
else, including a fix that departs from the reviewer's fix text, goes to the reviewer.

There is no round cap. For codex, a clean recheck advances to the holistic final pass
`codex-review` requires, whose `APPROVE` closes the loop; for a Claude reviewer, a clean recheck
closes it. The **churn check** ends either loop early: a finding regressed twice, or new findings
outnumbering closed ones two rounds running, is a structural problem — stop, report, and re-plan
the unit rather than queue another fix round.
