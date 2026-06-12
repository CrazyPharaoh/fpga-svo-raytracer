#!/usr/bin/env python3
# host/fly.py — live keyboard fly-through with HDMI output.
#
# Default (stdin, no board USB needed):  python3 fly.py
#   Type WASD/arrows in the launch terminal; watch the HDMI monitor.
# evdev (USB keyboard on the board, needs root):
#   sudo python3 fly.py --evdev               (auto-detect keyboard)
#   sudo python3 fly.py --evdev /dev/input/eventN

import os, glob, struct, select, fcntl, sys, time, math, json
import numpy as np
from pynq import Overlay, MMIO, allocate, Clocks
import svo_builder, fly_camera, vox_loader

# ── backend A: terminal stdin ─────────────────────────────────────────────────
import termios, tty
CHAR_ACTION = {'w':'fwd','s':'back','a':'left','d':'right',
               ' ':'up','c':'down','-':'zoomOut','=':'zoomIn','q':'quit','p':'dump',
               'i':'sunUp','k':'sunDown','j':'sunLeft','l':'sunRight','o':'sunOrbit',
               't':'shadowTog','[':'depthDown',']':'depthUp','f':'capture'}
ARROW_ACTION = {0x41:'pitchU', 0x42:'pitchD', 0x44:'yawL', 0x43:'yawR'}  # ESC [ A/B/D/C

class StdinKeyboard:
    """Terminal in cbreak mode; each poll returns keys pressed since last call."""
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
                if b == 0x1b and i + 2 < len(data) and data[i+1] == 0x5b:   # ANSI arrow ESC[A/B/D/C
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
EVENT_SIZE = struct.calcsize(EVENT_FMT)          # 16 bytes on 32-bit PYNQ
EVIOCGRAB  = 0x40044590
EVDEV_ACTION = {17:'fwd', 31:'back', 30:'left', 32:'right', 57:'up', 42:'down',
                103:'pitchU', 108:'pitchD', 105:'yawL', 106:'yawR',
                16:'zoomOut', 18:'zoomIn', 1:'quit',
                23:'sunUp', 37:'sunDown', 36:'sunLeft', 38:'sunRight', 24:'sunOrbit',  # I/K/J/L/O
                20:'shadowTog', 26:'depthDown', 27:'depthUp', 33:'capture'}  # T / [ / ] / F

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
                low = int(words[-1], 16)            # KEY_W(17) is in the lowest capabilities word
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

# ── hardware constants ────────────────────────────────────────────────────────
BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'
IMG_W, IMG_H, BPP = 320, 240, 4
HSIZE = STRIDE = IMG_W * BPP
def to_q16(f):       return int(f * 65536) & 0xFFFFFFFF
def pack_rgb(r,g,b): return ((int(r)&0xFF)<<16)|((int(g)&0xFF)<<8)|(int(b)&0xFF)

# ── scene config ──────────────────────────────────────────────────────────────
# Loaded from scene.json next to this script (or pass a path on the CLI).
# Missing keys fall back to these defaults.
DEFAULT_SCENE = {
    "world": "world.vox",
    "sky_color": [135, 206, 235],
    "fog_color": [180, 200, 220],
    "fog_start": 15.0,
    "shadow_bias": 0.5,
    "light_dir": [1.0, 2.0, 1.5],
    "anim_speed": 1.0,
    "materials": None,   # None -> vox_loader.DEFAULT_MATERIAL_RULES
}

def load_scene(path=None):
    scene = dict(DEFAULT_SCENE)
    if path is None:
        cand = os.path.join(os.path.dirname(__file__), 'scene.json')
        path = cand if os.path.exists(cand) else None
    if path is not None:
        with open(path) as f:
            scene.update(json.load(f))
        print(f'Scene: {path}  (world={scene["world"]})')
    return scene

