#!/usr/bin/env python3
# sim/compare.py
# Compare hardware_render.png against reference_render.png.
# Reports per-pixel match rate and saves a diff image.

import os
import sys
import numpy as np
from PIL import Image

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'output')
HW_PATH    = os.path.join(OUTPUT_DIR, 'hardware_render.png')
REF_PATH   = os.path.join(OUTPUT_DIR, 'reference_render.png')
DIFF_PATH  = os.path.join(OUTPUT_DIR, 'diff.png')

THRESHOLD  = 0.95   # pass if ≥ 95% pixels match


def main():
    for p in (HW_PATH, REF_PATH):
        if not os.path.exists(p):
            print(f"ERROR: {p} not found — run the simulation and gen_reference.py first")
            sys.exit(1)

    hw  = np.array(Image.open(HW_PATH).convert('RGB'))
    ref = np.array(Image.open(REF_PATH).convert('RGB'))

    if hw.shape != ref.shape:
        print(f"ERROR: shape mismatch: hw={hw.shape}, ref={ref.shape}")
        sys.exit(1)

    H, W = hw.shape[:2]
    total = H * W

    match      = np.all(hw == ref, axis=2)
    n_match    = int(match.sum())
    n_mismatch = total - n_match
    pct        = n_match / total * 100

    print(f"Resolution : {W}×{H}  ({total} pixels)")
    print(f"Match      : {n_match}  ({pct:.2f}%)")
    print(f"Mismatch   : {n_mismatch}  ({100-pct:.2f}%)")

    # Break down mismatch types
    hw_hit  = np.all(hw  == [255,255,255], axis=2)
    ref_hit = np.all(ref == [255,255,255], axis=2)
    false_hit  = int((hw_hit  & ~ref_hit).sum())
    false_miss = int((~hw_hit &  ref_hit).sum())
    print(f"  False hits (hw=white, ref=sky): {false_hit}")
    print(f"  False miss (hw=sky, ref=white): {false_miss}")

    # Save diff image: green=match, red=hw extra hit, blue=ref extra hit
    diff = np.zeros((H, W, 3), dtype=np.uint8)
    diff[match]              = [0, 200, 0]    # green: correct
    diff[hw_hit & ~ref_hit]  = [255, 0, 0]   # red:   false hit
    diff[~hw_hit & ref_hit]  = [0, 0, 255]   # blue:  false miss
    Image.fromarray(diff, 'RGB').save(DIFF_PATH)
    print(f"Diff image : {DIFF_PATH}")

    if pct >= THRESHOLD * 100:
        print(f"\nPASS  ({pct:.2f}% ≥ {THRESHOLD*100:.0f}%)")
        sys.exit(0)
    else:
        print(f"\nFAIL  ({pct:.2f}% < {THRESHOLD*100:.0f}%)")
        sys.exit(1)


if __name__ == '__main__':
    main()
