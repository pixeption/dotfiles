Outcome: Changes required.

## Findings

MAJ-01 — Major — the slot wrapper is missing, so the root loses its flow hints. Fix: wrap it:
    const slot = document.createElement('div');
    root.replaceWith(slot); slot.append(root);

  and size the slot, not the root.

MIN-02 — Minor — a stale aria attribute on non-toggle roots.

## Acceptance and verification

AC-1 fails through MAJ-01.

BEES: reviews=CASE-01:MAJ-01,MIN-02
CHANGES_REQUIRED
