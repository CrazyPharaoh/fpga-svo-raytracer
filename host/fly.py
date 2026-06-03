#!/usr/bin/env python3
# host/fly.py — live keyboard fly-through of the SVO scene on HDMI.
# Run on the PYNQ as root, with a USB keyboard on the board and a monitor on HDMI OUT:
#     sudo python3 fly.py            (auto-finds the keyboard)
#     sudo python3 fly.py /dev/input/eventN   (explicit device)
# Controls: WASD move, Space/LeftShift up/down, arrows look, Q/E zoom, Esc quit.
# Software-only: writes the existing camera registers + triggers render; the HDMI MM2S
# is parked on frame_phys, so each render updates the monitor by itself. ~3 FPS.

import os, glob, struct, select, fcntl, sys, time, math
import numpy as np
from pynq import Overlay, MMIO, allocate, Clocks
import svo_builder, fly_camera

# ── keyboard (evdev, no extra deps) ───────────────────────────────────────────
EV_KEY     = 0x01
EVENT_FMT  = 'llHHi'                        # time_sec,time_usec,type,code,value
EVENT_SIZE = struct.calcsize(EVENT_FMT)     # 16 on the 32-bit PYNQ, 24 on a 64-bit host
EVIOCGRAB  = 0x40044590                     # _IOW('E',0x90,int)
KEY = dict(W=17, A=30, S=31, D=32, SPACE=57, LSHIFT=42, Q=16, E=18,
           UP=103, DOWN=108, LEFT=105, RIGHT=106, ESC=1)

def find_keyboard(override=None):
    if override:
        return override
    cands = []
    for dev in sorted(glob.glob('/dev/input/event*')):
        node = os.path.basename(dev)
        try:
            name = open(f'/sys/class/input/{node}/device/name').read().strip()
        except OSError:
            name = '?'
        try:
            words = open(f'/sys/class/input/{node}/device/capabilities/key').read().split()
            # last word = key-capability bits 0..W-1; KEY_W(17) lives there regardless of
            # 32- vs 64-bit kernel word size, so this works on the 32-bit PYNQ.
            low = int(words[-1], 16)
            cands.append(f'{dev}  ({name})')
            if low & (1 << KEY['W']):
                print(f'Keyboard: {dev}  ({name})')
                return dev
        except (OSError, ValueError):
            pass
    raise RuntimeError('No keyboard found. Candidates:\n  ' + '\n  '.join(cands) +
                       '\nPass the device explicitly: sudo python3 fly.py /dev/input/eventN')

class Keyboard:
    def __init__(self, path):
        self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, EVIOCGRAB, 1)          # grab exclusively (don't leak to console)
        self.held = set()
    def poll(self):
        """Drain pending events, update the held-key set, return it."""
        while select.select([self.fd], [], [], 0)[0]:
            data = os.read(self.fd, EVENT_SIZE)
            if not data or len(data) < EVENT_SIZE:
                break
            _, _, typ, code, value = struct.unpack(EVENT_FMT, data)
            if typ != EV_KEY:
                continue
            if value == 1:                          # down
                self.held.add(code)
            elif value == 0:                        # up (value==2 is auto-repeat: ignore)
                self.held.discard(code)
        return self.held
    def close(self):
        try:
            fcntl.ioctl(self.fd, EVIOCGRAB, 0)
        except OSError:
            pass
        os.close(self.fd)

# ── hardware (mirrors hdmi_display.py) ────────────────────────────────────────
BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'
IMG_W, IMG_H, BPP = 320, 240, 4
HSIZE = STRIDE = IMG_W * BPP
def to_q16(f):       return int(f * 65536) & 0xFFFFFFFF
def pack_rgb(r,g,b): return ((int(r)&0xFF)<<16)|((int(g)&0xFF)<<8)|(int(b)&0xFF)

