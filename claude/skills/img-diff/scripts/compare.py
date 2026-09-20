#!/usr/bin/env python3
"""img-diff skill — compare two screenshots and report real similarity, not a flattering one.

Usage:
    python3 compare.py A.png B.png [--out-prefix DIR/name] [--threshold 20]

Prints SSIM (primary metric) and a naive pixel-match% (secondary, see caveat below), and writes
two diagnostic images next to --out-prefix (default: alongside A.png):
    <prefix>-overlay.png   A.png with every "structurally different" pixel painted red
    <prefix>-heat.png      grayscale SSIM dissimilarity heatmap (bright = more different)

ALWAYS look at the overlay image (Read it) before trusting the number. A low score is often
concentrated in one real, fixable difference (wrong icon size, missing state) rather than spread
evenly — the overlay tells you which in about two seconds. A high score can also hide a real bug
if it's confined to a small element (e.g. a 20px icon inside a 400px frame barely moves the
whole-image score) — diff the element on its own, not just the full composition, when precision
on one part matters.

Why SSIM and not a raw pixel-diff:
    A naive "% of pixels within N of each other" score is misleadingly high whenever most of the
    image is flat background — two near-identical beige rectangles score ~98% even when the one
    interactive element in the middle (an icon, a border, a control) is visibly wrong, because
    that element is a small fraction of total pixels. SSIM compares local structure (luminance,
    contrast, edges) in sliding windows, so a small-but-real shape/edge mismatch drags the score
    down proportionally to how *different* it looks, not just how much *area* it covers. It's a
    much closer proxy for "does a human notice this."

Sizing caveat (read this before arguing with a low score):
    If A.png and B.png aren't the same pixel size, this script resizes B to match A (Lanczos) before
    comparing — and that resize itself introduces blur that SSIM will count as "different", even
    for two genuinely identical designs. This is the most common reason a comparison looks worse
    than it should. Fix it upstream instead of trusting a resized comparison: use shoot.mjs's
    `--match-width` (or matching `--width`) so both PNGs come out the same pixel size natively,
    with the same --dpr, and re-run. A same-size comparison is always more trustworthy than a
    resized one — this script will tell you in its output whether it had to resize.
"""
import argparse
import sys

import numpy as np
from PIL import Image

try:
    from skimage.metrics import structural_similarity as ssim
except ImportError:
    sys.exit(
        "Missing scikit-image. Install once (persists across sessions on this machine):\n"
        "    python3 -m pip install --user numpy Pillow scikit-image"
    )


def score(a_path, b_path, out_prefix=None, threshold=20, dissim_paint=0.3, mask=None):
    """SSIM-score two PNGs and write the -overlay/-heat diagnostics.

    mask, when given, is an (x, y, w, h) rect flattened to one colour in BOTH images before
    scoring - the way to ask "how close is everything except this region".
    Returns a dict: ssim, pixel_match, resized, sizes, overlay, heat.
    """
    a_im = Image.open(a_path).convert("RGB")
    b_im = Image.open(b_path).convert("RGB")
    resized = a_im.size != b_im.size
    if resized:
        b_im = b_im.resize(a_im.size, Image.LANCZOS)

    a = np.array(a_im)
    b = np.array(b_im)
    if mask:
        x, y, w, h = (int(v) for v in mask)
        a[y:y + h, x:x + w] = 0
        b[y:y + h, x:x + w] = 0

    ssim_score, full = ssim(a, b, channel_axis=-1, data_range=255, full=True)
    dissim = np.clip(1 - full.mean(axis=-1), 0, 1)

    diff = np.abs(a.astype(np.int16) - b.astype(np.int16))
    pixel_match = 100 - (diff.max(axis=-1) > threshold).mean() * 100

    result = {
        "ssim": ssim_score * 100,
        "pixel_match": pixel_match,
        "resized": resized,
        "sizes": (a_im.size, b_im.size),
        "overlay": None,
        "heat": None,
    }
    if out_prefix is not None:
        overlay = a.copy()
        overlay[dissim > dissim_paint] = [255, 0, 0]
        Image.fromarray(overlay).save(f"{out_prefix}-overlay.png")
        Image.fromarray((dissim * 255).astype(np.uint8)).save(f"{out_prefix}-heat.png")
        result["overlay"] = f"{out_prefix}-overlay.png"
        result["heat"] = f"{out_prefix}-heat.png"
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--out-prefix", default=None, help="prefix for -overlay.png/-heat.png (default: <a> without extension)")
    p.add_argument("--threshold", type=int, default=20, help="0-255 per-channel diff treated as a 'different' pixel for the secondary pixel-match%% metric")
    p.add_argument("--dissim-paint", type=float, default=0.3, help="SSIM per-pixel dissimilarity (0-1) above which the overlay paints that pixel red")
    args = p.parse_args()

    prefix = args.out_prefix or args.a.rsplit(".", 1)[0]
    r = score(args.a, args.b, prefix, args.threshold, args.dissim_paint)

    print(f"sizes: {args.a}={r['sizes'][0]}  {args.b}={r['sizes'][1]}{'  (RESIZED to match - see sizing caveat)' if r['resized'] else '  (native, no resize)'}")
    print(f"SSIM:        {r['ssim']:.2f}%   <- primary metric")
    print(f"pixel-match: {r['pixel_match']:.2f}%   (secondary; >{args.threshold}/255 diff = 'different pixel' - tends to read high on flat-background UI, don't rely on it alone)")
    print(f"wrote: {r['overlay']} (red = structurally different, >{args.dissim_paint} dissimilarity)")
    print(f"wrote: {r['heat']} (grayscale dissimilarity heatmap)")


if __name__ == "__main__":
    main()
