# Handing off the orchestrator

Read when a phase ends or the context hook fires.

## Triggers

The orchestrator pays its context every turn like any agent, and compaction's summary is lossy in
ways nobody chose. It hands off to a fresh orchestrator — one role, chained — at:

- **Phase end**: every parent item in phase N is accepted, including parents represented by ☑
  piece rows, so checkpoints are not mistaken for missing or completed acceptance, and the GATE
  row's full suites are green. You decide this from the checklist and parent acceptance log
  lines; no tool does. Triage, pick-up and the retro are the successor's opening (bees "Triage",
  "Retro"), never the retiring session's.
- **Context**: the `PostToolUse` hook (`scripts/context-nudge`) injects "Context at 170k: … hand
  off" once per session, since a handoff there costs least for the measured startup cost and
  growth. Finish the running unit, then hand off by ~200k. The hook reads the transcript, which
  can lag: if your context is clearly past 170k and it has not fired, act as if it had.

## Checklist

At the next safe point:

```text
- [ ] Start nothing new. Every running unit reports; a reviewer mid-recheck finishes.
- [ ] Retire every Claude bee (the successor cannot receive their notifications). A codex session
      under 200k may stay for the successor to resume by id, in its pinned directory, same server.
- [ ] Every lane a retired bee held: close its editors and release its claim (nono4u's `workspaces`
      skill "End a lane session" steps 2–3) — a retired holder never comes back to do it.
- [ ] Every gap a report listed since the last handoff is a tooling-gaps row or a `gap:` log line.
- [ ] Rules: every owner decision that still applies is a line there, in place, naming the one it
      replaces; no environment lines — the successor re-runs machine checks.
- [ ] Resume, overwritten, ≤ 10 lines, so the successor needs nothing from this tab: lane and
      holder, editor/Play-mode state; each repo's branch, HEAD and uncommitted paths (owner WIP
      named); accepted-but-unintegrated ranges; blockers; open review ids; each kept codex session
      (id, pinned dir, last out-file, context); the last verification command and result.
- [ ] Queue: the running row's Stage and Lanes current; the next row's AC in the Owner list.
- [ ] Log `handoff: phase N → <tab name>`; the handoff commit, by path:
      `git commit -m 'docs(plans): handoff …' -- <plan>.md <plan>.log.md docs/queue.md`
      (one of the docs-only commits bees "Commit cadence" permits).
- [ ] Spawn the successor (below).
- [ ] Confirm the new tab is up (ListAgents shows its name), report the handoff, dispatch nothing
      further. This session stays open as a fallback and starts nothing.
```

## Spawning the successor

Fill `<plan path>`, `<plan>` and `<N>` in the template and pipe it to the handoff script, which
reads the brief from stdin and is not on PATH:

```sh
plan=docs/plans/<plan>; n=<N>
sed -e "s|<plan path>|$plan.md|" -e "s|<plan>|$plan|" -e "s|<N>|$n|" \
  ~/.claude/skills/bees/templates/successor-brief.txt |
  ~/.claude/skills/handoff/scripts/spawn-handoff.sh --cwd <repo> --task "${plan##*/} phase $n" --model '<exact current model id>'
```

`n` is N+1 at phase end, or N with `--task "… phase N continued"` on the hook.

## After a compaction

Compaction stays enabled only as the fallback for a single unit that overruns the window before a
safe point. The first action after one is to read the queue, the plan's checklist, Rules and Resume
(bees "Setup") and run `bees-watch`, not to trust the summary.
