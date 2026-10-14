# Handing off the orchestrator

Read when the context hook fires.

## Triggers

The orchestrator pays its context every turn like any agent, and compaction's summary is lossy in
ways nobody chose. It hands off to a fresh orchestrator — one role, chained — only when its
context runs out, when the context hook fires: the `PostToolUse` hook (`scripts/context-nudge`)
injects "Context at <n>k: … hand off" once per session. Finish the running unit, then hand off. The
hook reads the transcript, which can lag a turn: if it lags, act on the next.

## Checklist

At the next safe point:

```text
- [ ] Start nothing new. Every running unit reports; a reviewer mid-recheck finishes.
- [ ] Retire every Claude bee (the successor cannot receive their notifications). A codex session
      `opencode-budget` still resumes may stay for the successor to resume by id, in its pinned
      directory, same server.
- [ ] Every lane a retired bee held: close its editors and release its claim (nono4u's `workspaces`
      skill "End a lane session" steps 2–3) — a retired holder never comes back to do it.
- [ ] Every gap a report listed since the last handoff has been routed through bees "Intake".
- [ ] Status file current (`<plan>.status.md`): Now, Next, Blocked, Resources, Rules, Fixes, so
      the successor needs nothing from this tab. Resources names each lane's holder and
      editor/Play-mode state, each repo's branch, HEAD and uncommitted paths (owner WIP named),
      accepted-but-unintegrated ranges and each kept codex session; Rules holds every owner
      decision that still applies, in place; no environment lines — the successor re-runs
      machine checks.
- [ ] `git diff --numstat -- <plan>.md`: a handoff edits at most the checklist, so more deletions
      than those edits mean a truncated write — restore the plan before committing.
- [ ] Log `handoff: <tab name>`; the handoff commit, by path:
      `git commit -m 'docs(plans): handoff …' -- <plan>.md <plan>.status.md <plan>.log.md`
      (one of the docs-only commits bees "Commit cadence" permits).
- [ ] Spawn the successor (below).
- [ ] Confirm the new tab is up (ListAgents shows its name), report the handoff, dispatch nothing
      further. This session stays open as a fallback and starts nothing.
```

## Spawning the successor

Fill `<plan>` in the template and pipe it to the handoff script, which reads the brief from
stdin and is not on PATH:

```sh
plan=docs/plans/<plan>
sed "s|<plan>|$plan|g" ~/.claude/skills/bees/templates/successor-brief.txt |
  ~/.claude/skills/handoff/scripts/spawn-handoff.sh --cwd <repo> --task "${plan##*/} continued" --model '<exact current model id>'
```

## After a compaction

Compaction stays enabled only as the fallback for a single unit that overruns the window before a
safe point. The first action after one is to read the plan's checklist and its status file (bees
"Setup") and run `bees-watch`, not to trust the summary.
