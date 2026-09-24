---
name: codex-review
description: >-
  Run a second-opinion code/design review with a codex-family model (default gpt-6-sol) — grounded against the actual repo source, as a multi-round conversation you steer. DEFAULT channel is OpenCode (`opencode-review`): a persistent, human-attachable session whose edit tool is hard-denied but whose Bash read-only discipline is instruction-enforced with no 30-min resume cliff (findings-application between rounds routinely exceeds it). FALLBACK is the `codex` CLI (`codex-review`, `codex exec --sandbox read-only`). Use whenever the user asks to "run codex", get a "codex review" / "codex sol review", have codex review a plan/design/PR/diff, or a second AI opinion before building. Covers both channels, session reuse across rounds, the review prompt shape, the verdict that ends the loop, and how to read the findings back.
---

# Codex review

A review loop with a **codex-family model** as a second opinion on a plan, a design or a diff.
**You are the lead; the reviewer is a helper.** It raises findings; you decide, apply them
yourself, and bring the result back. Verified against `opencode 1.18.31`, `codex-cli 0.155.0`,
default model `gpt-6-sol`.

Two channels to the **same models**; the method (prompt shape, rounds, verdict, reading findings
back) is identical. Only the harness differs.

| | **Default — OpenCode** (`opencode-review`) | **Fallback — codex CLI** (`codex-review`) |
|---|---|---|
| how | `opencode run --agent review-discovery` against one persistent `opencode serve` | `codex exec` background process |
| read-only | the edit tool is hard-denied (verified: refuses even when told to edit); `review-followup` also denies the task tool. Bash stays enabled by the shared config, so read-only shell use is instruction-enforced, not sandboxed — it can run a suite or `unity command` to *check* a claim | codex `--sandbox read-only` |
| session | server-held, **no TTL** — resume any time | prompt cache **30-min TTL**; resume within it or start cold |
| live view | owner attaches to the session (`opencode-sessions --attach`) | read-only tail of the JSONL `.log` |
| use when | the default | OpenCode server won't start |

**Prefer the default.** A review loop spends minutes-to-hours *between* rounds while you apply
findings — routinely past the CLI's 30-minute cache cliff. OpenCode's session has no cliff.

## Run it — OpenCode

`scripts/opencode-review` runs codex-implementor's `opencode-preflight` before any round file is
written (the server is up, carries the fence, allows the plan's repos outside `-C`, and lists `-m`
in `/config/providers`; an idle server is restarted to fix a stale config or model catalogue, a
busy one never), runs one round via `--dir` with `--agent review-discovery --auto` by default or
`--agent review-followup --auto` under `--no-subagents`, and records the final answer, session id
and usage.

```bash
# round 1 — write the prompt to a file first (see "Prompt shape")
~/.claude/skills/codex-review/scripts/opencode-review \
  -C <repo> -p "$T/r1-prompt.txt" -u <unit> -o docs/plans/<plan>.work/   # → review-<unit>-r1.txt; default openai/gpt-6-sol / medium
# follow-up — same session, any time; --no-subagents = the `review-followup` agent, which denies
# the task tool as well as edits (the wrapper refuses if the running server has not loaded it)
~/.claude/skills/codex-review/scripts/opencode-review \
    -C <repo> -p "$T/r2-prompt.txt" -u <unit> -o docs/plans/<plan>.work/ -s "$(cat "$W/review-<unit>-r1.txt.session")" --no-subagents
# final pass — same session, same flag
~/.claude/skills/codex-review/scripts/opencode-review \
    -C <repo> -p "$T/final-prompt.txt" -u <unit> -o docs/plans/<plan>.work/ -s "$(cat "$W/review-<unit>-r1.txt.session")" --no-subagents
# harder review: -e high
```

- Run via the **Bash tool with `run_in_background: true`**; reviews take minutes. `$T` (prompts)
  is your scratchpad, never `/tmp`. Every round belongs to a plan unit: `-u <unit>` (repeatable)
  and `-o docs/plans/<plan>.work/` (`$W` above), which the wrapper turns into
  `review-<unit>[+<unit>…]-r<N>.txt`; without them it fails before writing. The out-files outlive
  the session, and the wrapper's exit refreshes the plan's `Status` column (bees skill §9).
