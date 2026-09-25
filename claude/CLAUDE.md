# Coding preferences

These apply across all repos, not just one project — consolidated from project-scoped feedback
memory that turned out to be general working-style preferences, not project-specific.

## Memory

Don't write to the auto-memory system (user / project / agent memory files). Memory is local to
one machine and one project, so it doesn't sync and silently diverges. If something seems worth
remembering, **ask me first** — and prefer fixing the root cause instead: update this file, a
repo's CLAUDE.md, a skill, or the code/tooling itself so the lesson lives in committed source.

## Comments

Don't add comments unless the code is genuinely hard to understand or needs real explanation —
self-documenting code through good names is preferred over comments that restate what the code
already says. Prefer expressing intent via a method/variable name (e.g. a `TryTakePooled` helper
instead of a comment on an inline loop) over adding prose next to the code.

## Code quality

All code — including fix snippets inside review/audit docs — should be short, precise, easy to
understand, and obviously correct at a glance; long or clever code is hard to review and trust.
Extract repeated logic into one tiny helper instead of inlining the same expression multiple
times. Prefer the simplest correct expression over a maximally-optimized branchy one; mention the
optimization as an option rather than writing it out unless asked.

## Owned packages in co-development (fix root causes, not workarounds)

`game-core` and `pipeline-ui` (and `game-build`) are **mine too** — they are developed in
parallel with `nono4u`, not frozen third-party dependencies. So when an issue, blocker, or missing
capability surfaces while working in `nono4u`, the default is to **find the root cause and fix it in
the owning package**, with a test — not to work around it in the consumer.

- Never patch a generated or scratch artifact to get past a blocker (e.g. a converter's
  intermediate/workspace file). Those regenerate and the edit is lost; worse, it hides a real gap.
  Fix the source (the design HTML, the tool, the package) so the result is reproducible from
  committed source alone.
- When a blocker can't be fixed cleanly at the root, **stop and surface it** — don't shim the
  consumer or a scratch file to keep moving.

## Git commits

Use Conventional Commits (https://www.conventionalcommits.org/en/v1.0.0/) for every commit:
`type: subject` (e.g. `refactor:`, `fix:`, `feat:`, `ci:`, `chore:`), optionally
`type(scope):`, imperative subject, body explaining the why/what when non-trivial. When a batch
of uncommitted changes mixes unrelated concerns (e.g. an API-rename refactor across many files
plus a CI workflow tweak plus a solution-file change), split into separate atomic commits by
concern rather than one grab-bag commit — each gets its own conventional-commit type.

## Plans

For a non-trivial plan (e.g. a refactor) before implementing, write it to a markdown file in the
repo rather than presenting it only as chat text — better visibility, easier to review. Still
summarize in chat too, but the file is the reviewable artifact. Check for an existing docs
convention in the repo (e.g. `Assets/Docs/`) and follow it; otherwise pick a sensible location.

## Structured review/audit docs

For any structured code audit, implementation plan, design review, or markdown deliverable with
enumerated items, load the `plan` skill and follow its format rules.

## Browser automation

Drive **Chrome** — it has the claude-in-chrome extension installed for exactly this. **Arc is also
on the machine and is off-limits for automation**; its extension instance has hung and stopped
responding to `tabs_context_mcp`. If `list_connected_browsers` returns more than one device, pick
the Chrome one rather than guessing.

The tools also **reject `file://` URLs outright**, regardless of the extension's "allow access to
file URLs" setting. Serve local files over `http://localhost` instead.
