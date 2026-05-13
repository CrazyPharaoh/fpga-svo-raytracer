#!/usr/bin/env python3
# host/main.py
# Phase 3 interactive host: keyboard navigation of the SVO voxel world.
#
# Controls:
#   W / S          Move forward / backward
#   A / D          Strafe left / right
#   Arrow Up/Down  Pitch camera
#   Arrow Left/Right Yaw camera
#   Space          Move up
#   Left Shift     Move down
#   Esc            Quit
#
# Run on the PYNQ board:
#   python3 main.py

import time
import math
import sys

from pynq import Overlay
import evdev
from evdev import ecodes

import svo_builder
from camera import Camera

BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_raytracer.bit'


# ---------------------------------------------------------------------------
# Q16.16 helpers
# ---------------------------------------------------------------------------
def to_q16(f: float) -> int:
    return int(f * 65536) & 0xFFFF_FFFF


def pack_rgb(r: int, g: int, b: int) -> int:
    return (int(r) & 0xFF) | ((int(g) & 0xFF) << 8) | ((int(b) & 0xFF) << 16)


# ---------------------------------------------------------------------------
# Load bitstream
# ---------------------------------------------------------------------------
print("Loading bitstream …")
ol = Overlay(BITSTREAM)
ip = ol.svo_raytracer_0

# ---------------------------------------------------------------------------
# Build world + SVO
# ---------------------------------------------------------------------------
print("Building world and SVO …")
grid  = svo_builder.build_world()
root  = svo_builder.build_svo(grid)
nodes = svo_builder.flatten_svo(root)
words = svo_builder.serialise_nodes(nodes)
print(f"  {len(nodes)} nodes → {len(words)} words")

print("Streaming SVO into BRAM …")
ip.write(0x48, 0)
for w in words:
    ip.write(0x4C, w)

# ---------------------------------------------------------------------------
# Static scene registers
# ---------------------------------------------------------------------------
# Colour LUT (block IDs 0-5)
ip.write(0x50, pack_rgb(  0,   0,   0))   # BLOCK_AIR   (unused)
ip.write(0x54, pack_rgb(128, 128, 128))   # BLOCK_STONE
ip.write(0x58, pack_rgb( 60, 160,  40))   # BLOCK_GRASS
ip.write(0x5C, pack_rgb(255, 220,  80))   # BLOCK_GLOWING (base; pulsed each frame)
ip.write(0x60, pack_rgb(  0,   0,   0))   # spare
ip.write(0x64, pack_rgb(  0,   0,   0))   # spare

ip.write(0x68, pack_rgb(135, 206, 235))   # SKY_COLOR
ip.write(0x6C, pack_rgb(180, 200, 220))   # FOG_COLOR
ip.write(0x70, to_q16(15.0))              # FOG_START
ip.write(0x74, to_q16(0.01))              # SHADOW_BIAS

# Light direction: roughly sun-like (normalised)
ld_raw = [0.5, -0.7, 0.5]
ld_len = math.sqrt(sum(x * x for x in ld_raw))
ld = [x / ld_len for x in ld_raw]
ip.write(0x3C, to_q16(ld[0]))
ip.write(0x40, to_q16(ld[1]))
ip.write(0x44, to_q16(ld[2]))


# ---------------------------------------------------------------------------
# Camera register write helper
# ---------------------------------------------------------------------------
CAM_OFFSETS = [0x08, 0x0C, 0x10,   # pos x y z
               0x14, 0x18, 0x1C,   # right x y z
               0x20, 0x24, 0x28,   # up x y z
               0x2C, 0x30, 0x34]   # fwd x y z


def write_camera(cam: Camera, frame: int = 0) -> None:
    regs = cam.registers()
    ip.write(0x38, to_q16(regs['scale']))
    for offset, val in zip(CAM_OFFSETS,
                           regs['pos'] + regs['right'] + regs['up'] + regs['fwd']):
        ip.write(offset, to_q16(val))
    # Pulse the GLOWING block emissive colour
    pulse = 0.5 + 0.5 * math.sin(frame * 0.2)
    ip.write(0x5C, pack_rgb(int(255 * pulse), int(200 * pulse), int(60 * pulse)))


def trigger_render() -> float:
    """Write CTRL=1 and poll until frame_done. Returns elapsed seconds."""
    t0 = time.time()
    ip.write(0x00, 1)
    while not (ip.read(0x04) & 0x2):
        time.sleep(0.001)
    return time.time() - t0


# ---------------------------------------------------------------------------
# Find USB keyboard
# ---------------------------------------------------------------------------
keyboard = None
for path in evdev.list_devices():
    dev = evdev.InputDevice(path)
    if ecodes.EV_KEY in dev.capabilities():
        keyboard = dev
        print(f"Keyboard: {dev.name}  ({path})")
        break

if keyboard is None:
    print("ERROR: No keyboard found. Plug in a USB keyboard and re-run.")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Render first frame and enter the event loop
# ---------------------------------------------------------------------------
cam   = Camera()
frame = 0

print("Rendering first frame …")
write_camera(cam, frame)
elapsed = trigger_render()
print(f"Frame 0 rendered in {elapsed*1000:.0f} ms  → HDMI output active.")
print("Controls: WASD=move  Arrows=look  Space/Shift=up/down  Esc=quit")

keyboard.grab()
try:
    for event in keyboard.read_loop():
        if event.type != ecodes.EV_KEY or event.value != 1:   # key-down only
            continue
        key = ecodes.KEY[event.code]
        if key == 'KEY_ESC':
            break
        if cam.handle_key(key):
            frame += 1
            write_camera(cam, frame)
            elapsed = trigger_render()
            print(
                f"Frame {frame:4d}  {elapsed*1000:5.0f} ms  "
                f"pos=({cam.pos[0]:.1f}, {cam.pos[1]:.1f}, {cam.pos[2]:.1f})  "
                f"yaw={cam.yaw:.0f}°  pitch={cam.pitch:.0f}°"
            )
finally:
    keyboard.ungrab()
    print("Quit.")
