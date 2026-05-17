#!/usr/bin/env python3
# host/display_frame.py
# Render one frame using the SVO ray tracer and read it back via VDMA.
# Run on the PYNQ board: sudo /usr/local/share/pynq-venv/bin/python3 display_frame.py

import time
import math
import numpy as np
import PIL.Image
from pynq import Overlay
from pynq.lib.video import common
import svo_builder

BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'
IMG_W, IMG_H = 320, 240


def to_q16(f):
    return int(f * 65536) & 0xFFFF_FFFF


def pack_rgb(r, g, b):
    return ((int(r) & 0xFF) << 16) | ((int(g) & 0xFF) << 8) | (int(b) & 0xFF)


def normalise(v):
    l = math.sqrt(sum(x**2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


# ---------------------------------------------------------------------------
# Load overlay
# ---------------------------------------------------------------------------
print("Loading bitstream …")
ol = Overlay(BITSTREAM)
ip = ol.top_0

# ---------------------------------------------------------------------------
# Configure VDMA — S2MM (stream-to-memory = write channel)
# PYNQ names it writechannel because the DMA is writing frames into memory.
# ---------------------------------------------------------------------------
vdma = ol.axi_vdma_0
videoMode = common.VideoMode(IMG_W, IMG_H, 32)   # 32 bpp XRGB
vdma.writechannel.mode = videoMode
vdma.writechannel.start()

# ---------------------------------------------------------------------------
# Build and upload SVO
# ---------------------------------------------------------------------------
print("Building SVO …")
grid  = svo_builder.build_world()
root  = svo_builder.build_svo(grid)
nodes = svo_builder.flatten_svo(root)
words = svo_builder.serialise_nodes(nodes)
print(f"  {len(nodes)} nodes → {len(words)} words")

ip.write(0x48, 0)
for w in words:
    ip.write(0x4C, w)

# ---------------------------------------------------------------------------
# Colour / fog registers
# ---------------------------------------------------------------------------
ip.write(0x50, pack_rgb(  0,   0,   0))
ip.write(0x54, pack_rgb(128, 128, 128))
ip.write(0x58, pack_rgb( 60, 160,  40))
ip.write(0x5C, pack_rgb(255, 220,  80))
ip.write(0x60, pack_rgb(  0,   0,   0))
ip.write(0x64, pack_rgb(  0,   0,   0))
ip.write(0x68, pack_rgb(135, 206, 235))  # sky colour
ip.write(0x6C, pack_rgb(180, 200, 220))
ip.write(0x70, to_q16(15.0))
ip.write(0x74, to_q16(0.01))

# ---------------------------------------------------------------------------
# Camera (same as main_phase1.py)
# ---------------------------------------------------------------------------
pos   = [32.0, 40.0, -20.0]
fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
right = normalise(cross(fwd, [0, 1, 0]))
up    = cross(right, fwd)
fov_scale = math.tan(math.radians(60) / 2) / (IMG_W / 2)
ip.write(0x38, to_q16(fov_scale))
for offset, val in zip(range(0x08, 0x38, 4), pos + right + up + fwd):
    ip.write(offset, to_q16(val))
ld = normalise([0.5, -0.7, 0.5])
ip.write(0x3C, to_q16(ld[0]))
ip.write(0x40, to_q16(ld[1]))
ip.write(0x44, to_q16(ld[2]))

# ---------------------------------------------------------------------------
# Trigger render and wait for busy→0
# ---------------------------------------------------------------------------
print("Triggering render …")
t0 = time.time()
ip.write(0x00, 1)
while ip.read(0x04) & 0x1:
    time.sleep(0.001)
elapsed = time.time() - t0
print(f"Render complete in {elapsed:.3f} s")

# ---------------------------------------------------------------------------
# Read frame from VDMA
# readframe() returns (IMG_H, IMG_W, 4) uint8 — channel order [B, G, R, 0]
# because VDMA stores 32-bit XRGB little-endian in memory.
# ---------------------------------------------------------------------------
frame_raw = vdma.writechannel.readframe()
frame_rgb = frame_raw[:, :, [2, 1, 0]]   # BGR → RGB, drop padding byte

image = PIL.Image.fromarray(frame_rgb, 'RGB')
image.save('/tmp/render_output.png')
print("Saved to /tmp/render_output.png")

vdma.writechannel.stop()
