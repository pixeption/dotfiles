---
name: codex-review
description: >-
  Runs a grounded, multi-round second-opinion review of a plan, design, PR or diff by a codex-family model, ending on an APPROVE verdict. Use when the user asks to "run codex", for a "codex review" or "codex sol review", to have codex review a plan/design/PR/diff, or for a second AI opinion before building. For implementation use codex-implementor.
---

# Codex review

A review loop with a **codex-family model** as a second opinion on a plan, a design or a diff.
**You are the lead; the reviewer is a helper.** It raises findings; you decide, apply them
yourself, and bring the result back. Verified against `opencode 1.18.31`, `codex-cli 0.155.0`,
default model `gpt-6.1-sol`.

## Channel

**OpenCode by default** (`scripts/opencode-review`): `opencode run --agent review-discovery`
against one persistent `opencode serve`, or `--agent review-followup` under `--no-subagents`. The
edit tool is hard-denied, and `review-followup` also denies the task tool; Bash stays enabled, so
read-only shell use is instruction-enforced — the reviewer can run a suite or a `unity command` to
*check* a claim. The session is server-held with no TTL, which matters because applying findings
between rounds routinely outlasts the CLI's 30-minute cache. **Read
codex-implementor's [`reference/opencode-channel.md`](../codex-implementor/reference/opencode-channel.md)
before the session's first round** — preflight, the fence, flags and files, failed rounds,
compaction, watching, usage gating; this skill runs that skill's scripts.

The **codex CLI** (`scripts/codex-review`, `codex exec --sandbox read-only`) is the fallback, only
when the server won't start: codex-implementor's
[`reference/codex-cli.md`](../codex-implementor/reference/codex-cli.md).

Out of usage (`codex-usage` exit 1) → the review goes to `bee-reviewer` (scores 1–5) or
`bee-reviewer-high` (8–13), per bees `reference/review.md`.

## Run it

```bash
# round 1 — write the prompt to a file first ("Prompt shape")
~/.claude/skills/codex-review/scripts/opencode-review \
  -C <repo> -p "$T/r1-prompt.txt" -u <unit> -o "$W/review-<unit>-r1.txt"   # default openai/gpt-6.1-sol / medium
# follow-up and final pass — same session, --no-subagents
~/.claude/skills/codex-review/scripts/opencode-review \
  -C <repo> -p "$T/r2-prompt.txt" -u <unit> -o "$W/review-<unit>-r2.txt" \
  -s "$(cat "$W/review-<unit>-r1.txt.session")" --no-subagents
# harder review: -e high on round 1, and the same -e on every later round
```

`-C <repo>` is the repo that holds the artifact and the sources it composes over; pass every
sibling repo the review reads as `--repo <abs path>` and name it in the prompt. The out-file holds
only the final answer — findings, suggestions, verdict.

## Shape of the loop

Three kinds of round, one session, no round cap — the loop ends on `APPROVE` from the final pass:

1. **Round 1 — discovery, broad.** The reviewer reads the whole artifact and the source it
   composes over. Sub-agents are allowed (breadth is wanted, and they keep the parent under the
   ~270k compaction point). On a large artifact, give it explicit lenses — source compatibility,
   sequencing/dependencies, testability, completeness — and let its sub-agents divide them.
   Independent parallel reviews are separate loops; never merge their histories or id sequences.
2. **Follow-up rounds — targeted, delta-only, no sub-agents.** One after any `CHANGES_REQUIRED`,
   once you have dispositioned every Open or Partial finding.
3. **Final pass — holistic.** Always the last word; work proceeds or is accepted on its `APPROVE`.

A healthy loop is round 1, one follow-up, final pass. Two things keep it short:

- **Ask for the fix text, not a description.** The reviewer can emit the exact replacement
  paragraph or a unified diff. Paste it: "applied differently" is the main source of `Partial`
  verdicts and extra rounds.
- **Fix everything Open in one batch**, run cheap gates (anchors resolve, cited files and symbols
  exist, every step names a real test — a script or a Haiku scout, not a sol round), then
  resubmit. Never resubmit after a subset.

**Churn check, instead of a cap.** After each follow-up: a finding that regressed twice, or new
findings outnumbering closed ones two rounds running, means a structural problem patches will not
fix. Stop and rewrite the section before resubmitting.

## One session for the whole loop

All rounds on one artifact run in **one session** (`-s` / `-r`), so the reviewer keeps what it read
and every finding it raised, accepted or rejected. Start a **new** session only for a different
artifact, when the repo or feature scope changed far beyond the artifact's edits, or when the
session is anchored to a conclusion you can see is wrong. **Changing the effort or model is a new
session too**: a resume with a different `-e`/`-m` invalidates the prompt cache and re-reads the
whole history cold. For a different effort, start fresh with a round-1 prompt and hand it the
previous session's out-file to read.

