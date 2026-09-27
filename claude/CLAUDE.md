# Working preferences

Apply in every repo.

## Memory

Don't write to the auto-memory system — it is local to one machine and one project, so it doesn't
sync and silently diverges. If something seems worth remembering, **ask me first**, and prefer
putting the lesson in committed source: this file, a repo's CLAUDE.md, a skill, or the code/tooling
itself.

## Code

- Short, precise and obviously correct at a glance — long or clever code is hard to review and
  trust. This includes fix snippets inside review/audit docs.
- Extract repeated logic into one tiny helper instead of inlining the same expression twice.
- Prefer the simplest correct expression over a maximally optimized, branchy one; mention the
  optimization as an option unless asked for it.
- No comments unless the code genuinely needs explaining. Express intent through names instead
  (a `TryTakePooled` helper, not a comment on an inline loop).

## Owned packages: fix root causes, not workarounds

`game-core` (including `pipeline-ui`) and `game-build` are **mine**, developed in parallel with
`nono4u` — not frozen third-party dependencies. When an issue, blocker or missing capability shows
up in a consumer, find the root cause and **fix it in the owning package, with a test**.

- Read the package's CLAUDE.md/README/spec before deciding where the fix belongs.
- Never patch a generated or scratch artifact (e.g. a converter's workspace file) to get past a
  blocker — it regenerates and hides the real gap. Fix the source so the result is reproducible
  from committed files alone.
- If it can't be fixed cleanly at the root, **stop and surface it** — don't shim the consumer.
- A package change gets its own review (e.g. codex).
- For a feature that hasn't shipped or been adopted yet, prefer an **aggressive rewrite** (delete
  the old types, redesign cleanly) over a migration that preserves legacy shapes.

## Git commits

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): subject`,
imperative subject, a body explaining why when non-trivial. Split uncommitted changes that mix
unrelated concerns into separate atomic commits, each with its own type.

## Plans and structured docs

- Write a non-trivial plan (e.g. a refactor) to a markdown file in the repo before implementing,
  following the repo's docs convention if it has one; summarize it in chat too.
- For any plan, audit, design review or other markdown deliverable with enumerated items, load the
  `plan` skill and follow its format.

## Browser automation

- Drive **Chrome** (claude-in-chrome). **Arc is off-limits** — its extension instance hangs. If
  `list_connected_browsers` returns several devices, pick Chrome.
- The tools reject `file://` URLs whatever the extension's settings; serve local files over
  `http://localhost`.
