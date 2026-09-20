import os
import re
from PIL import Image

SP = os.environ["PARITY_SCRATCH"]
RAW = f"{SP}/gcap2"
FINAL = f"{SP}/final"

rows = []
with open(f"{RAW}/measures.tsv") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        theme, ratio, meas = line.split("\t")
        d = dict(re.findall(r"(\w+)=([\d.]+)", meas.replace("x", " ").replace("render ", "renderW=") ))
        # parse render=WxH separately
        rw, rh = re.search(r"render=(\d+)x(\d+)", meas).groups()
        vals = dict(re.findall(r"(cropTop|cropBottom|boardX|boardY|boardW|boardH)=([-\d.]+)", meas))
        rows.append((theme, ratio, int(rw), int(rh), {k: float(v) for k, v in vals.items()}))

print(f"{'theme':9} {'ratio':5} {'crop(x,y,w,h)':24} {'board in crop (x,y,w,h)':28}")
for theme, ratio, rw, rh, v in rows:
    top = int(round(v["cropTop"]))
    bottom = int(round(v["cropBottom"]))
    cx, cy, cw, ch = 0, top, rw, bottom - top
    img = Image.open(f"{RAW}/{theme}__{ratio}__raw.png")
    img.crop((cx, cy, cx + cw, cy + ch)).save(f"{FINAL}/{theme}__{ratio}__game.png")
    bx = int(round(v["boardX"]))
    by = int(round(v["boardY"] - top))
    bw = int(round(v["boardW"]))
    bh = int(round(v["boardH"]))
    print(f"{theme:9} {ratio:5} {str((cx,cy,cw,ch)):24} {str((bx,by,bw,bh)):28}")