Your follow-up need not restate old findings: reference them ("your round-2 F1–F4") and say what
you did with each — **applied**, **applied differently (how)**, or **rejected (why)**. A rejection
with a reason is a decision: the reviewer may push back once with new evidence, and you rule.

**Reuse established repository understanding.** The reviewer reopens source only for the specific
file, symbol or range it needs: a detail it cannot confidently recover, a new assumption the
changed artifact introduces, a repo change since the last round, or a detail compaction removed.
Compaction alone is never a reason for a broad rescan. **Always reopen the source before an exact
`file:line` citation** — never cite from memory.

**Compact review state.** Every round's answer ends with the open findings in compact form — id,
severity, status, the problem, the established facts it rests on, the required correction — and
settled findings as id + status only. No source excerpts. This survives compaction and is normally
enough to verify an artifact-only correction without re-reading source.

```text
F24 — High — Open
Problem: STEP-02 invalidates `player_unit` before the atomic avatar migration.
Established facts: `_playerPrefab` must be cleared before `player_unit` is repointed or deleted.
Required correction: put those operations in the documented atomic ordering.
```

## Prompt shape — grounded, bounded, findings-only

- **Point at the artifact and the real source it composes over** — the plan/PR/diff (a commit
  range, `git diff A..B`) plus the files/classes to verify claims against. Invite a read-only
  suite or `unity command` run when the acceptance criteria are behavioural.
- **Scope it** — one feature/section/diff at a time; "the whole artifact" means the feature and the
  context it composes over, never the entire repository.
- **Ask for a findings list**: stable id (F1, F2, …, continuing across rounds); **severity** — High
  / Med / Low for a plan, design or document, Critical / Major / Minor / Nit for a diff under
  bees; the claim; **why, citing file:line**; the **fix as exact replacement text or a diff**. Ask
  it to **confirm what is sound**, **not to rewrite** the artifact, and to end with the compact
  review state.
- **Invite suggestions** as a separate, labelled, non-blocking list.
- **Ask for a terminal verdict** as the last line: `APPROVE` (no blocking findings remain) or
  `CHANGES_REQUIRED`, with `BEES: reviews=<unit>:<open-ids|->[;…]` directly above it — one entry
  per `-u` unit. `<open-ids>` lists only unresolved blocking findings (High/Med, or
  Critical/Major), `-` when none. `APPROVE` with an open id, `CHANGES_REQUIRED` with none, or a
  missing line is a malformed report. A follow-up `APPROVE` advances to the final pass; only the
  final pass's `APPROVE` ends the loop.

## Follow-up rounds

Run one once every Open or Partial finding is dispositioned; never when neither the artifact nor a
disposition changed. **You supply the delta**: the artifact's diff since the last reviewed commit
(`git diff <sha>.. -- <artifact>`) or the changed section names — or `no artifact delta` when
findings were only rejected — with each disposition, the repo SHA, and whether the repo moved.

The reviewer does two jobs in the existing session, spawning nothing: **verify** each Open or
Partial finding (Fixed / Partial / Open / Regressed; settled findings stay settled unless the
change invalidates why), and **review the delta** and its dependencies for what the fixes
introduced or exposed — no general audit of unchanged areas. An unusually large independent audit
is a separate round-1 session.

Build the prompt from the two templates — the prompt, then the output contract it asks for
verbatim — and fill every `<…>`:

```sh
cat ~/.claude/skills/codex-review/templates/followup-prompt.txt \
    ~/.claude/skills/codex-review/templates/followup-output-contract.txt > "$T/r<N>-prompt.txt"
```

## Final pass

After round 1 with nothing left Open/Partial, or after a follow-up `APPROVE`, run one holistic pass
in the same session, `--no-subagents`, with `templates/final-pass-prompt.txt` as the prompt. It
reads the artifact top to bottom against the repository and does **not** assume earlier findings
or verdicts were right: prior source facts may be reused, prior conclusions may not. Its findings
are ordinary `CHANGES_REQUIRED` — fix, one targeted follow-up, then this pass again. A final pass
that finds a lot means the follow-ups were too narrow or the fixes drifted from the reviewer's
text: fix the section structurally rather than adding rounds.

## Reading the findings back

Read the out-file directly. Triage as lead: apply what you agree with (paste the reviewer's fix
text), apply differently or reject with a reason, treat suggestions as optional. Under bees, a
recheck returns `Fixed / Partial / Open / Regressed` id lists scoped to the listed findings plus
anything the fix introduced; a clean review is valid.

## Alternative: `codex exec review`

Reviews the repository's uncommitted changes as a diff, without a prompt you write. Use this
skill's prompt flow for a **document or design**, `codex exec review` for a **raw diff** when you
want no framing. Run it with `< /dev/null` when backgrounded (codex-implementor
`reference/codex-cli.md`, the stdin trap).
