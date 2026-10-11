# Intake: where a reported gap goes

Read when a report lists a gap or a task found during a run. SKILL.md "Intake" holds who writes
what; this table is the only place gap routing is stated, and `tooling-gaps.md` and the root
`CLAUDE.md` link here through it.

| Found | Where it goes |
|---|---|
| A defect or missing capability in an owned package (game-core, game-build) that the current unit would otherwise work around | fixed at the owning source first — its own unit, test and review — before the dependent work continues, never shimmed; not cleanly fixable at the root → stop and surface it (global `CLAUDE.md` "Owned packages") |
| An owned-package defect the unit observed but does not depend on | a `tooling-gaps.md` row, fixed at the owning source when picked up |
| Blocks the current unit, not an owned package | fixed in that unit |
| Obvious bug, clear fix, inside the unit's own area | fixed in that unit as its own commit |
| Has a workaround and cost < ~5 min, no correctness defect | a `gap:` log line only, with the workaround |
| Anything else (tooling) | a `tooling-gaps.md` row: `Hits 1`, minutes lost, workaround |
| Anything else (player-facing) | `docs/backlog.md` under "Later", next free `T-nnn` |
| Same gap again | `Hits` + 1 and minutes added on the existing row; never a second row |

A backlog or tooling-gaps row that is queued gets `→ Q-nn` in its Status, so nothing is queued
twice.
