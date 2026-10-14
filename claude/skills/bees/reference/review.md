# Review policy

Read before briefing any reviewer or choosing one.

## Pairing

The reviewer is codex, so no model checks its own habits:

| implementor | reviewer | slot |
|---|---|---|
| Claude (`bee-opus-*`) | codex via `codex-review` (`codex-round review -m openai/gpt-6.1-sol-fast -e medium`, CLI fallback) | one (background) |
| codex (fallback on a Claude usage limit) | a separate codex `codex-review` session, logged as a same-vendor exception | one |

When codex is unavailable (both channels down or a usage limit), the review is skipped and logged
`review: skipped, codex unavailable`.

## Once per unit

| What | Review |
|---|---|
| Every expanded plan | one discovery round in plan-review mode, over all its items |
| Every item, a production diff of five lines or fewer included | one codex review of its landed commit, in the background (SKILL.md "Status and acceptance"); its findings become Fixes lines |
| Every fix unit | fix → recheck before it lands (SKILL.md "Fixes"), skipped and logged only when codex is unavailable |

Code reviews check the change against the item's brief and Tests. The reviewed SHA is the landed
SHA, and its verdict is the item's `review:` log line. A recheck is a fresh session pointed at the review
file whenever the first passed its review line (`codex-review` "One session for the whole loop").

## The review

- A reviewer is fresh, read-only, holds no resource, never edits, and is never the implementor of
  the unit. Every Claude review brief carries the reviewer standing rules
  (`reference/briefs.md`).
- It covers a **quiescent tree** — an item's is the detached worktree at its landed SHA — and
  states the commit reviewed; never while another agent edits the same domain. Input: changed files, surrounding code, acceptance criteria,
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
codex recheck runs `codex-round review --no-subagents`.

Under bees, an ordinary item gets one landed-commit discovery review; its findings become Fixes. A
fix unit gets targeted rechecks until clean, with no holistic final pass. Keep the churn check: a
finding regressed twice, or new findings outnumbering closed ones two rounds running, stops the loop
for a structural decision.
