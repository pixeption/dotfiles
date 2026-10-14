---
name: codex-review
description: >-
  Runs a grounded second-opinion review of a plan, design, PR or diff by a codex-family model: one review then rechecks under bees, a multi-round loop ending on APPROVE for ad-hoc reviews. Use when the user asks to "run codex", for a "codex review" or "codex sol review", to have codex review a plan/design/PR/diff, or for a second AI opinion before building. For implementation use codex-implementor.
---

# Codex review

A review loop with a **codex-family model** as a second opinion on a plan, a design or a diff.
**You are the lead; the reviewer is a helper.** It raises findings; you decide, apply them
yourself, and bring the result back. Verified against `opencode 1.18.31`, `codex-cli 0.155.0`,
default model `gpt-6.1-sol`.

## Channel

**OpenCode by default** (codex-implementor's `scripts/codex-round review`): `opencode run --agent review-discovery`
against one persistent `opencode serve`, or `--agent review-followup` under `--no-subagents`. The
edit tool is hard-denied, and `review-followup` also denies the task tool; Bash stays enabled, so
read-only shell use is instruction-enforced — the reviewer can run a suite or a `unity command` to
*check* a claim. The session is server-held with no TTL, which matters because applying findings
between rounds routinely outlasts the CLI's 30-minute cache. **Read
[`reference/opencode-channel.md`](reference/opencode-channel.md)
before the session's first round** — preflight, the fence, flags and files, failed rounds,
watching; this skill runs codex-implementor's scripts.

The **codex CLI** (`codex-round review` on `codex exec --sandbox read-only`) is the automatic
fallback when the server won't start. Exit 3 means codex is unavailable (no channel, or a usage
limit): bees logs `review: skipped, codex unavailable`, per bees `reference/review.md`.

## Run it

```bash
# round 1 — write the prompt to a file first ("Prompt shape")
~/.claude/skills/codex-implementor/scripts/codex-round review \
  -C <repo> -p "$T/r1-prompt.txt" -u <unit> -o "$W/review-<unit>-r1.txt"   # default openai/gpt-6.1-sol-fast / medium
# follow-up or recheck — same session, --no-subagents
~/.claude/skills/codex-implementor/scripts/codex-round review \
  -C <repo> -p "$T/r2-prompt.txt" -u <unit> -o "$W/review-<unit>-r2.txt" \
  -s "$(cat "$W/review-<unit>-r1.txt.session")" --no-subagents
# harder review: -e high on round 1, and the same -e on every later round
```

`-C <repo>` is the repo that holds the artifact and the sources it composes over; pass every
sibling repo the review reads as `--repo <abs path>` and name it in the prompt. The out-file holds
only the final answer — findings, suggestions, verdict.

## Under bees: one review, then rechecks

A code review is **one discovery round** (round 1 of the "Outside bees" loop) over the landed
commit, whatever its verdict. Its blocking findings go to the status file's Fixes list (bees
`reference/review.md`); the round is never followed by another round on the landed commit.

