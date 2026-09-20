#!/usr/bin/env python3
"""img-diff skill — batch parity: capture every (theme x ratio) pair, score them, print a table.

    parity-shot.py --mockup-url http://localhost:8756/screens/PlayScreen.html \
      --themes paper,midnight,zen --ratios 9:16,9:20,3:4 \
      --seed 'g.level.mockupParity' --out docs/ui/parity --gate 0.95 [--mask rects.json]

Each pair is one `unity command ui_shot` (device + seed + capture + crop in one call) and one
`node shoot.mjs` at that ratio's matched mockup viewport. NOTHING but the score table is printed:
never read the diff PNGs back to score a run — parse the table, then open exactly one overlay to
diagnose a named failing pair.

--mask takes a JSON file of {"<theme>__<ratio>": [x, y, w, h]} (or {"<ratio>": [...]}) naming the
region to exclude — the puzzle board, whose content is data, not design. Masked pairs report both
the full score and the masked one.
"""
import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import score  # noqa: E402

SHOOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shoot.mjs")

# The reviewed ratios: the Device Simulator device the game renders on (mirroring
# pipeline-ui-live's RatioDeviceMap) and the browser viewport the mockup is captured at.
RATIOS = {
    "9:16": {"game": (1080, 1920), "mockup": (390, 693), "url": "phone"},
    "9:20": {"game": (1080, 2400), "mockup": (393, 873), "url": "phone"},
    "3:4": {"game": (1536, 2048), "mockup": (834, 1112), "url": "tablet"},
}


def run(command, timeout=180):
    done = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if done.returncode != 0:
        raise RuntimeError(f"{' '.join(command[:3])} failed: {(done.stderr or done.stdout).strip()[:400]}")
    return done.stdout


def capture_game(args, theme, ratio, out_path):
    unity = [args.unity, "command"]
    project = ["--project-path", args.project_path]
    if args.theme_command:
        run(unity + ["devconsole", "--input", args.theme_command.format(theme=theme)] + project)
    shot = unity + ["ui_shot", "--ratio", ratio, "--crop", args.crop, "--out", out_path] + project
    if args.seed:
        shot += ["--seed", args.seed]
    run(shot, timeout=args.timeout)


def capture_mockup(args, theme, ratio, out_path):
    width, height = RATIOS[ratio]["mockup"]
    url = args.tablet_url if RATIOS[ratio]["url"] == "tablet" and args.tablet_url else args.mockup_url
    run([
        "node", SHOOT, "--url", url, "--full-page", "--out", out_path,
        "--width", str(width), "--height", str(height), "--dpr", str(args.dpr),
        "--wait", str(args.wait),
        "--eval", f"document.body.setAttribute('data-theme', '{theme}')",
    ], timeout=args.timeout)


def sheet(rows, out_dir):
    cells = "".join(
        f"<figure><figcaption>{r['pair']} — {r['ssim']:.2f}%</figcaption>"
        f"<img src='{r['game']}'><img src='{r['mockup']}'><img src='{r['diff']}'></figure>"
        for r in rows)
    path = os.path.join(out_dir, "index.html")
    with open(path, "w") as handle:
        handle.write(
            "<style>body{font:13px system-ui;background:#111;color:#eee}"
            "figure{display:inline-block;margin:8px}img{height:320px;vertical-align:top}</style>" + cells)
    return path


def table(rows, gate):
    width = max(len(r["pair"]) for r in rows)
    lines = [f"{'pair'.ljust(width)}  {'ssim':>7}  {'masked':>7}  {'gate':>5}  note"]
    for r in rows:
        masked = f"{r['masked']:.2f}" if r["masked"] is not None else "-"
        verdict = "PASS" if (r["masked"] if r["masked"] is not None else r["ssim"]) >= gate * 100 else "FAIL"
        lines.append(
            f"{r['pair'].ljust(width)}  {r['ssim']:7.2f}  {masked:>7}  {verdict:>5}  {r['note']}")
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--mockup-url", required=True)
    p.add_argument("--tablet-url", help="mockup URL for the 3:4 row, when the tablet layout is its own page")
    p.add_argument("--themes", default="paper,midnight,zen")
    p.add_argument("--ratios", default="9:16,9:20,3:4")
    p.add_argument("--seed", help="console line run before each capture, e.g. 'g.level.mockupParity'")
    p.add_argument("--theme-command", help="console line applying a theme; '{theme}' is substituted")
    p.add_argument("--out", required=True, help="output directory; one subfolder per theme")
    p.add_argument("--gate", type=float, default=0.95)
    p.add_argument("--mask", help="JSON file of {'theme__ratio' or 'ratio': [x,y,w,h]} regions to exclude")
    p.add_argument("--emit", choices=["table", "json", "sheet"], default="sheet")
    p.add_argument("--crop", default="content")
    p.add_argument("--dpr", type=int, default=2)
    p.add_argument("--wait", type=int, default=300)
    p.add_argument("--unity", default="unity")
    p.add_argument("--project-path", default="Game")
    p.add_argument("--timeout", type=int, default=180)
    args = p.parse_args()

    masks = json.load(open(args.mask)) if args.mask else {}
    rows = []

    for theme in args.themes.split(","):
        folder = os.path.join(args.out, theme)
        os.makedirs(folder, exist_ok=True)
        for ratio in args.ratios.split(","):
            if ratio not in RATIOS:
                sys.exit(f"unknown ratio '{ratio}'; known: {', '.join(RATIOS)}")
            tag = ratio.replace(":", "x")
            game = os.path.join(folder, f"{tag}__game.png")
            mockup = os.path.join(folder, f"{tag}__mockup.png")

            capture_game(args, theme, ratio, game)
            capture_mockup(args, theme, ratio, mockup)

            pair = f"{theme}__{tag}"
            full = score(game, mockup, os.path.join(folder, f"{tag}__diff"))
            mask = masks.get(pair) or masks.get(ratio)
            masked = score(game, mockup, None, mask=mask)["ssim"] if mask else None
            rows.append({
                "pair": pair,
                "ssim": full["ssim"],
                "masked": masked,
                "game": os.path.relpath(game, args.out),
                "mockup": os.path.relpath(mockup, args.out),
                "diff": os.path.relpath(full["overlay"], args.out),
                "note": "RESIZED (sizes differ)" if full["resized"] else "native",
            })

    if args.emit == "json":
        print(json.dumps(rows, indent=2))
        return
    print(table(rows, args.gate))
    if args.emit == "sheet":
        print(f"\ncontact sheet: {sheet(rows, args.out)}")


if __name__ == "__main__":
    main()
