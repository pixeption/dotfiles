<the approved brief fields stay exactly as written; expansion appends below them>

**Today:** `Foo.Apply` (`Game/Assets/Foo.cs`) writes x on every call, so y drifts; evidence: <the failing output>.
**Approach:** `Foo.Apply` writes x only when it changed, as `Bar.Load` already does; keep z's order, since `Baz` reads it. Guidance: <package> CLAUDE.md "<heading>".
**Tests:**
- an unchanged second apply writes nothing — `FooTests` (new, plain)
- a changed x is written once — `FooTests` (new, plain)
- loading still reads z in order — `BarTests` (existing)
- `--filter "FooTests|BarTests"`
**Score:** 3
Done when: the Tests pass and every named non-test check holds.
