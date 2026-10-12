<the approved brief fields stay exactly as written; expansion appends below them>

**AC:**
- STEP-07-AC1 — a checkable statement
- STEP-07-AC2 — the edge or failure case
**Reach:**
- `Game/Assets/Foo.cs` `Foo.Apply` — changes
- `Game/Assets/Bar.cs` `Bar.Load` — reads
- tests: `FooTests`, `BarTests`
**Verify:** STEP-07-AC1 — `FooTests.Applies_x` (new, plain); STEP-07-AC2 — `BarTests.Rejects_y` (existing); `--filter "FooTests|BarTests"`; <an AC no test proves names its command or file:line inspection; a new Integration test names what a plain test cannot observe>
**Score:** 3
Done when: STEP-07-AC1 and STEP-07-AC2 are verified by their named checks and the review is APPROVE.
