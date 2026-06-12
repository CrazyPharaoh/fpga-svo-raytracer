#!/usr/bin/env python3
# sim/compare_shaded.py
# Compare hardware_render_shaded.png against reference_render_shaded.png.
# Uses per-channel tolerance (±TOLERANCE) to account for Q16.16 rounding.
# Writes mismatch_trace_shaded.txt by filtering pixel_trace_shaded.txt.

import os, re, sys
import numpy as np
from PIL import Image

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'output')
HW_PATH    = os.path.join(OUTPUT_DIR, 'hardware_render_shaded.png')
REF_PATH   = os.path.join(OUTPUT_DIR, 'reference_render_shaded.png')
DIFF_PATH  = os.path.join(OUTPUT_DIR, 'diff_shaded.png')
LOGS_DIR   = os.path.join(OUTPUT_DIR, 'logs')
TRACE_PATH = os.path.join(LOGS_DIR, 'pixel_trace_shaded.txt')
MISMATCH_PATH = os.path.join(LOGS_DIR, 'mismatch_trace_shaded.txt')

TOLERANCE  = 5     # per-channel: |hw_ch - ref_ch| <= TOLERANCE → match
THRESHOLD  = 0.95  # pass if ≥ 95% pixels match


def write_mismatch_log(trace_path, mismatch_set, out_path, hw, ref):
    """Filter pixel_trace_shaded.txt to mismatched pixels only, annotating each
    header with hw/ref RGB and per-channel error. mismatch_set: set of (px, py);
    hw, ref: int32 arrays shaped (H, W, 3)."""
    if not os.path.exists(trace_path):
        print(f"  (mismatch log skipped: {trace_path} not found)")
        return

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
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
                flush(f_out)
                cur_px, cur_py = int(m.group(1)), int(m.group(2))
                in_target = (cur_px, cur_py) in mismatch_set
                buf = []
                if in_target:
                    hw_px  = hw[cur_py, cur_px]
                    ref_px = ref[cur_py, cur_px]
                    hw_rgb  = f"({hw_px[0]},{hw_px[1]},{hw_px[2]})"
                    ref_rgb = f"({ref_px[0]},{ref_px[1]},{ref_px[2]})"
                    err_ch  = np.abs(hw_px.astype(int) - ref_px.astype(int))
                    buf.append(SEP + '\n')
                    buf.append(
                        f"PIXEL (px={cur_px}, py={cur_py})  "
                        f"[MISMATCH: hw={hw_rgb}, ref={ref_rgb}, "
                        f"err=({err_ch[0]},{err_ch[1]},{err_ch[2]})]\n"
                    )
                    buf.append(SEP + '\n')
            elif in_target:
                buf.append(raw_line)
        flush(f_out)

    print(f"Mismatch log: {out_path}  ({written} pixels written)")


def main():
    for p in (HW_PATH, REF_PATH):
        if not os.path.exists(p):
            print(f"ERROR: {p} not found")
            sys.exit(1)

    hw  = np.array(Image.open(HW_PATH).convert('RGB'),  dtype=np.int32)
    ref = np.array(Image.open(REF_PATH).convert('RGB'), dtype=np.int32)

    if hw.shape != ref.shape:
        print(f"ERROR: shape mismatch: hw={hw.shape} ref={ref.shape}")
        sys.exit(1)

    H, W   = hw.shape[:2]
    total  = H * W

    diff       = np.abs(hw - ref)
    match      = np.all(diff <= TOLERANCE, axis=2)
    n_match    = int(match.sum())
    n_mismatch = total - n_match
    pct        = n_match / total * 100

    print(f"Resolution  : {W}×{H}  ({total} pixels)")
    print(f"Tolerance   : ±{TOLERANCE} per channel")
    print(f"Match       : {n_match}  ({pct:.2f}%)")
    print(f"Mismatch    : {n_mismatch}  ({100-pct:.2f}%)")
    print(f"Max error   : {int(diff.max())}")
    print(f"Mean error  : {float(diff.mean()):.3f}")

    # Diff image: green=match; red channel intensity = per-pixel max channel error
    diff_img = np.zeros((H, W, 3), dtype=np.uint8)
    diff_img[match] = [0, 200, 0]
    if n_mismatch > 0:
        err_scaled = np.clip(diff.max(axis=2, keepdims=True) * 5, 0, 255).astype(np.uint8)
        diff_img[~match, 0] = err_scaled[~match, 0]   # red channel = error magnitude
    Image.fromarray(diff_img, 'RGB').save(DIFF_PATH)
    print(f"Diff image  : {DIFF_PATH}")

    # Per-pixel mismatch trace log (skipped silently if pixel_trace_shaded.txt absent)
    py_arr, px_arr = np.where(~match)
    mismatch_coords = set(zip(px_arr.tolist(), py_arr.tolist()))
    write_mismatch_log(TRACE_PATH, mismatch_coords, MISMATCH_PATH,
                       hw.astype(np.uint8), ref.astype(np.uint8))

    if pct >= THRESHOLD * 100:
        print(f"\nPASS  ({pct:.2f}% ≥ {THRESHOLD*100:.0f}%)")
        sys.exit(0)
    else:
        print(f"\nFAIL  ({pct:.2f}% < {THRESHOLD*100:.0f}%)")
        sys.exit(1)


if __name__ == '__main__':
    main()
