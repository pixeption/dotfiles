"""img-diff skill — score()/table() on synthetic images. No editor, no browser.

    python3 -m pytest ~/.claude/skills/img-diff/scripts/test_parity_shot.py
"""
import importlib.util
import os
import sys

import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import score  # noqa: E402

def load_parity_shot():
    """The script's filename has a hyphen, so it is loaded by path rather than imported."""
    spec = importlib.util.spec_from_file_location(
        "parity_shot", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parity-shot.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


parity_shot = load_parity_shot()

MASK = (10, 10, 40, 40)


def write(path, changed_region=None):
    pixels = np.full((80, 80, 3), 200, dtype=np.uint8)
    pixels[60:70, 5:75] = (20, 40, 90)
    if changed_region:
        x, y, w, h = changed_region
        pixels[y:y + h, x:x + w] = (255, 0, 0)
    Image.fromarray(pixels).save(path)
    return str(path)


def test_identical_images_score_100(tmp_path):
    a = write(tmp_path / "a.png")
    b = write(tmp_path / "b.png")
    assert score(a, b)["ssim"] == pytest.approx(100.0, abs=1e-6)


def test_masking_the_only_changed_region_restores_a_perfect_score(tmp_path):
    a = write(tmp_path / "a.png")
    b = write(tmp_path / "b.png", changed_region=MASK)

    assert score(a, b)["ssim"] < 100.0
    assert score(a, b, mask=MASK)["ssim"] == pytest.approx(100.0, abs=1e-6)


def test_score_writes_the_overlay_and_heat_diagnostics(tmp_path):
    a = write(tmp_path / "a.png")
    b = write(tmp_path / "b.png", changed_region=MASK)

    result = score(a, b, str(tmp_path / "pair"))

    assert os.path.exists(result["overlay"]) and os.path.exists(result["heat"])


def test_table_marks_each_pair_against_the_gate():
    rows = [
        {"pair": "paper__9x16", "ssim": 96.0, "masked": None, "note": "native"},
        {"pair": "zen__3x4", "ssim": 90.0, "masked": 97.5, "note": "RESIZED (sizes differ)"},
    ]

    lines = parity_shot.table(rows, gate=0.95).splitlines()

    assert lines[0].split() == ["pair", "ssim", "masked", "gate", "note"]
    assert "PASS" in lines[1] and "96.00" in lines[1]
    # The masked score is the one gated when a mask is given.
    assert "PASS" in lines[2] and "97.50" in lines[2]