class Renderer:
    def __init__(self, scene=None):
        self.scene = scene if scene is not None else load_scene()
        Clocks.fclk0_mhz = 100
        self.ol = Overlay(BITSTREAM); self.ip = self.ol.top_0
        base = self.ol.ip_dict['axi_vdma_0']['phys_addr']
        self.vdma = MMIO(base, 0x1000); self.mm2s = MMIO(base, 0x100)
        # Two buffers: render into back, scan out front — no tearing.
        self.bufs = [allocate(shape=(IMG_H, IMG_W, BPP), dtype=np.uint8) for _ in range(2)]
        self.phys = [b.physical_address for b in self.bufs]
        self.front = 0                       # buffer currently scanned out to HDMI
        rules = (vox_loader.rules_from_materials(self.scene['materials'])
                 if self.scene['materials'] else None)
        self.grid, self.lut_words = vox_loader.load_world(
            os.path.join(os.path.dirname(__file__), self.scene['world']), rules)
        self._upload_svo(); self._shading()
        self._arm_s2mm(1 - self.front)       # first render targets the back buffer
        self._arm_mm2s()
    def _upload_svo(self):
        words = svo_builder.serialise_nodes(
            svo_builder.flatten_svo(svo_builder.build_svo(self.grid)))
        self.ip.write(0x48, 0)
        for w in words: self.ip.write(0x4C, w)
    def _shading(self):
        # The HDMI path swaps G↔B, so pre-swap every colour we write so it cancels out.
        # cc(r,g,b) physically writes (r,b,g) into the register.
        def cc(r, g, b): return pack_rgb(r, b, g)
        s = self.scene
        lx, ly, lz = s['light_dir']
        lm = math.sqrt(lx*lx + ly*ly + lz*lz); ld = (lx/lm, ly/lm, lz/lm)
        self.ip.write(0x3C, to_q16(ld[0])); self.ip.write(0x40, to_q16(ld[1])); self.ip.write(0x44, to_q16(ld[2]))
        # LUT via auto-inc pair (0x50=index, 0x54=data). G↔B pre-swap; preserve [31:24] flag.
        self.ip.write(0x50, 0)                       # lut_index = 0
        for w in self.lut_words:
            flag = (w >> 24) & 0xFF
            r, g, b = (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF
            self.ip.write(0x54, (flag << 24) | pack_rgb(r, b, g))   # auto-increments
        self.ip.write(0x68, cc(*s['sky_color'])); self.ip.write(0x6C, cc(*s['fog_color']))
        self.ip.write(0x70, to_q16(s['fog_start'])); self.ip.write(0x74, to_q16(s['shadow_bias']))
    def set_glow(self, phase):
        # Rainbow-animate any MAT_GLOW block. Full hue cycle per 2π. Same G↔B pre-swap.
        for bid, w in enumerate(self.lut_words):
            if ((w >> 24) & 0xFF) != vox_loader.MAT_GLOW:
                continue
            r = int(127.5 * (1 + math.sin(phase)))
            g = int(127.5 * (1 + math.sin(phase + 2.0943951)))   # +120°
            b = int(127.5 * (1 + math.sin(phase + 4.1887902)))   # +240°
            self.ip.write(0x50, bid)                          # lut_index = bid
            self.ip.write(0x54, (vox_loader.MAT_GLOW << 24) | pack_rgb(r, b, g))
    def _arm_s2mm(self, idx):
        # Arm S2MM write channel to write the rendered frame into buffer idx.
        self.vdma.write(0x30, 0x4)
        while self.vdma.read(0x30) & 0x4: pass
        for o in (0xAC, 0xB0, 0xB4): self.vdma.write(o, self.phys[idx])
        self.vdma.write(0xA8, STRIDE); self.vdma.write(0xA4, HSIZE)
        self.vdma.write(0x30, 0x3); self.vdma.write(0xA0, IMG_H)
    def _arm_mm2s(self):
        # Arm MM2S read channel; parks on whichever buffer is `front`.
        self.mm2s.write(0x00, 0x4)
        while self.mm2s.read(0x00) & 0x4: pass
        self.mm2s.write(0x5C, self.phys[0]); self.mm2s.write(0x60, self.phys[1]); self.mm2s.write(0x64, self.phys[1])
        self.mm2s.write(0x28, self.front)        # PARK_PTR_REG: which frame store to scan
        self.mm2s.write(0x58, STRIDE); self.mm2s.write(0x54, HSIZE)
        self.mm2s.write(0x00, 0x1); self.mm2s.write(0x50, IMG_H)
    def set_sun(self, az, el):
        # az = azimuth around Y, el = elevation above horizon. Direction vector — no G↔B swap.
        ce = math.cos(el)
        self.ip.write(0x3C, to_q16(ce * math.sin(az)))
        self.ip.write(0x40, to_q16(math.sin(el)))
        self.ip.write(0x44, to_q16(ce * math.cos(az)))
    def set_camera(self, cam):
        fwd, right, up = cam.vectors()
        self.ip.write(0x08, to_q16(cam.pos[0])); self.ip.write(0x0C, to_q16(cam.pos[1])); self.ip.write(0x10, to_q16(cam.pos[2]))
        self.ip.write(0x14, to_q16(right[0]));   self.ip.write(0x18, to_q16(right[1]));   self.ip.write(0x1C, to_q16(right[2]))
        self.ip.write(0x20, to_q16(up[0]));      self.ip.write(0x24, to_q16(up[1]));      self.ip.write(0x28, to_q16(up[2]))
        self.ip.write(0x2C, to_q16(fwd[0]));     self.ip.write(0x30, to_q16(fwd[1]));     self.ip.write(0x34, to_q16(fwd[2]))
        self.ip.write(0x38, to_q16(cam.scale))
    def render(self, timeout=2.0):
        back = 1 - self.front
        self._arm_s2mm(back)
        t0 = time.time(); self.ip.write(0x00, 1)
        while not (self.ip.read(0x04) & 0x1):
            if time.time() - t0 > 0.5: return False
        while self.ip.read(0x04) & 0x1:
            if time.time() - t0 > timeout: return False
        # Swap buffers; VDMA latches the new park frame at the next SOF — no mid-scan tear.
        self.front = back
        self.mm2s.write(0x28, self.front)
        return True
    def capture(self, path):
        # DDR byte order is B,G,R,X; _shading() pre-swapped G↔B. Index [2,0,1] undoes both → true RGB.
        import PIL.Image
        buf = self.bufs[self.front]
        buf.invalidate()                          # flush stale CPU cache after DMA write
        rgb = np.array(buf[:, :, [2, 0, 1]])
        PIL.Image.fromarray(rgb, 'RGB').save(path)
    def stop(self):
        self.vdma.write(0x30, 0x0)
        for b in self.bufs:
            try: b.freebuffer()
            except Exception: pass

# ── main loop ─────────────────────────────────────────────────────────────────
MOVE = 1.5                   # world-units per frame
TURN = math.radians(5)       # radians per frame
ZOOM = 1.05                  # FOV scale multiplier per frame

def main(use_evdev=False, device=None, scene_path=None):
    fov = math.tan(math.radians(60)/2) / (IMG_W/2)
    cam = fly_camera.Camera.looking_at([32, 40, -20], [32, 4, 32], scale=fov)
    rnd = Renderer(load_scene(scene_path))
    rnd.ip.write(0x88, 1); rnd.ip.write(0x8C, 6)   # shadow_on=1, max_depth=6
    if use_evdev:
        kb = EvdevKeyboard(find_keyboard(device))
        print('evdev: type on the BOARD keyboard. WASD move, arrows look, Space/Shift up-down, Q/E zoom, Esc quit')
    else:
        kb = StdinKeyboard()
        print('Type IN THIS TERMINAL: WASD move, arrows look, Space/C up-down, -/= zoom, Q or Ctrl-C quit')
    print('  Sun: I/K raise/lower, J/L swing, O toggle auto-orbit.')
    print('  Demo: T toggle shadows, [ ] traversal depth, F capture frame.')

    cap_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'captures')
    os.makedirs(cap_dir, exist_ok=True)
    cap_n = len(glob.glob(os.path.join(cap_dir, 'frame_*.png')))
    prev_capture_key = False

    # Seed sun az/el from the scene light_dir
    lx, ly, lz = rnd.scene['light_dir']
    ln = math.sqrt(lx*lx + ly*ly + lz*lz) or 1.0
    sun_el = math.asin(max(-1.0, min(1.0, ly / ln)))
    sun_az = math.atan2(lx, lz)
    SUN_STEP   = math.radians(4)     # per-frame nudge while a key is held
    ORBIT_STEP = math.radians(2)     # per-frame auto-orbit speed
    sun_orbit = False
    prev_orbit_key = False

    shadows_on = True
    max_depth  = 6
    prev_shadow_key = False

    frames = 0; t0 = time.time()
    fps_t = t0; fps_n = 0
    try:
        while True:
            h = kb.poll()
            if 'quit' in h:
                break
            sun_el += SUN_STEP * (('sunUp' in h) - ('sunDown' in h))
            sun_el  = max(math.radians(-89), min(math.radians(89), sun_el))
            sun_az += SUN_STEP * (('sunRight' in h) - ('sunLeft' in h))
            orbit_key = 'sunOrbit' in h
            if orbit_key and not prev_orbit_key:        # edge-trigger: toggle on key-down
                sun_orbit = not sun_orbit
            prev_orbit_key = orbit_key
            if sun_orbit:
                sun_az += ORBIT_STEP
            capture_key = 'capture' in h
            if capture_key and not prev_capture_key:
                cap_n += 1
                p = os.path.join(cap_dir, f'frame_{cap_n:03d}.png')
                while os.path.exists(p):
                    cap_n += 1; p = os.path.join(cap_dir, f'frame_{cap_n:03d}.png')
                rnd.capture(p)
                cfwd, cright, cup = cam.vectors()
                print(f'\n  captured {p}   (paste this camera into the sim):')
                print(f"    pos   = {[round(x, 4) for x in cam.pos]}")
                print(f"    fwd   = {[round(x, 4) for x in cfwd]}")
                print(f"    right = {[round(x, 4) for x in cright]}")
                print(f"    up    = {[round(x, 4) for x in cup]}")
                print(f"    scale = {cam.scale:.6f}")
            prev_capture_key = capture_key
            shadow_key = 'shadowTog' in h
            if shadow_key and not prev_shadow_key:
                shadows_on = not shadows_on
                rnd.ip.write(0x88, 1 if shadows_on else 0)
            prev_shadow_key = shadow_key
            if 'depthUp' in h or 'depthDown' in h:
                max_depth = max(1, min(6, max_depth + ('depthUp' in h) - ('depthDown' in h)))
                rnd.ip.write(0x8C, max_depth)
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
            if 'dump' in h:
                fwd, right, up = cam.vectors()
                u_edge = (IMG_W/2)*cam.scale   # = tan(FOV/2)
                v_edge = (IMG_H/2)*cam.scale
                print(f"\n# --- camera dump ---")
                print(f"pos   = {[round(x,4) for x in cam.pos]}")
                print(f"fwd   = {[round(x,4) for x in fwd]}")
                print(f"right = {[round(x,4) for x in right]}")
                print(f"up    = {[round(x,4) for x in up]}")
                print(f"yaw={cam.yaw:.4f} pitch={cam.pitch:.4f} scale={cam.scale:.6f}")
                print(f"u_edge={u_edge:.3f} v_edge={v_edge:.3f}  "
                      f"len2_corner={1+u_edge**2+v_edge**2:.3f}  "
                      f"(rsqrt seed y0={1.5-(1+u_edge**2+v_edge**2)/2:.3f}; "
                      f"{'OK' if 1.5-(1+u_edge**2+v_edge**2)/2 > 0.2 else 'TOO LOW -> distortion'})\n")
            rnd.set_glow(frames * 0.15)
            rnd.set_sun(sun_az, sun_el)
            rnd.ip.write(0x84, int(frames * rnd.scene['anim_speed']) & 0xFFFFFFFF)   # time_phase for water/lava
            rnd.set_camera(cam)
            if not rnd.render():
                print('  (render timeout)')
            frames += 1

            fps_n += 1
            now = time.time()
            if now - fps_t >= 1.0:
                sys.stdout.write(
                    f"\r{fps_n/(now-fps_t):5.1f} FPS  |  sun az={math.degrees(sun_az)%360:3.0f} "
                    f"el={math.degrees(sun_el):+3.0f}{'  ORBIT' if sun_orbit else '       '}"
                    f"  |  shadows={'ON ' if shadows_on else 'OFF'}  depth={max_depth}   ")
                sys.stdout.flush()
                fps_t = now; fps_n = 0
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
    scene_path = next((a for a in args if a.endswith('.json')), None)
    args = [a for a in args if not a.endswith('.json')]
    main(use_evdev, args[0] if args else None, scene_path)
