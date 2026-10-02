# Handing off the orchestrator

Read when a phase ends or the context hook fires.

## Triggers

The orchestrator pays its context every turn like any agent, and compaction's summary is lossy in
ways nobody chose. It hands off to a fresh orchestrator — one role, chained — at:

- **Phase end**: every unit in phase N is ✅. You decide this; no tool does.
- **Context**: the `PostToolUse` hook (`scripts/context-nudge`) injects "Context at 200k: … hand
  off" once per session. Finishing the running unit past 200k is fine; not handing off is not. The
  hook reads the transcript, which can lag: if your context is clearly past 200k and it has not
  fired, act as if it had.

## Checklist

At the next safe point:

```text
- [ ] Start nothing new. Every running unit reports; a reviewer mid-recheck finishes.
- [ ] Retire every Claude bee (the successor cannot receive their notifications). A codex session
      under 200k may stay for the successor to resume by id, in its pinned directory, same server.
- [ ] Write <plan>.status.md so the successor needs nothing from this tab:
      Setup — owner answers, each environment check with machine and date
      Now / Resources — each kept codex session (id, pinned dir, last out-file, context),
        editor/Play-mode state and holder, each repo's branch, HEAD and uncommitted paths
        (owner WIP named), last verification command and result, open review ids
      Next / Blocked — the next ready unit, blockers
      Keep in mind — still-applicable decisions, or links to their log lines
- [ ] Log `handoff: phase N → <tab name>`; commit the plan and both files.
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
safe point. The first action after one is to read `<plan>.status.md` and run `bees-watch`, not to
trust the summary.
