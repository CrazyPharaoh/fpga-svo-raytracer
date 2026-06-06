#!/usr/bin/env python3
# sim/gen_reference_shaded.py
# Generate a shaded reference PNG matching the hardware shading_pipeline.sv algorithm.
# Constants are taken directly from shading_pipeline.sv to match hardware behaviour.
# Output: sim/output/reference_render_shaded.png

import sys, os, math
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'host'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'hardware_ref'))
import svo_builder
import fpga_svo_raytracer as ref

# Fast-sim crop: must match tb_svo_full.py / the -GIMG_W shade build (Makefile.shade).
RENDER_DIV   = int(os.environ.get('RENDER_DIV', '1'))
IMG_W, IMG_H = 320 // RENDER_DIV, 240 // RENDER_DIV

# ─── Constants from shading_pipeline.sv ──────────────────────────────────────
AMBIENT      = 6554 / 65536.0        # 32'h0000_199A / 65536
FOG_INV_RANGE = 916 / 65536.0        # 32'h0000_0394 / 65536  (≈1/71.5 units)
FOG_START    = 15.0                  # matches tb_svo_full.py

_LM = math.sqrt(1.0**2 + 2.0**2 + 1.5**2)
LIGHT_DIR = (1.0/_LM, 2.0/_LM, 1.5/_LM)

SKY_COLOR  = (135, 206, 235)
FOG_COLOR  = (180, 200, 220)

LUT = [
    (0,   0,   0),    # 0 air
    (120, 120, 120),  # 1 stone
    (60,  160,  40),  # 2 grass
    (255,   0,   0),  # 3 glowing (animated rainbow on HW; static here)
    (194, 178, 128),  # 4 sand
    (235, 240, 250),  # 5 snow
]

SHADOW_BIAS = 0.5    # matches tb_svo_full.py
# Shadows ON (DSP budget freed by the shared multiplier banks).
# Must match SHADOW_EN in svo_full_tb.sv / top.sv.
SHADOWS_ENABLED = True


def clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def clamp255(x):
    return 0 if x < 0 else (255 if x > 255 else int(x))


def dot(a, b):
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]


def normalise(v):
    l = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
    return (v[0]/l, v[1]/l, v[2]/l) if l > 1e-9 else v