A **recheck** is a `--no-subagents` round on the fix branch's diff, built like a follow-up round
("Follow-up rounds"): it verifies the listed ids (Fixed / Partial / Open / Regressed) and reviews
the delta, and repeats on the next fix until clean. There is no holistic last round and no
`APPROVE` loop. The churn check still applies (bees `reference/review.md` "Rechecks and the end of
the loop").

`-u`, the out-file and the report are named by the reviewed item or the fix unit, never a parent
item: `review-<item|fix>-r<N>.txt`. `bees-brief` refuses a report path that already exists, so two
concurrent reviews never share a file.

## Planning reviews under bees

Two stages, each **one discovery round at `-e high`** and **at most one targeted recheck**
(`--no-subagents`, scoped to the ids) — never a third round:

- **Brief review**, for every plan, before the owner approves the brief: it checks consistency,
  dependencies and scores.
- **Plan review** of the expansion (bees `reference/review.md` "Once per unit"), skipped when the
  plan has three items or fewer (GATE rows not counted). It checks scores first — any item scored 8
  or 13 is a High finding, since such an item is split at planning (`plan` skill "Scoring") — then
  the expansion against the owner-approved brief (`plan` skill "Item fields by stage"): each Outcome
  and Right is proven by a Tests bullet, no bullet falls outside the brief, none contradicts a
  Wrong, and Today and Approach match the source they name.

A **Med** finding closed by pasting the reviewer's exact text is closed by inspection and needs no
recheck; a **High**, or any fix that departs from the reviewer's text, gets the recheck, whose
`Fixed` closes it. A High or Med still open after round 2: a brief's goes to the owner beside the
brief; a plan's is ruled by the orchestrator and logged.

The brief is frozen once approved: a plan-review finding against an Outcome, a Right or a Wrong is
dispositioned "back to owner", never applied. A finding against the expansion alone is applied or
dispositioned like any other.

## One session for the whole loop

All rounds on one artifact run in **one session** (`-s` / `-r`), so the reviewer keeps what it read
and every finding it raised, accepted or rejected. Start a **new** session only for a different
artifact, when the repo or feature scope changed far beyond the artifact's edits, or when the
session is anchored to a conclusion you can see is wrong. **Changing the effort or model is a new
session too**: a resume with a different `-e`/`-m` invalidates the prompt cache and re-reads the
whole history cold. For a different effort, start fresh with a round-1 prompt and hand it the
previous session's out-file to read.

**A review session continues further than an implementor's**, since a resumed round rereads
findings, not the repo: past the session threshold the hook refuses `-s`; start fresh and hand over
the last out-file.

Your follow-up need not restate old findings: reference them ("your round-2 F1–F4") and say what
you did with each — **applied**, **applied differently (how)**, or **rejected (why)**. A rejection
with a reason is a decision: the reviewer may push back once with new evidence, and you rule.

**Reuse established repository understanding.** Reopen only the specific source needed when it
changed since its read, was never read in this session, or the needed lines are no longer in
context. Cite `file:line` only from an unchanged file's read still in context, never from summaries
or memory, so grounding does not require redundant reads. A long session never warrants a broad rescan.
"Unchanged" means the repo's contents, uncommitted source included — a SHA alone does not show it.

**Short review state.** Every round's answer ends with the open findings in short form — id,
severity, status, the problem, the established facts it rests on, the required correction — and
settled findings as id + status only. No source excerpts. This survives a summarized history and is normally
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
  it to **confirm what is sound**, **not to rewrite** the artifact, and to end with the short
  review state.
- **Invite suggestions** as a separate, labelled, non-blocking list.
- **Ask for a terminal verdict** as the last line: `APPROVE` (no blocking findings remain) or
  `CHANGES_REQUIRED`, with `BEES: reviews=<unit>:<open-ids|->[;…]` directly above it — one entry
  per `-u` unit. `<open-ids>` lists only unresolved blocking findings (High/Med, or
  Critical/Major), `-` when none. `APPROVE` with an open id, `CHANGES_REQUIRED` with none, or a
  missing line is a malformed report.

## Outside bees

The ad-hoc loop, for a user asking for a codex review of a design, plan or diff. A follow-up
`APPROVE` advances to the final pass; only the final pass's `APPROVE` ends the loop.

### Shape of the loop

Three kinds of round, one session, no round cap — the loop ends on `APPROVE` from the final pass:

1. **Round 1 — discovery, broad.** The reviewer reads the whole artifact and the source it
   composes over. Sub-agents are allowed (breadth is wanted, and they keep the parent's context
   small). On a large artifact, give it explicit lenses — source compatibility,
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

### Follow-up rounds

Run one once every Open or Partial finding is dispositioned; never when neither the artifact nor a
disposition changed. **You supply the delta**: the artifact's diff since the last reviewed commit
(`git diff <sha>.. -- <artifact>`) or the changed section names — or `no artifact delta` when
findings were only rejected — with each disposition, the repo SHA, and whether the repo moved.
For an uncommitted artifact, snapshot it after each round (`cp <artifact> "$W/<unit>-reviewed.md"`)
and send `diff -u` against the snapshot: without a diff the reviewer rereads the whole artifact.

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

### Final pass

After round 1 with nothing left Open/Partial, or after a follow-up `APPROVE`, run one holistic pass
in the same session, `--no-subagents`, with `templates/final-pass-prompt.txt` as the prompt. It
reads the artifact top to bottom against the repository and does **not** assume earlier findings
or verdicts were right: prior source facts may be reused, prior conclusions may not. Fill in the
repo SHA and whether it moved since the session's last round. Its findings
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
want no framing. Run it as
`codex="$("$HOME/.claude/skills/codex-implementor/scripts/resolve-codex")" && "$codex" exec review < /dev/null`
(`< /dev/null`: codex appends stdin and hangs on an open one).
