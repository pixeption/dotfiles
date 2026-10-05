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

**Cadence** is what the owner chose in setup: per unit, or one diff review of the whole plan at
the end. For the end-of-plan review, the reviewer is chosen by the vendor that implemented **most
points**, and a Claude reviewer is `bee-reviewer-high` when the plan holds any unit routed at
8–13.

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
else, including a fix that departs from the given text, goes to the reviewer — also when your own
decision replaced that text, since nobody has checked the decision's code.

There is no round cap. For codex, a clean recheck advances to the holistic final pass
`codex-review` requires, whose `APPROVE` closes the loop; for a Claude reviewer, a clean recheck
closes it. The **churn check** ends either loop early: a finding regressed twice, or new findings
outnumbering closed ones two rounds running, is a structural problem — stop, report, and re-plan
the unit rather than queue another fix round.
