#!/usr/bin/env python3
"""STEP-06 final re-score: full-content SSIM + GUI-only (board-masked) SSIM."""
import json
import os
import numpy as np
from PIL import Image, ImageDraw
from skimage.metrics import structural_similarity as ssim

BASE = os.environ["PARITY_BASE"]
OUT_ROOT = os.environ["PARITY_OUT"]

# rects: (x,y,w,h) per theme-group (paper/midnight share; zen separate), per ratio
GAME_RECTS = {
    "9x16": {"paper": (0,270,1080,1080), "midnight": (0,270,1080,1080), "zen": (0,262,1080,1080)},
    "9x20": {"paper": (0,326,1080,1080), "midnight": (0,326,1080,1080), "zen": (0,318,1080,1080)},
    "3x4":  {"paper": (34,130,1469,1469), "midnight": (34,130,1469,1469), "zen": (43,130,1451,1451)},
}
MOCK_RECTS = {
    "9x16": {"paper": (4,160,756,739), "midnight": (4,160,756,739), "zen": (4,142,756,739)},
    "9x20": {"paper": (4,303,762,744), "midnight": (4,303,762,744), "zen": (4,305,762,744)},
    "3x4":  {"paper": (56,168,1556,1522), "midnight": (56,168,1556,1522), "zen": (56,175,1556,1522)},
}

THEMES = ["paper", "midnight", "zen"]
RATIOS = ["9x16", "9x20", "3x4"]

def ssim_overlay(a_im, b_im, dissim_paint=0.3):
    """a_im, b_im: PIL RGB images, must be same size. Returns score, overlay(PIL on a), heat unused."""
    a = np.array(a_im)
    b = np.array(b_im)
    score, full = ssim(a, b, channel_axis=-1, data_range=255, full=True)
    dissim = np.clip(1 - full.mean(axis=-1), 0, 1)
    overlay = a.copy()
    overlay[dissim > dissim_paint] = [255, 0, 0]
    return score * 100, Image.fromarray(overlay)

def band_score(game_im, mock_im, grect, mrect, band):
    gx, gy, gw, gh = grect
    mx, my, mw, mh = mrect
    GW, GH = game_im.size
    MW, MH = mock_im.size
    if band == "top":
        g_box = (0, 0, GW, gy)
        m_box = (0, 0, MW, my)
    else:
        g_box = (0, gy + gh, GW, GH)
        m_box = (0, my + mh, MW, MH)
    g_band = game_im.crop(g_box)
    m_band = mock_im.crop(m_box).resize(g_band.size, Image.LANCZOS)
    score, overlay = ssim_overlay(g_band, m_band)
    area = (g_box[2] - g_box[0]) * (g_box[3] - g_box[1])
    return score, overlay, area, g_box

def main():
    results = {}
    for theme in THEMES:
        for ratio in RATIOS:
            key = f"{theme}__{ratio}"
            game_path = f"{BASE}/{key}__game.png"
            mock_path = f"{BASE}/{key}__mockup.png"
            game_im = Image.open(game_path).convert("RGB")
            mock_im = Image.open(mock_path).convert("RGB")

            # --- (A) full-content SSIM ---
            mock_resized = mock_im.resize(game_im.size, Image.LANCZOS)
            full_score, full_overlay = ssim_overlay(game_im, mock_resized)

            # --- (B) GUI-only SSIM (masked board, top+bottom bands) ---
            grect = GAME_RECTS[ratio][theme]
            mrect = MOCK_RECTS[ratio][theme]
            top_score, top_overlay, top_area, top_box = band_score(game_im, mock_im, grect, mrect, "top")
            bot_score, bot_overlay, bot_area, bot_box = band_score(game_im, mock_im, grect, mrect, "bot")
            gui_score = (top_score * top_area + bot_score * bot_area) / (top_area + bot_area)

            # gui_diff composite: game image with top/bottom bands replaced by their overlays,
            # board region grayed out and labeled
            gui_diff = game_im.copy()
            gui_diff.paste(top_overlay, (top_box[0], top_box[1]))
            gui_diff.paste(bot_overlay, (bot_box[0], bot_box[1]))
            gx, gy, gw, gh = grect
            draw = ImageDraw.Draw(gui_diff)
            draw.rectangle([gx, gy, gx + gw, gy + gh], fill=(60, 60, 60))
            label = "board excluded from gate"
            draw.text((gx + 10, gy + gh // 2), label, fill=(230, 230, 230))

            out_dir = f"{OUT_ROOT}/{theme}"
            os.makedirs(out_dir, exist_ok=True)
            game_im.save(f"{out_dir}/{ratio}__game.png")
            mock_im.save(f"{out_dir}/{ratio}__mockup.png")
            full_overlay.save(f"{out_dir}/{ratio}__diff.png")
            gui_diff.save(f"{out_dir}/{ratio}__gui_diff.png")

            results[key] = {
                "full": full_score,
                "gui": gui_score,
                "top": top_score,
                "bot": bot_score,
                "top_area": top_area,
                "bot_area": bot_area,
                "game_size": list(game_im.size),
                "mock_size": list(mock_im.size),
            }
            print(f"{key}: full={full_score:.2f}  gui={gui_score:.2f} (top={top_score:.2f} bot={bot_score:.2f})")

    with open(f"{BASE}/final_scores_v2.json", "w") as f:
        json.dump(results, f, indent=1)

if __name__ == "__main__":
    main()
