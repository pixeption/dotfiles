# Coding preferences

These apply across all repos, not just one project — consolidated from project-scoped feedback
memory that turned out to be general working-style preferences, not project-specific.

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
Code/API snippets inside a plan doc use a language-tagged fence (` ```csharp `, ` ```ts `, etc.),
never a bare fence.

## Structured review/audit docs

For code audits, implementation plans, design reviews, or any markdown deliverable with
enumerated items:

- Header block right under the title: `**Date:**`, `**Scope:**`, `**Focus:**`, `**By:**` (agent +
  reasoning effort, e.g. `**By:** claude-opus-4-8 · reasoning: high`; name the subagent too if one
  was used), and `**Method:**` when real verification was done (compile check, call-site tracing,
  an actual build/test run, etc.).
- A triage/summary table immediately followed by a checklist table, **both at the top** of the
  doc, right after the header block — never at the end, even if a project's own CLAUDE.md says to
  end with a checklist; this preference wins.
- Every checklist ID is a markdown anchor link to its section heading below
  (`[BUG-01](#bug-01--title-slug)`), never plain text. Anchor targets are GitHub's auto-slug of
  the heading (lowercase, spaces→`-`, most punctuation dropped, ` · ` and ` — ` each become `--`).
- Stable, category-prefixed, sequential IDs (`BUG-01`, `PERF-01`, `STEP-01`, ...); each item is a
  `### <ID> · <title>` heading. Keep IDs stable across re-runs — mark done items inline
  (`✅` in the checklist + `**✅ Fixed/Done <date>**` on the heading) rather than renumbering; for
  a re-run, add a compact "Resolved since previous" table.
- Source references inside such docs should be clickable, relative-path markdown links landing on
  the exact line, not bare inline-code paths: `[World.cs:92](relative/path/World.cs#L92)`, ranges
  as `#L84-L112`.

## Browser automation

Drive **Chrome** — it has the claude-in-chrome extension installed for exactly this. **Arc is also
on the machine and is off-limits for automation**; its extension instance has hung and stopped
responding to `tabs_context_mcp`. If `list_connected_browsers` returns more than one device, pick
the Chrome one rather than guessing.

The tools also **reject `file://` URLs outright**, regardless of the extension's "allow access to
file URLs" setting. Serve local files over `http://localhost` instead.
