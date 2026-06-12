#!/usr/bin/env python3
# host/main_phase1.py — load SVO, set static camera, render one frame (Phase 1: white hits).
# Run on the PYNQ: python3 main_phase1.py

import time
import math
from pynq import Overlay
import svo_builder

BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'


def to_q16(f: float) -> int:
    """Float to Q16.16 unsigned 32-bit."""
    return int(f * 65536) & 0xFFFF_FFFF


def pack_rgb(r: int, g: int, b: int) -> int:
    """Pack RGB into 32-bit: [23:16]=R, [15:8]=G, [7:0]=B."""
    return (int(r) & 0xFF) | ((int(g) & 0xFF) << 8) | ((int(b) & 0xFF) << 16)


def normalise(v):
    l = math.sqrt(sum(x ** 2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


print("Loading bitstream …")
ol = Overlay(BITSTREAM)
ip = ol.top_0

print("Building world …")
grid  = svo_builder.build_world()
print("Building SVO …")
root  = svo_builder.build_svo(grid)
nodes = svo_builder.flatten_svo(root)
words = svo_builder.serialise_nodes(nodes)
print(f"  {len(nodes)} nodes → {len(words)} 32-bit words")

print("Loading SVO into BRAM …")
ip.write(0x48, 0)            # SVO_ADDR = 0
for w in words:
    ip.write(0x4C, w)        # SVO_DATA (auto-increments address)

# LUT (block IDs 0–5), sky, fog, shadow bias
ip.write(0x50, pack_rgb(  0,   0,   0))   # LUT[0] air (unused)
ip.write(0x54, pack_rgb(128, 128, 128))   # LUT[1] stone
ip.write(0x58, pack_rgb( 60, 160,  40))   # LUT[2] grass
ip.write(0x5C, pack_rgb(255, 220,  80))   # LUT[3] glowing
ip.write(0x60, pack_rgb(  0,   0,   0))   # LUT[4] spare
ip.write(0x64, pack_rgb(  0,   0,   0))   # LUT[5] spare
ip.write(0x68, pack_rgb(135, 206, 235))   # sky
ip.write(0x6C, pack_rgb(180, 200, 220))   # fog
ip.write(0x70, to_q16(15.0))
ip.write(0x74, to_q16(0.01))              # shadow_bias

# Camera: looking from (32,40,-20) toward (32,4,32), 60° FOV
pos = [32.0, 40.0, -20.0]
fwd = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
right = normalise(cross(fwd, [0, 1, 0]))
up    = cross(right, fwd)

fov_scale = math.tan(math.radians(60) / 2) / 160   # tan(FOV/2) / (IMG_W/2)
ip.write(0x38, to_q16(fov_scale))

for offset, val in zip(range(0x08, 0x38, 4), pos + right + up + fwd):
    ip.write(offset, to_q16(val))

ld = normalise([0.5, -0.7, 0.5])
ip.write(0x3C, to_q16(ld[0]))
ip.write(0x40, to_q16(ld[1]))
ip.write(0x44, to_q16(ld[2]))

print("Triggering render …")
t0 = time.time()
ip.write(0x00, 1)

while not (ip.read(0x04) & 0x2):   # poll STATUS.frame_done
    time.sleep(0.005)

elapsed = time.time() - t0
print(f"Frame rendered in {elapsed:.3f} s  ({1/elapsed:.2f} FPS)")
print("HDMI output: white voxels on sky-blue background (Phase 1 — no shading).")
print("If the screen is blank: check HDMI cable, set monitor to 640×480 input.")