def normalise_list(v):
    l = math.sqrt(sum(x**2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def shade_pixel(t_hit, hit_pos, face_axis, face_sign, block_id,
                ray_d, svo_nodes, is_miss):
    """Shading algorithm matching shading_pipeline.sv (post >> 8 fix)."""

    if is_miss:
        return SKY_COLOR

    # ── S_NORMAL ──────────────────────────────────────────────────────────────
    normal = [0.0, 0.0, 0.0]
    normal[face_axis] = float(face_sign)   # face_sign from traversal: ±1 integer

    base = LUT[min(block_id, 5)]
    # XOR checkerboard texture (matches shading_pipeline.sv): 0.75x base on alternating
    # unit cells. pattern = LSB of each integer hit coord XORed (HW uses Q16.16 bit 16).
    ix, iy, iz = int(hit_pos[0]), int(hit_pos[1]), int(hit_pos[2])
    if ((ix ^ iy ^ iz) & 1) == 0:
        base = tuple(c - (c >> 3) for c in base)   # subtle ~12% darken

    # ── S_DIFFSPEC ────────────────────────────────────────────────────────────
    d = dot(normal, LIGHT_DIR)
    diffuse = clamp01(d)

    dot_ln = dot(LIGHT_DIR, normal)
    rx = LIGHT_DIR[0] - 2.0 * dot_ln * normal[0]
    ry = LIGHT_DIR[1] - 2.0 * dot_ln * normal[1]
    rz = LIGHT_DIR[2] - 2.0 * dot_ln * normal[2]
    dot_rv = rx * ray_d[0] + ry * ray_d[1] + rz * ray_d[2]
    s = clamp01(-dot_rv)
    s = s * s          # ^2
    spec = s * s       # ^4  (spec ∈ [0,1])

    # Shadow ray: hit_pos + normal * SHADOW_BIAS → LIGHT_DIR
    if SHADOWS_ENABLED:
        sx = hit_pos[0] + normal[0] * SHADOW_BIAS
        sy = hit_pos[1] + normal[1] * SHADOW_BIAS
        sz = hit_pos[2] + normal[2] * SHADOW_BIAS
        shadow_hit = ref.svo_traverse(sx, sy, sz,
                                      LIGHT_DIR[0], LIGHT_DIR[1], LIGHT_DIR[2],
                                      svo_nodes, shadow_mode=True)
    else:
        shadow_hit = False

    # ── S_COMBINE ─────────────────────────────────────────────────────────────
    # direct = shadowed ? AMBIENT : clamp(diffuse + AMBIENT)
    direct = AMBIENT if shadow_hit else clamp01(diffuse + AMBIENT)

    # r_ch = base_r * direct  (qmul({16'd0, base_r}, direct) — no >> 8 after fix)
    # spec_add = spec * 256   (spec >> 8 in hardware: spec Q16.16 / 256)
    spec_add = spec * 256.0   # spec ∈ [0,1] → spec_add ∈ [0,256]
    r_ch = clamp255(base[0] * direct + spec_add)
    g_ch = clamp255(base[1] * direct + spec_add)
    b_ch = clamp255(base[2] * direct + spec_add)
    combined = (r_ch, g_ch, b_ch)

    # ── S_FOG ─────────────────────────────────────────────────────────────────
    if t_hit > FOG_START:
        blend = clamp01((t_hit - FOG_START) * FOG_INV_RANGE)
        r_f = clamp255(combined[0] + blend * (FOG_COLOR[0] - combined[0]))
        g_f = clamp255(combined[1] + blend * (FOG_COLOR[1] - combined[1]))
        b_f = clamp255(combined[2] + blend * (FOG_COLOR[2] - combined[2]))
        return (r_f, g_f, b_f)

    return combined


def main():
    print("Building SVO …")
    grid  = svo_builder.build_world()
    root  = svo_builder.build_svo(grid)
    nodes = svo_builder.flatten_svo(root)
    print(f"  {len(nodes)} nodes")

    # Camera — MUST stay identical to tb_svo_full.py for the PNG comparison to mean anything.
    pos   = [48.0095, 16.7627, 27.9686]
    fwd   = [-0.9094, -0.337, 0.2437]
    right = [-0.2588, 0.0, -0.9659]
    up    = [-0.3255, 0.9415, 0.0872]
    fov_scale = math.tan(math.radians(60) / 2) / (IMG_W / 2)

    print("Rendering shaded reference frame …")
    pixels = []
    for py in range(IMG_H):
        for px in range(IMG_W):
            u  = (px - IMG_W / 2) * fov_scale
            v  = (py - IMG_H / 2) * fov_scale
            dx = fwd[0] + u*right[0] - v*up[0]
            dy = fwd[1] + u*right[1] - v*up[1]
            dz = fwd[2] + u*right[2] - v*up[2]
            l  = math.sqrt(dx*dx + dy*dy + dz*dz)
            if l > 1e-9:
                dx /= l; dy /= l; dz /= l

            result = ref.svo_traverse(
                pos[0], pos[1], pos[2],
                dx, dy, dz, nodes, shadow_mode=False
            )
            if result is None:
                pixels.append(SKY_COLOR)
            else:
                t, hit_pos, face_axis, face_sign, block_id = result
                px_color = shade_pixel(
                    t, hit_pos, face_axis, face_sign, block_id,
                    (dx, dy, dz), nodes, is_miss=False
                )
                pixels.append(px_color)
        if py % 40 == 0:
            print(f"  row {py}/{IMG_H}")

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    out_dir = os.path.join(os.path.dirname(__file__), 'output')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'reference_render_shaded.png')
    Image.fromarray(arr, 'RGB').save(out_path)
    print(f"Saved {out_path}")


if __name__ == '__main__':
    main()