class Renderer:
    def __init__(self):
        Clocks.fclk0_mhz = 100
        self.ol = Overlay(BITSTREAM); self.ip = self.ol.top_0
        base = self.ol.ip_dict['axi_vdma_0']['phys_addr']
        self.vdma = MMIO(base, 0x1000); self.mm2s = MMIO(base, 0x100)
        self.buf  = allocate(shape=(IMG_H, IMG_W, BPP), dtype=np.uint8)
        self.phys = self.buf.physical_address
        self._upload_svo(); self._shading()
        self._arm_s2mm(); self._arm_mm2s()          # MM2S park-arm once at startup

    def _upload_svo(self):
        words = svo_builder.serialise_nodes(
            svo_builder.flatten_svo(svo_builder.build_svo(svo_builder.build_world())))
        self.ip.write(0x48, 0)
        for w in words:
            self.ip.write(0x4C, w)

    def _shading(self):
        lm = math.sqrt(1 + 4 + 2.25); ld = (1/lm, 2/lm, 1.5/lm)
        self.ip.write(0x3C, to_q16(ld[0])); self.ip.write(0x40, to_q16(ld[1])); self.ip.write(0x44, to_q16(ld[2]))
        for i, (r, g, b) in enumerate([(0,0,0),(120,120,120),(60,160,40),(255,0,0),(0,0,0),(0,0,0)]):
            self.ip.write(0x50 + i*4, pack_rgb(r, g, b))
        self.ip.write(0x68, pack_rgb(135,206,235)); self.ip.write(0x6C, pack_rgb(180,200,220))
        self.ip.write(0x70, to_q16(15.0)); self.ip.write(0x74, to_q16(0.5))

    def _arm_s2mm(self):
        self.vdma.write(0x30, 0x4)
        while self.vdma.read(0x30) & 0x4: pass
        for o in (0xAC, 0xB0, 0xB4): self.vdma.write(o, self.phys)
        self.vdma.write(0xA8, STRIDE); self.vdma.write(0xA4, HSIZE)
        self.vdma.write(0x30, 0x3); self.vdma.write(0xA0, IMG_H)

    def _arm_mm2s(self):
        self.mm2s.write(0x00, 0x4)
        while self.mm2s.read(0x00) & 0x4: pass
        for o in (0x5C, 0x60, 0x64): self.mm2s.write(o, self.phys)
        self.mm2s.write(0x28, 0x0); self.mm2s.write(0x58, STRIDE); self.mm2s.write(0x54, HSIZE)
        self.mm2s.write(0x00, 0x1); self.mm2s.write(0x50, IMG_H)

    def set_camera(self, cam):
        fwd, right, up = cam.vectors()
        self.ip.write(0x08, to_q16(cam.pos[0])); self.ip.write(0x0C, to_q16(cam.pos[1])); self.ip.write(0x10, to_q16(cam.pos[2]))
        self.ip.write(0x14, to_q16(right[0]));   self.ip.write(0x18, to_q16(right[1]));   self.ip.write(0x1C, to_q16(right[2]))
        self.ip.write(0x20, to_q16(up[0]));      self.ip.write(0x24, to_q16(up[1]));      self.ip.write(0x28, to_q16(up[2]))
        self.ip.write(0x2C, to_q16(fwd[0]));     self.ip.write(0x30, to_q16(fwd[1]));     self.ip.write(0x34, to_q16(fwd[2]))
        self.ip.write(0x38, to_q16(cam.scale))

    def render(self, timeout=2.0):
        self._arm_s2mm()
        t0 = time.time(); self.ip.write(0x00, 1)
        while not (self.ip.read(0x04) & 0x1):
            if time.time() - t0 > 0.5: return False
        while self.ip.read(0x04) & 0x1:
            if time.time() - t0 > timeout: return False
        return True

    def stop(self):
        self.vdma.write(0x30, 0x0)
        try: self.buf.freebuffer()
        except Exception: pass

# ── main loop ─────────────────────────────────────────────────────────────────
MOVE = 1.5                   # world-units per frame
TURN = math.radians(5)       # radians per frame
ZOOM = 1.05                  # FOV scale multiplier per frame

def main(device=None):
    fov = math.tan(math.radians(60)/2) / (IMG_W/2)
    cam = fly_camera.Camera.looking_at([32, 40, -20], [32, 4, 32], scale=fov)
    rnd = Renderer()
    kb  = Keyboard(find_keyboard(device))
    print('Fly: WASD move, Space/Shift up-down, arrows look, Q/E zoom, Esc quit')
    frames = 0; t0 = time.time()
    try:
        while True:
            h = kb.poll()
            if KEY['ESC'] in h:
                break
            fwd  = (KEY['W'] in h) - (KEY['S'] in h)
            strf = (KEY['D'] in h) - (KEY['A'] in h)
            vert = (KEY['SPACE'] in h) - (KEY['LSHIFT'] in h)
            if fwd or strf or vert:
                cam.move(MOVE*fwd, MOVE*strf, MOVE*vert)
            dyaw = (KEY['LEFT'] in h) - (KEY['RIGHT'] in h)
            dpit = (KEY['UP'] in h) - (KEY['DOWN'] in h)
            if dyaw or dpit:
                cam.look(TURN*dyaw, TURN*dpit)
            if KEY['Q'] in h: cam.scale *= ZOOM
            if KEY['E'] in h: cam.scale /= ZOOM
            rnd.set_camera(cam)
            if not rnd.render():
                print('  (render timeout)')
            frames += 1
    except KeyboardInterrupt:
        pass
    finally:
        kb.close(); rnd.stop()
        dt = time.time() - t0
        print(f'\nstopped. {frames} frames in {dt:.1f}s ({frames/dt:.1f} FPS)' if dt > 0 else '\nstopped.')

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
