---
name: codex-implementor
description: >-
  Delegates a bounded, well-specified implementation unit to a codex-family model over OpenCode (codex CLI fallback), in a worktree or in place with a live Unity editor, as reviewed rounds. Use when the user asks to have codex implement, build or write something, or to delegate a unit to codex. For a read-only review use codex-review.
---

# Codex implementor

Delegate a **bounded, well-specified** unit to a **codex-family model**. It has the same reach as
a Claude sub-agent: it edits, compiles, runs suites and drives the live Unity editor through the
`unity` CLI. **You are the lead; it executes and brings evidence.** Accept on a suite count or a
real run, never on its claim. Verified against `opencode 1.18.31`, `codex-cli 0.155.0`.

## Channel

**OpenCode by default** (`scripts/opencode-implement`): a server-held session that survives idle
gaps, that the owner can attach to and steer, in a worktree or in place. **Read
[`reference/opencode-channel.md`](reference/opencode-channel.md) before the session's first
round** — preflight, the fence, flags and files, failed rounds, compaction, watching, usage
gating. The **codex CLI** (`scripts/codex-implement`) is the fallback, only when the server won't
start or the unit must run under an OS sandbox: [`reference/codex-cli.md`](reference/codex-cli.md).

**Resume or fresh** (bees "Rules", the session budget): read `context_tokens` from `.usage`. Below
120k resume freely; 120–200k only for a short recheck in the same files; at 200k, or for **any
other directory**, start a new session — a session is pinned to the directory it was created in,
and a brief for another repo trips the fence instead of running.

## Models and effort

| model | id (opencode / codex) | default effort |
|---|---|---|
| sol **(default)** | `openai/gpt-6.1-sol` / `gpt-6.1-sol` | **medium** |
| luna | `openai/gpt-6-luna` / `gpt-6-luna` | max |

Default to sol at medium; raise `-e` only when capability changes the outcome. Effort → codex `-e`
/ opencode `--variant`: `low|medium|high|xhigh|max` (codex also `ultra`).

## Worktree or in place — pick by what the unit must verify

| unit needs | run it | verify |
|---|---|---|
| a diff only (pure C#, docs, data, a tool with its own tests) | **worktree**: `git worktree add -b oc/<unit> "$T/wt-<unit>" HEAD` | you compile/test the diff on the real project afterward — a worktree has no `Library`, so Unity cannot run there |
| Unity: compile, a suite, the live editor, a prefab/scene, a screenshot | **in place**: `-C ~/code/<project>` | the implementor verifies itself in the editor and reports counts; you re-run once |

An in-place unit **holds that Unity project** like a Claude agent would: one driver per compile
domain (nono4u/Game compiles game-core and game-build sources through `file:` packages, so those
three are one domain). Before launching, check nothing else drives the domain — another agent's
uncommitted edits surface as a Safe-Mode compile error in your run. Edits land on the real branch;
the fence and the brief carry the git discipline.

## Run it

```bash
# in place (editor-drive) — the common Unity case
~/.claude/skills/codex-implementor/scripts/opencode-implement \
  -C ~/code/game-core -p "$T/brief.md" -u <unit> -o "$W/impl-<unit>-r1.txt" --title <unit>
# worktree (pure diff)
git worktree add -b oc/<unit> "$T/wt-<unit>" HEAD
~/.claude/skills/codex-implementor/scripts/opencode-implement -C "$T/wt-<unit>" -p "$T/brief.md" -u <unit> -o "$W/impl-<unit>-r1.txt"
# follow-up round: same session, same -C, context < 200k
~/.claude/skills/codex-implementor/scripts/opencode-implement -C <same dir> -p "$T/r2.md" -u <unit> \
  -o "$W/impl-<unit>-r2.txt" -s "$(cat "$W/impl-<unit>-r1.txt.session")"
# harder unit: add -e high
```

Then read the out-file (the report ending in its `BEES:` line) and the change (`git -C <dir> diff`,
or the commits it reports).

## What the session loads, and what it doesn't

A **new** session reads `~/.claude/CLAUDE.md`, the directory's root `CLAUDE.md` and the nearer ones
on the path to what it edits. It opens a skill only when the brief names it. A resumed session has
them already. Everything it reads stays in its context for every later turn, so the brief gives it
**passages, not documents**:

- the **plan section pasted in**, never "read section X" — the read tool has no section mode, so
  the whole plan is read;
- a spec or doc contract **quoted, or cited as `path:start-end`**, and task files with line ranges
  where the change is local;
- the **`CLAUDE.md` of the one sibling package** the unit edits
  (`../game-core/Packages/<package>/CLAUDE.md`) — nothing under the directory points there;
- for an in-place unit, the **editor card** ([`templates/editor-card.md`](templates/editor-card.md)):
  the unity-cli helpers by absolute path and their rules, in place of the whole `unity-cli` skill.

## The brief

The implementor knows only the brief and the repo. Start from
[`templates/brief.md`](templates/brief.md) (`cat` it into `$T/brief.md` and fill every `<…>`):
objective and acceptance, context, where it runs, the editor-drive contract (`cat` the editor
card into it), the commit gate, owner WIP,
the blocker cap, style, and the return format with its exact last line. Under bees, follow bees
"Briefing an agent" too.

Cite the contract file, never paraphrase values from memory. Quote a count only with the command
that produced it. Never send transcripts or source dumps.

## Accept on evidence, then a review

```text
- [ ] Read the report and the diff.
- [ ] Re-run the acceptance suite once yourself (or hand it to a bee-sonnet-medium holding the
      resource): a worktree diff is unverified until compiled on the real project; an in-place
      report is checked, not trusted.
- [ ] Findings go back as the next round's prompt in the same session (-s).
- [ ] Review: under bees, bee-reviewer for scores 1–5, bee-reviewer-high for 8–13.
- [ ] Land it: worktree → apply its commits/diff, then `git worktree remove`; in place → its
      commits are already on the branch.
```
