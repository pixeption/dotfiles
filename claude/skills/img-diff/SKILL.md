---
name: img-diff
description: Compare two rendered UI elements/pages for visual parity — a design mockup vs. its implementation, before/after a change, two themes, two browsers. Screenshots both with Playwright at a controlled, matched size and scores them with SSIM (not a naive pixel-diff, which reads misleadingly high on flat-background UI), producing a red-overlay diagnostic image. Use whenever asked to check visual "parity", "does this match the mockup", "did this change anything visually", or to quantify how close two renders are.
---

# img-diff — screenshot + SSIM comparison

Two building blocks, meant to be composed per-task rather than run as one rigid command, because
"compare these two things" varies every time (different selectors, different viewport quirks,
different states to set up first):

- `scripts/shoot.mjs` — Playwright: screenshot one element (or a full page) at a controlled size.
- `scripts/compare.py` — SSIM-score two PNGs, with a diagnostic overlay image.

Both are pre-installed in this skill's own directory (`npm install` already run here — `shoot.mjs`
gets its `playwright` library through a dependency on `@playwright/cli` rather than its own direct
`playwright` install, so it shares the same package version and browser binaries as the
`playwright-cli` skill instead of duplicating them; Python deps go to the user site-packages via
`pip install --user`, which persists across sessions on this machine) — no per-session setup
needed. If `compare.py` reports missing `scikit-image`, run the one-line install it prints and
continue; don't reach for a different comparison method.

## The workflow

1. **Serve local HTML over `http://localhost`, never `file://`.** Relative CSS/asset links and
   `fetch()` calls can silently fail under `file://` even though Playwright itself doesn't block
   the scheme outright — don't debug that class of flakiness, just serve it:
   ```bash
   cd <dir with the HTML> && python3 -m http.server 8791 --bind 127.0.0.1 & disown
   ```
   Kill it when done: `pkill -f "http.server 8791"`.

2. **Shoot both targets at the same pixel size, natively — do not resize to align them.**
   This is the one rule that matters most. Resizing either screenshot to match the other's
   dimensions blurs edges, and that blur reads as "different" to SSIM — inflating the apparent
   mismatch for two designs that actually agree. Get matching native sizes instead:
   - If both targets are naturally responsive to viewport width, pass the same `--width` to both.
   - If one target's rendered size depends on surrounding chrome you don't want to hand-compute
     (padding, a device frame, flex siblings), use `--match-width <px>` on that shot: it
     binary-searches the viewport width until the selector's own `getBoundingClientRect().width`
     converges on the target px value. Point `--match-width` at the *other* screenshot's already-
     known width (shoot that one first with `--print-box` to read it off).
   - Always pass the same `--dpr` (default 2) to both — supersampling reduces antialiasing noise
     that would otherwise show up as diff.

   ```bash
   node scripts/shoot.mjs --url http://127.0.0.1:8791/a.html --selector '#thing' \
     --width 390 --dpr 2 --out /tmp/a.png --print-box
   # box printed: width 354 — use that as the match target for the other side

   node scripts/shoot.mjs --url http://127.0.0.1:8791/b.html --selector '.other-thing' \
     --width 390 --height 900 --dpr 2 --match-width 354 \
     --eval "document.querySelector('.thing').dataset.state='active'" \
     --out /tmp/b.png --print-box
   ```
   `--eval` runs after page load, before the shot — use it to flip a class/attribute/state that
   isn't reachable via URL params (data-attributes, toggling a preview control, etc.).

