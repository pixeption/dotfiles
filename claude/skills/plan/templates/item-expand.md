<the stage-1 fields stay exactly as approved; stage 2 appends below them>

**Reach:**
- `Game/Assets/Foo.cs` `Foo.Apply` — changes
- `Game/Assets/Bar.cs` `Bar.Load` — reads
- tests: `FooTests`, `BarTests`
**Sizing:** files 3 · call sites 7 · test classes 2 · runs 1 → S
**Pieces:** none — or `STEP-07a`, `STEP-07b`, each S/M with its own `Done when` and the ACs it proves
**Tests:** AC-1 — `FooTests.Applies_x` (new); AC-2 — `BarTests.Rejects_y` (existing)
**Test filter:** `--filter "FooTests|BarTests"`
**Needs:** STEP-03, or `-`
Done when: AC-1 and AC-2 pass in the filter and the review is APPROVE.
