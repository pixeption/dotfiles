# Handing off the orchestrator

Read when the context hook fires.

## Triggers

The orchestrator pays its context every turn like any agent, and compaction's summary is lossy in
ways nobody chose. It hands off to a fresh orchestrator — one role, chained — only when its
context runs out, when the context hook fires: the `PostToolUse` hook (`scripts/context-nudge`)
injects "Context at <n>k: … hand off" once per session. Finish the step in hand (a landing, a
dispatch, a consult), then hand off; running units keep running. The hook reads the transcript,
which can lag a turn: if it lags, act on the next.

## Checklist

Start nothing new; running Claude bees and codex rounds keep running in this session. Hand off at
the first safe point where a unit could start — a `ready` item or fix unit with a free lane and room
under the agent cap — since only then does a lane idle waiting on this session; until then keep
accepting hand-backs as usual. Every unit done and none startable: hand off with nothing `in flight`.

```text
- [ ] Every gap a report listed since the last handoff has been routed through bees "Intake".
- [ ] Status file current (`<plan>.status.md`): Now, Next, Blocked, Resources, Rules, Fixes, so
      the successor needs nothing from this tab, and every finished line deleted (bees "Status
      and acceptance"). Each running unit's Now line ends `· in flight`, naming its out-file for a
      codex round. Resources names each lane's holder and
      editor/Play-mode state, each repo's branch, HEAD and uncommitted paths (owner WIP named),
      accepted-but-unintegrated ranges and each kept codex session; Rules holds every owner
      decision that still applies, in place; no environment lines — the successor re-runs
      machine checks.
- [ ] `git diff --numstat -- <plan>.md`: a handoff edits at most the checklist, so more deletions
      than those edits mean a truncated write — restore the plan before committing.
- [ ] Log `handoff: <tab name>`; the handoff commit, by path:
      `git commit -m 'docs(plans): handoff …' -- <plan>.md <plan>.status.md <plan>.log.md`
      (one of the docs-only commits bees "Status and acceptance" permits).
- [ ] Spawn the successor (below) and confirm it is up (ListAgents shows its name).
- [ ] Become the relay ("Relaying") until every `in flight` unit is forwarded.
```

## Spawning the successor

Fill `<plan>` in the template and pipe it to the handoff script, which reads the brief from
stdin and is not on PATH:

```sh
plan=docs/plans/<plan>
sed "s|<plan>|$plan|g" ~/.claude/skills/bees/templates/successor-brief.txt |
  ~/.claude/skills/handoff/scripts/spawn-handoff.sh --cwd <repo> --task "${plan##*/} continued" --model '<exact current model id>'
```

Keep its printed `NAME=`: every relay message goes there.

## Relaying

After the handoff commit the successor is the only ledger keeper, since two writers of the plan
files, the claim registry or `integration` conflict. The relay edits nothing — no plan file, no
`workspace.sh` command, no landing, no dispatch, no review — and only forwards, with `SendMessage`
to the successor's name:

- **A unit hands back** (a bee's report or a codex round's termination): send `[relay] <unit>`
  followed by the bee's whole report verbatim, or the round's out-file path, since the successor
  accepts on the report's own evidence.
- **The successor asks** to continue or stop one of this session's bees: do exactly that, with
  its text verbatim; nothing else reaches a bee from here.
- **The last `in flight` unit is forwarded**: send `[relay] done`, report the handoff, and stay
  open, idle.

## After a compaction

Compaction stays enabled only as the fallback for a single unit that overruns the window before a
safe point. The first action after one is to read the plan's checklist and its status file (bees
"Setup") and run `bees-watch`, not to trust the summary.