3. **Score with `compare.py`, not a hand-rolled pixel-diff.** A naive "% of pixels within N of
   each other" metric reads misleadingly high whenever most of the image is flat background —
   two near-identical panels can score ~98% by that measure even when the one interactive element
   in the middle is visibly wrong, because it's a small fraction of total pixels. SSIM compares
   local structure (luminance/contrast/edges) in sliding windows, so it drags down proportionally
   to how different a region *looks*, not how much area it covers — a much closer proxy for "does
   a human notice this."
   ```bash
   python3 scripts/compare.py /tmp/a.png /tmp/b.png
   ```
   Prints SSIM (primary) and a secondary pixel-match% (context only, don't lead with it), and
   writes `<a>-overlay.png` (red = structurally different regions) and `<a>-heat.png`
   (dissimilarity heatmap).

4. **Read the overlay image before trusting the number.** Always. A score under your target is
   often concentrated in one real, nameable difference (wrong icon size, missing border, extra
   opacity) rather than spread evenly — the overlay makes that obvious in seconds and turns "94.85%,
   not sure why" into a specific, fixable diagnosis. It also catches the inverse failure: a
   generously high score can still hide a real bug confined to a small element, if that element is
   a small fraction of the total frame — crop to just that element (a tighter `--selector`) and
   diff it on its own when precision on one part matters more than the whole composition.

5. **If the score is low, form a hypothesis from the overlay, fix, re-shoot, re-compare** — same
   two commands, cheap to iterate. Before spending a design-token or geometry change to chase the
   last few points, weigh the cost: a magic non-token pixel value that buys +0.2% is usually a bad
   trade against breaking a design system's token scale — say so instead of silently taking it.

## Batch parity — many pairs, one table (`parity-shot.py`)

When the question is a *matrix* — every theme x every ratio against the mockup — do not hand-run the
two commands N times. `scripts/parity-shot.py` captures and scores every pair in one call and prints
the table:

```bash
python3 ~/.claude/skills/img-diff/scripts/parity-shot.py \
  --mockup-url http://localhost:8756/screens/PlayScreen.html \
  --themes paper,midnight,zen --ratios 9:16,9:20,3:4 \
  --seed 'g.level.mockupParity' --out docs/ui/parity --gate 0.95
```

- Each game shot is one `unity command ui_shot --ratio ... --seed ... --crop content` (device
  selection, seeding, capture and crop in a single call); each mockup shot is `shoot.mjs` at that
  ratio's matched viewport. `--seed` and `--theme-command '<line with {theme}>'` both run through
  `unity command devconsole --input`, so anything the game registers as a `[ConsoleCommand]` can set
  the state up. `--mask rects.json` (`{"theme__ratio" or "ratio": [x,y,w,h]}`) excludes a
  data-driven region — a puzzle board, a feed — and the table then gates on the masked score.
- **Never read the diff PNGs to score a run.** Parse the table; open exactly one overlay, for one
  named failing pair, to diagnose it. Images in context are the expensive part of a parity loop.
- **Matched-size contract**: both sides are captured at the map's pixel size, never resized. The
  `note` column says `native` or `RESIZED (sizes differ)`; a `RESIZED` row is `compare.py`'s Lanczos
  fallback and its score is a floor, not a measurement — fix the capture size before reading it.
- `parity-v1/` holds the hand-built scripts this replaced (band scoring, a DOM-rect mockup crop),
  kept as reference for a review that needs per-region scores rather than whole-screen ones. They are
  project-specific one-offs driven by env vars (`PARITY_SCRATCH`, `PARITY_BASE`, `PARITY_OUT`,
  `UNITY`, `PROJECT_PATH`) — read one before running it, don't expect it to work as-is.

## Interpreting SSIM in practice

- Two independently-rendered documents (different DOM, different CSS techniques, different font
  rasterization paths) essentially never hit 100%, even when they look identical to a human — font
  hinting/antialiasing alone costs a point or two. Don't chase 100%; chase "the overlay shows
  nothing but text-edge antialiasing and sub-pixel noise, no real shape".
- SSIM computed over a full composite image is *not* just the average of its parts — a boundary
  region between two sub-elements (e.g. a small gap between two side-by-side controls) can drag
  the whole-image score below either sub-region's own score, because windowed SSIM straddles that
  boundary. If the whole-image number is surprising, crop and score the sub-regions separately
  (two more `shoot.mjs`/`compare.py` calls) to see whether it's one shared trouble spot or a
  boundary-window artifact — report both if it clarifies the picture.
- A single lever that only buys a fraction of a percent at a real design-consistency cost (an
  off-token radius, a magic-number gap) is usually not worth taking — say so and stop, rather than
  chasing the number past the point of diminishing, costly returns.

## Worked example

Comparing `docs/ui/views/TrackpadTool.html`'s trackpad control (a nono4u repo Unity-UI design
source) against its reference mockup at `docs/ui/mockup/main-game-mockup.html`:

```bash
cd docs/ui && python3 -m http.server 8791 --bind 127.0.0.1 & disown

node ~/.claude/skills/img-diff/scripts/shoot.mjs \
  --url 'http://127.0.0.1:8791/views/TrackpadTool.html?preview=1' \
  --selector '[data-id="root"]' --width 390 --height 300 --dpr 2 \
  --out /tmp/gallery.png --print-box
# box: width 354

node ~/.claude/skills/img-diff/scripts/shoot.mjs \
  --url 'http://127.0.0.1:8791/mockup/main-game-mockup.html' \
  --selector '.trackpad-controls' --width 390 --height 900 --dpr 2 \
  --match-width 354 \
  --eval "document.querySelector('.phone').setAttribute('data-control','trackpad')" \
  --out /tmp/mockup.png --print-box
# binary-search converged on viewport 402 -> box: width 354 (matches, no resize needed)

python3 ~/.claude/skills/img-diff/scripts/compare.py /tmp/gallery.png /tmp/mockup.png
# SSIM: 94.85%   pixel-match: 98.06% (the pixel-match number alone would have looked "done" —
# SSIM caught what it didn't: a real border/crosshair-opacity and icon-size mismatch, visible
# immediately in the overlay as a solid red ring around the pad and both icons)
```

That first pass used a naive pixel-diff and reported 96.3% — looked done. Redoing it with SSIM at
matched native size (no resize) surfaced 94.85%, just under a 95% target, and the overlay pointed
straight at the real remaining differences (edge/corner rendering, font antialiasing) rather than
leaving it a mystery.
