Outcome: Changes required — one major, one minor.

## Findings

### MAJ-02 — Major — the cache key ignores the theme

**Where:** `Game/Assets/Scripts/Cache.cs:41`

The key is built from the view name only, so a theme switch serves the previous theme's sprite.

**Fix:**

```csharp
var key = $"{view}/{theme}";
```

### MIN-03 — Minor — a stale comment names the old field

Delete the comment at `Cache.cs:12`.

## Acceptance and verification

AC-1 holds; AC-2 fails through MAJ-02.

Cost: ~20k tokens context now / 12 turns / ~4 min elapsed
BEES: reviews=CACHE-01:MAJ-02,MIN-03
CHANGES_REQUIRED
