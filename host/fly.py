#!/usr/bin/env python3
# host/fly.py — live keyboard fly-through of the SVO scene on HDMI.
#
# DEFAULT (no board USB needed): read keys from THIS terminal (web terminal / SSH).
#     python3 fly.py
#   Type WASD/arrows etc. IN the terminal you launched from; watch the HDMI monitor.
#
# evdev mode (USB keyboard on the board, needs root + working board USB host):
#     sudo python3 fly.py --evdev               (auto-find keyboard)
#     sudo python3 fly.py --evdev /dev/input/eventN
#
# Software-only: writes the existing camera registers + triggers render; the HDMI MM2S
# is parked on frame_phys, so each render updates the monitor by itself. ~3 FPS.

import os, glob, struct, select, fcntl, sys, time, math
import numpy as np
from pynq import Overlay, MMIO, allocate, Clocks
import svo_builder, fly_camera

# ── unified actions (both input backends emit these) ──────────────────────────
#   fwd back left right up down  pitchU pitchD yawL yawR  zoomIn zoomOut  quit

# ── backend A: terminal stdin (default; no board USB) ─────────────────────────
import termios, tty
CHAR_ACTION = {'w':'fwd','s':'back','a':'left','d':'right',
               ' ':'up','c':'down','-':'zoomOut','=':'zoomIn','q':'quit'}
ARROW_ACTION = {0x41:'pitchU', 0x42:'pitchD', 0x44:'yawL', 0x43:'yawR'}  # ESC [ A/B/D/C

class StdinKeyboard:
    """Reads the controlling terminal in cbreak mode. Hold-to-move uses the OS key-repeat
    stream (each frame = the set of keys seen since the last poll)."""
    def __init__(self):
        self.fd = sys.stdin.fileno()
        self.old = termios.tcgetattr(self.fd)
        tty.setcbreak(self.fd)            # char-at-a-time, no echo, Ctrl-C still works
    def poll(self):
        acts = set()
        while select.select([self.fd], [], [], 0)[0]:
            data = os.read(self.fd, 64)
            if not data:
                break
            i = 0
            while i < len(data):
                b = data[i]
                if b == 0x1b and i + 2 < len(data) and data[i+1] == 0x5b:   # arrow esc-seq
                    a = ARROW_ACTION.get(data[i+2])
                    if a: acts.add(a)
                    i += 3; continue
                a = CHAR_ACTION.get(chr(b).lower())
                if a: acts.add(a)
                i += 1
        return acts
    def close(self):
        termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old)

# ── backend B: evdev USB keyboard on the board (--evdev) ──────────────────────
EV_KEY = 0x01
EVENT_FMT  = 'llHHi'
EVENT_SIZE = struct.calcsize(EVENT_FMT)          # 16 on 32-bit PYNQ, 24 on 64-bit host
EVIOCGRAB  = 0x40044590
EVDEV_ACTION = {17:'fwd', 31:'back', 30:'left', 32:'right', 57:'up', 42:'down',
                103:'pitchU', 108:'pitchD', 105:'yawL', 106:'yawR',
                16:'zoomOut', 18:'zoomIn', 1:'quit'}

def find_keyboard(override=None, wait=20.0):
    if override:
        return override
    deadline = time.time() + wait
    announced = False
    while True:
        cands = []
        for dev in sorted(glob.glob('/dev/input/event*')):
            node = os.path.basename(dev)
            try: name = open(f'/sys/class/input/{node}/device/name').read().strip()
            except OSError: name = '?'
            try:
                words = open(f'/sys/class/input/{node}/device/capabilities/key').read().split()
                low = int(words[-1], 16)            # KEY_W(17) lives in the lowest word (32/64-bit safe)
                cands.append(f'{dev}  ({name})')
                if low & (1 << 17):
                    print(f'Keyboard: {dev}  ({name})'); return dev
            except (OSError, ValueError):
                pass
        if time.time() > deadline:
            raise RuntimeError('No keyboard found. Candidates:\n  ' + '\n  '.join(cands) +
                               '\nPass it explicitly: sudo python3 fly.py --evdev /dev/input/eventN')
        if not announced:
            print('Waiting for a keyboard — plug it in now ...'); announced = True
        time.sleep(0.5)

class EvdevKeyboard:
    def __init__(self, path):
        self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, EVIOCGRAB, 1)
        self.held = set()
    def poll(self):
        while select.select([self.fd], [], [], 0)[0]:
            data = os.read(self.fd, EVENT_SIZE)
            if not data or len(data) < EVENT_SIZE: break
            _, _, typ, code, value = struct.unpack(EVENT_FMT, data)
            if typ != EV_KEY: continue
            if value == 1: self.held.add(code)
            elif value == 0: self.held.discard(code)
        return {EVDEV_ACTION[c] for c in self.held if c in EVDEV_ACTION}
    def close(self):
        try: fcntl.ioctl(self.fd, EVIOCGRAB, 0)
        except OSError: pass
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
        self._upload_svo(); self._shading(); self._arm_s2mm(); self._arm_mm2s()
    def _upload_svo(self):
        words = svo_builder.serialise_nodes(
            svo_builder.flatten_svo(svo_builder.build_svo(svo_builder.build_world())))
        self.ip.write(0x48, 0)
        for w in words: self.ip.write(0x4C, w)
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

def main(use_evdev=False, device=None):
    fov = math.tan(math.radians(60)/2) / (IMG_W/2)
    cam = fly_camera.Camera.looking_at([32, 40, -20], [32, 4, 32], scale=fov)
    rnd = Renderer()
    if use_evdev:
        kb = EvdevKeyboard(find_keyboard(device))
        print('evdev: type on the BOARD keyboard. WASD move, arrows look, Space/Shift up-down, Q/E zoom, Esc quit')
    else:
        kb = StdinKeyboard()
        print('Type IN THIS TERMINAL: WASD move, arrows look, Space/C up-down, -/= zoom, Q or Ctrl-C quit')
    frames = 0; t0 = time.time()
    try:
        while True:
            h = kb.poll()
            if 'quit' in h:
                break
            fwd  = ('fwd' in h)  - ('back' in h)
            strf = ('right' in h) - ('left' in h)
            vert = ('up' in h)   - ('down' in h)
            if fwd or strf or vert:
                cam.move(MOVE*fwd, MOVE*strf, MOVE*vert)
            dyaw = ('yawL' in h)   - ('yawR' in h)
            dpit = ('pitchU' in h) - ('pitchD' in h)
            if dyaw or dpit:
                cam.look(TURN*dyaw, TURN*dpit)
            if 'zoomOut' in h: cam.scale *= ZOOM
            if 'zoomIn'  in h: cam.scale /= ZOOM
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
    args = sys.argv[1:]
    use_evdev = '--evdev' in args
    args = [a for a in args if a != '--evdev']
    main(use_evdev, args[0] if args else None)
