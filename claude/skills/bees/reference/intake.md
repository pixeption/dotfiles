# Intake: where a reported gap goes

Read when a report lists a gap or a task found during a run. SKILL.md "Intake" holds who writes
what; this table is the only place gap routing is stated, and the root `CLAUDE.md` links here
through it. A backlog row's columns and ids are defined once, in the `docs/backlog.md` header.

| Found | Where it goes |
|---|---|
| A defect or missing capability in an owned package (game-core, game-build) that the current unit would otherwise work around | fixed at the owning source first — its own unit, test and review — before the dependent work continues, never shimmed; not cleanly fixable at the root → stop and surface it (global `CLAUDE.md` "Owned packages") |
| An owned-package defect the unit observed but does not depend on | a backlog row, priority `review`, fixed at the owning source when picked up |
| Blocks the current unit, not an owned package | fixed in that unit |
| Obvious bug, clear fix, inside the unit's own area | fixed in that unit as its own commit |
| Has a workaround and cost < ~5 min, no correctness defect | the agent's report only, with the workaround |
| Anything else (tooling or player-facing) | a backlog row, priority `review`, with the next id of its type |
| Same gap again | extend the matching row's Note; never a second row |
