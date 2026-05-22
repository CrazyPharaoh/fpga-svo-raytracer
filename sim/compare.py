#!/usr/bin/env python3
# sim/compare.py
# Compare hardware_render.png against reference_render.png.
# Reports per-pixel match rate and saves a diff image.

import os
import re
import sys
import numpy as np
from PIL import Image

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'output')
HW_PATH    = os.path.join(OUTPUT_DIR, 'hardware_render.png')
REF_PATH   = os.path.join(OUTPUT_DIR, 'reference_render.png')
DIFF_PATH  = os.path.join(OUTPUT_DIR, 'diff.png')

THRESHOLD  = 0.95   # pass if ≥ 95% pixels match


def write_mismatch_log(trace_path, mismatch_set, out_path, hw, ref):
    """
    DEBUG — stream-parse pixel_trace.txt and write only the traces for pixels
    in mismatch_set to out_path. mismatch_set is a set of (px, py) tuples.

    For each mismatched pixel the header is annotated with the hw vs ref result.
    hw and ref are numpy uint8 arrays shaped (H, W, 3).

    Remove this function and its call in main() when debug logging is done.
    """
    if not os.path.exists(trace_path):
        print(f"  (mismatch log skipped: {trace_path} not found)")
        return

    _d = os.path.dirname(out_path)
    if _d:
        os.makedirs(_d, exist_ok=True)

    SEP      = '=' * 80
    pixel_re = re.compile(r'^PIXEL \(px=(\d+), py=(\d+)\)$')

    written  = 0
    cur_px = cur_py = -1
    in_target = False
    buf = []

    def flush(f_out):
        nonlocal written
        if in_target and buf:
            f_out.write('\n')
            for bl in buf:
                f_out.write(bl)
            written += 1

    with open(trace_path, 'r') as f_in, open(out_path, 'w') as f_out:
        for raw_line in f_in:
            line = raw_line.rstrip('\n')

            m = pixel_re.match(line)
            if m:
                # New pixel block starting — flush previous if it was a mismatch
                flush(f_out)

                cur_px, cur_py = int(m.group(1)), int(m.group(2))
                in_target = (cur_px, cur_py) in mismatch_set
                buf = []

                if in_target:
                    hw_pix  = hw[cur_py, cur_px]
                    ref_pix = ref[cur_py, cur_px]
                    hw_type  = "HIT"  if tuple(hw_pix)  == (255, 255, 255) else "MISS"
                    ref_type = "HIT"  if tuple(ref_pix)  == (255, 255, 255) else "MISS"
                    hw_rgb   = f"({hw_pix[0]},{hw_pix[1]},{hw_pix[2]})"
                    ref_rgb  = f"({ref_pix[0]},{ref_pix[1]},{ref_pix[2]})"
                    buf.append(SEP + '\n')
                    buf.append(
                        f"PIXEL (px={cur_px}, py={cur_py})  "
                        f"[MISMATCH: hw={hw_type}{hw_rgb}, ref={ref_type}{ref_rgb}]\n"
                    )
                    buf.append(SEP + '\n')
            elif in_target:
                buf.append(raw_line)

        # Flush the very last pixel
        flush(f_out)

    print(f"Mismatch log: {out_path}  ({written} pixels written)")


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

    # DEBUG: write mismatch trace log if pixel_trace.txt exists.
    # Remove this block when pixel_tracer is removed from tb_svo_traversal.py.
    LOGS_DIR      = os.path.join(OUTPUT_DIR, 'logs')
    TRACE_PATH    = os.path.join(LOGS_DIR, 'pixel_trace.txt')
    MISMATCH_PATH = os.path.join(LOGS_DIR, 'mismatch_trace.txt')
    # np.where(~match) → (py_indices, px_indices)
    py_arr, px_arr = np.where(~match)
    mismatch_coords = set(zip(px_arr.tolist(), py_arr.tolist()))
    write_mismatch_log(TRACE_PATH, mismatch_coords, MISMATCH_PATH, hw, ref)

    if pct >= THRESHOLD * 100:
        print(f"\nPASS  ({pct:.2f}% ≥ {THRESHOLD*100:.0f}%)")
        sys.exit(0)
    else:
        print(f"\nFAIL  ({pct:.2f}% < {THRESHOLD*100:.0f}%)")
        sys.exit(1)


if __name__ == '__main__':
    main()
