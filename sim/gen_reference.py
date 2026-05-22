#!/usr/bin/env python3
# sim/gen_reference.py
# Generate a reference PNG using the Python SVO traversal with the exact same
# camera / ray formula as the hardware testbench (tb_svo_traversal.py).
# Output: sim/output/reference_render.png  (white=hit, sky-blue=miss)

import sys, os, math
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'host'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'hardware_ref'))
import svo_builder
import fpga_svo_raytracer as ref

IMG_W, IMG_H = 320, 240
SKY_COLOR    = (135, 206, 235)
HIT_COLOR    = (255, 255, 255)


def normalise(v):
    l = math.sqrt(sum(x**2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def main():
    print("Building SVO …")
    grid  = svo_builder.build_world()
    root  = svo_builder.build_svo(grid)
    nodes = svo_builder.flatten_svo(root)
    print(f"  {len(nodes)} nodes")

    # Camera — identical to testbench
    pos   = [40, 60, 10]
    fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
    right = normalise(cross(fwd, [0, 1, 0]))
    up    = cross(right, fwd)
    fov_scale = math.tan(math.radians(60) / 2) / 160.0

    print("Rendering reference frame …")
    pixels = []
    for py in range(IMG_H):
        for px in range(IMG_W):
            # Exact same ray formula as hardware S_RAY_SETUP
            u  = (px - 160) * fov_scale
            v  = (py - 120) * fov_scale
            dx = fwd[0] + u*right[0] - v*up[0]
            dy = fwd[1] + u*right[1] - v*up[1]
            dz = fwd[2] + u*right[2] - v*up[2]
            l  = math.sqrt(dx*dx + dy*dy + dz*dz)
            if l > 1e-9:
                dx /= l; dy /= l; dz /= l

            result = ref.svo_traverse(
                pos[0], pos[1], pos[2],
                dx, dy, dz,
                nodes, shadow_mode=False
            )
            pixels.append(HIT_COLOR if result is not None else SKY_COLOR)

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    out_dir = os.path.join(os.path.dirname(__file__), 'output')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'reference_render.png')
    Image.fromarray(arr, 'RGB').save(out_path)
    print(f"Saved {out_path}")

    hits  = sum(1 for p in pixels if p == HIT_COLOR)
    total = IMG_W * IMG_H
    print(f"  {hits} hit pixels ({100*hits/total:.1f}%),  {total-hits} sky pixels")


if __name__ == '__main__':
    main()