- The out-file holds **only the final answer** — the last message's text (findings, suggestions,
  verdict); earlier steps' narration stays in the `.log`. The round runs through codex-implementor's
  `opencode-round`, so a permission ask is rejected and the run stopped as for an implementor. A
  failed round (that ask, an `error` event, a non-zero exit, no answer, an unfinished final step, or
  an answer not ending in `APPROVE`/`CHANGES_REQUIRED`) gets an out-file starting `Blocked: <reason>`
  and ending `BEES: results=<unit>:blocked:-`, which the board shows as `review blocked` and never
  counts as a verdict, and exit 1. The `.log` is a
  liveness aid only — never read it into context. Under the ChatGPT oauth credential `.usage`
  `cost` reads 0; report tokens.
- **Auto-compaction (OpenCode channel only).** The server compacts a session on its own past the
  ~270k point (the same figure round 1's sub-agent breadth is meant to stay under, above); the
  next `context_tokens` reading afterward is real but small. `.usage` then also carries a
  `compacted` object and the wrapper's final stderr line says `COMPACTED` — treat everything the
  reviewer says about source it read before that point as a summary, not a verified re-read, and
  reopen the file before trusting an exact citation from it. See `extract-opencode-usage`
  (codex-implementor skill) for the underlying event.
- **Usage limit**: check `~/.claude/skills/bees/scripts/codex-usage` first (exit 0 = `ROUTE: codex
  ok`). A STALE reading is not a reading — it once said "ok" while the real window was at 100% and
  three reviews came back truncated or empty (429) — so the tool prints `ROUTE: unknown` and exits
  2 for it: spend one cheap codex turn to refresh the snapshot and re-run. Out of window (exit 1)
  → the review goes to `bee-reviewer`.
- **Watching**: one server serves every repo, but the TUI's `/sessions` shows a single directory
  (the server's start directory unless `--dir` is passed — your shell's cwd does not matter) and
  never shows child sessions. `~/.claude/skills/codex-implementor/scripts/opencode-sessions`
  lists across repos; `--attach` picks and attaches. The wrapper prints the exact attach command.
- `-C <repo>` is the repo the review reads. Point it at the repo that holds the artifact and the
  sources it composes over; name sibling repos in the prompt by absolute path.

## Run it — codex CLI fallback

Same review, codex's harness (`--sandbox read-only`, 30-min TTL). `scripts/codex-review`
hardcodes `< /dev/null`, reads the prompt from a file, writes only the final answer, records the
session id, and records context size (`<out-file>.usage`, via `extract-codex-cli-usage` from the
session's rollout file under `~/.codex/sessions`: the last `token_count` event's
`last_token_usage` — never `total_token_usage`, a cumulative sum across the whole session, not
the current context).

```bash
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r1-prompt.txt" -u <unit> -o docs/plans/<plan>.work/ -e medium
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r2-prompt.txt" -u <unit> -o docs/plans/<plan>.work/ -r "$(cat "$W/review-<unit>-r1.txt.session")"
```

**The stdin trap**: `codex exec` (and `resume`) appends stdin as a `<stdin>` block even with a
prompt argument; backgrounded, it inherits an fd that never EOFs and **hangs forever** at
`Reading additional input from stdin...`. Never remove `< /dev/null`. Hung or working? after
~60–90 s the `.log` growing = working; stuck on that line = hung → `pkill -f "codex exec"`, resume
by **explicit id**, never `--last`.

## Shape of the loop

Three kinds of round, one session, no round cap — the loop ends on `APPROVE` from the final pass:

1. **Round 1 — discovery, broad.** The reviewer reads the whole artifact and the source it
   composes over. Sub-agents are allowed here (breadth is wanted and they keep the parent under
   the ~270k compaction point). On a large artifact, give the single round-1 session explicit
   review lenses (source compatibility, sequencing/dependencies, testability, completeness) and
   let its sub-agents divide that breadth — most of what late rounds find is reachable in round 1
   with a narrower lens. Independent parallel reviews are separate loops; never merge their
   session histories or id sequences into this one.
2. **Follow-up rounds — targeted, delta-only, no sub-agents** (below). Run one after any round
   returns `CHANGES_REQUIRED`, once you have dispositioned every Open or Partial finding.
3. **Final pass — holistic** (below). Always the last word; work proceeds or is accepted on its
   `APPROVE`.

A healthy loop is round 1, one follow-up, final pass. Two things keep it short:

- **Ask for the fix text, not a description.** The reviewer is read-only against the repo but can
  emit the exact replacement paragraph or a unified diff for the artifact. Paste it. "Applied
  differently" is the main source of `Partial` verdicts and extra rounds.
- **Fix everything Open in one batch**, run cheap gates (anchors resolve, cited files and symbols
  exist, every step names a real test — a script or a Haiku scout, not a sol round), then
  resubmit. Never resubmit after a subset.

**Churn check, instead of a cap.** After each follow-up: a finding that regressed twice, or new
findings outnumbering closed ones two rounds running, means the artifact has a structural problem
patches will not fix. Stop the loop and rewrite the section before resubmitting. Otherwise keep
going until `APPROVE`.

## One session for the whole loop

All rounds on one artifact run in **one session** (`-s` / `-r`). The reviewer keeps what it read
and every finding it raised, you accepted or rejected, so later rounds neither start cold nor
re-raise settled points. Start a **new** session only for a different artifact, or if the repo
or the feature scope changed under it far beyond the artifact's edits, or if the session is anchored
to a conclusion you can see is wrong. **Changing the effort or model is a new session too.** A
resume with a different `-e`/`-m` invalidates the prompt cache, so the whole history is re-read
cold at full price — the one thing resuming was meant to avoid. Keep the effort you started with
for every round; if you want a different effort, start a fresh session with a round-1 prompt and
hand it the previous session's out-file as context to read. Your follow-up need not restate old findings: reference
them ("your round-2 F1–F4") and say what you did with each — **applied**, **applied differently
(how)**, or **rejected (why)**. A rejection with a reason is a decision, not an invitation to
re-argue; the reviewer may push back once with new evidence, and you rule.

**Reuse established repository understanding; do not re-read unchanged source by default.** The
reviewer reopens source only for the specific file, symbol or line range it needs: an exact
implementation detail it cannot confidently recover, a new repository assumption the changed
artifact introduces, the repo having changed since the previous round, or a detail compaction removed
that a reliable judgment needs. Compaction by itself is not a reason to re-read the repo, and
never a reason to launch a broad rescan. **Always reopen the source before giving an exact
`file:line` citation** — never cite a line from memory, in any round.

**Compact review state.** Every round's answer ends with the open findings in compact form —
id, severity, status, the problem, the established repository facts it rests on, the required
correction — and settled findings as id + status only. No source excerpts. This is what survives
compaction, and it is normally enough to verify an artifact-only correction without re-reading source.

```text
F24 — High — Open
Problem: STEP-02 invalidates `player_unit` before the atomic avatar migration.
Established facts: `_playerPrefab` must be cleared before `player_unit` is repointed or deleted.
Required correction: put those operations in the documented atomic ordering.
```

## Prompt shape — grounded, bounded, findings-only

- **Point at the artifact and the real source it composes over** — the plan/PR/diff (a commit
  range, `git diff A..B`), plus the files/classes to verify claims against. It runs in the repo
  and can read them, run read-only commands, and (in place, read-only) run a suite or a `unity
  command` query to check a claim — invite that when the acceptance criteria are behavioural.
- **Scope it** — one feature/section/diff at a time. "The whole artifact" always means the feature
  under review and the context it composes over, never the entire repository.
- **Ask for a findings list**: stable id (F1, F2, …, continuing across rounds), **severity**
  (High/Med/Low — or Critical/Major/Minor/Nit for a diff under bees), the claim, **why, citing
  file:line**, the **fix as exact replacement text or a diff** for the artifact. Ask it to
  **confirm what is sound**, **not to rewrite** the artifact, and to end with the compact review
  state.
- **Invite suggestions** as a separate, labelled, non-blocking list.
- **Ask for a terminal verdict** as the last line: `APPROVE` (no blocking High/Med findings remain)
  or `CHANGES_REQUIRED`, with `BEES: reviews=<unit>:<open-ids|->[;…]` on the line directly above
  it — one entry per `-u` unit. `<open-ids>` contains only unresolved Critical/Major (High/Med)
  findings, `-` when none; Minor, Nit and suggestions stay in prose and never appear in the list.
  `APPROVE` with an open id or `CHANGES_REQUIRED` with none is a malformed report, and so is a
  missing line. A follow-up `APPROVE` advances to the final pass; only the final pass's `APPROVE`
  ends the loop.

## Follow-up rounds: targeted, delta-only

Run a follow-up once you have dispositioned every Open or Partial finding; do not re-run when
neither the artifact nor any disposition changed. **You supply the delta**: the artifact's diff
since the last reviewed commit (`git diff <sha>.. -- <artifact>`) or the changed section names —
or an explicit `no artifact delta` when findings were only rejected — with each finding's
disposition, the repo SHA, and whether the repo moved (normally it did not — only the artifact
changes between rounds; if it did, list what). The reviewer does not rediscover this. Run it
with `--no-subagents` (OpenCode) so the harness denies the task tool.

The reviewer does **two sequential jobs itself, in the existing session, spawning nothing**:

1. **Verify each Open or Partial finding** against the delta, its stored rationale and the
   established repository facts — classified **Fixed / Partial / Open / Regressed**. Settled
   findings stay settled unless the new changes invalidate why; a lead-rejected finding is not
   re-argued without new repository evidence.
2. **Delta-impact review**: new findings introduced, exposed, or made relevant by the changes —
   contradictions the fixes introduced, regressions, new repository assumptions, dependencies of
   the changed sections. Follow dependencies from changed sections when necessary; **no general
   audit of unchanged areas**. IDs continue the sequence.

Never authorize sub-agents in a follow-up — the harness denies them. An unusually large
independent audit is a separate round-1 session; compaction never permits a replacement
repository analysis inside the follow-up session.

Follow-up prompt template:

```text
Continue in the existing review session. Repo at <sha>, unchanged since round <n>
[or: changed — <what>]. The artifact changed as follows: <diff or section list>.
Perform this round directly, without spawning sub-agents.
1. Verify each listed Open/Partial finding against the updated artifact: Fixed, Partial, Open or Regressed.
2. Review the artifact delta and affected dependencies for new problems introduced, exposed or
   made relevant by these changes. Do not perform a fresh whole-artifact audit in this round.
Reuse established repository facts; do not re-read unchanged source or rescan the repository by
default. Reopen only the specific source needed to verify an uncertain implementation fact or to
support a new finding, and always before an exact file:line citation.
For each finding give the exact replacement text or a diff for the artifact.
Continue finding IDs from F<N>. End with the output contract: the BEES: reviews= line, then
APPROVE or CHANGES_REQUIRED as the last line.
```

Follow-up output contract (ask for it verbatim):

```text
## Fix verification
- F24 — Fixed — why, from the updated artifact and established facts
- F26 — Partial — what remains and the required correction
## New findings
### F27 — Medium
Claim / Evidence / Impact / Fix (exact text)
(or: No new findings introduced or exposed by the current changes.)
## Source revisited
- `File.cs:100-130` — reopened because <reason>   (or: None. Existing repository facts sufficed.)
## Review state
<open findings only, compact form; settled ones as id + status>
BEES: reviews=<unit>:<open-ids|->[;…]
CHANGES_REQUIRED | APPROVE
```

## Final pass: holistic, before accepting or implementing

After round 1 (when nothing is left Open/Partial) or after a follow-up returns `APPROVE`, run one
holistic pass in the same session. It is the safety net: it reads the current artifact top to
bottom against the repository and does **not** assume previous findings or verdicts were correct.
Prior *source facts* may be reused; prior *conclusions* may not, and any fact a verdict rests on
gets reopened. No sub-agents. Findings from this pass are ordinary `CHANGES_REQUIRED`: fix, one
targeted follow-up, then this pass again — it always has the last word. A holistic pass that
finds a lot means the follow-ups were too narrow or the fixes drifted from the reviewer's text;
fix the section structurally rather than adding rounds. A fresh session only for the reasons in
"One session for the whole loop".

```text
Read the current artifact top to bottom against the current repository and determine whether it
is coherent, complete, correctly sequenced, compatible with the actual source, testable and ready
to implement or accept, as appropriate. Do not assume previous approvals or findings were correct. Do not spawn
sub-agents. Reuse existing repository understanding, but reopen source wherever exact
verification is needed. Raise any remaining or newly discovered blocking findings with continuing
stable IDs, severity, claim, why with a freshly reopened file:line citation, and exact fix text.
Confirm what is sound, list non-blocking suggestions separately, and end with the compact review
state, then `BEES: reviews=<unit>:<open-ids|->[;…]`, then APPROVE or CHANGES_REQUIRED.
```

## Reading the findings back

The out-file is only the final message — read it directly. Triage as lead: apply what you agree
with (paste the reviewer's fix text), apply differently or reject with a reason, treat suggestions
as optional. Under bees, a recheck returns `Fixed / Partial / Open / Regressed` id lists scoped to
the listed findings plus anything the fix introduced; a clean review is valid.

## Alternative: `codex exec review`

Reviews the repository's uncommitted changes as a diff, without a prompt you write. Use this
skill's prompt flow for a **document or design**; `codex exec review` for a **raw diff** when you
want no framing. `< /dev/null` applies to both when backgrounded.
