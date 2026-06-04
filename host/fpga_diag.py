#!/usr/bin/env python3
# host/fpga_diag.py
# Diagnostic for the multi-ray render hang. Mirrors the notebook/hdmi_display.py
# setup (raw MMIO + allocate — the AxiVDMA driver fails to instantiate on this
# bitstream), then tight-loops the status + debug regs during the render and
# decodes the VDMA S2MM state, so we can tell whether the core (a) never starts,
# (b) runs and finishes but emits nothing, or (c) genuinely deadlocks — and
# whether the VDMA write channel is armed/erroring.
#   Run on the PYNQ: sudo /usr/local/share/pynq-venv/bin/python3 fpga_diag.py

import time, math
import numpy as np
from pynq import Overlay, MMIO, allocate
import svo_builder

BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'
IMG_W, IMG_H = 320, 240
BPP = 4
STRIDE = HSIZE = IMG_W * BPP   # 1280

def to_q16(f): return int(f * 65536) & 0xFFFF_FFFF
def pack_rgb(r, g, b): return ((int(r)&0xFF)<<16)|((int(g)&0xFF)<<8)|(int(b)&0xFF)
def normalise(v):
    l = math.sqrt(sum(x*x for x in v)); return [x/l for x in v] if l > 1e-9 else v
def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]

def decode_dbg(d78, d7c):
    return dict(state=d78 & 0xF, tvalid=(d78>>4)&1, tready=(d78>>5)&1,
                rs_wait=(d78>>6)&0xF, px=(d7c>>8)&0x1FF, py=d7c & 0xFF)

def vdma_s2mm(vdma):
    cr = vdma.read(0x30); sr = vdma.read(0x34)
    return dict(CR=hex(cr), SR=hex(sr), RS=cr & 1, Halted=sr & 1,
                Err=(sr>>4)&0x7, IRQ=(sr>>12)&0xF)

STATE_NAMES = {0:'IDLE',1:'RAY_SETUP',2:'ROOT_SLAB',3:'ENTER_NODE',4:'BRAM_WAIT',
               5:'CHECK_CHILD',6:'EMPTY',7:'SOLID',8:'MIXED',9:'POP_STACK',
               10:'MISS',11:'WAIT_SHADE',12:'WRITE_PIXEL',13:'NEXT_PIXEL'}

# ── load + arm VDMA (raw MMIO, like hdmi_display.py) ─────────────────────────
print("Loading bitstream …")
ol = Overlay(BITSTREAM); ip = ol.top_0
VDMA_BASE = ol.ip_dict['axi_vdma_0']['phys_addr']
vdma = MMIO(VDMA_BASE, 0x1000)
frame_buf  = allocate(shape=(IMG_H, IMG_W, BPP), dtype=np.uint8)
frame_phys = frame_buf.physical_address
print(f"Frame buffer phys = 0x{frame_phys:08X}")

vdma.write(0x30, 0x4)                       # reset
while vdma.read(0x30) & 0x4: pass
vdma.write(0xAC, frame_phys); vdma.write(0xB0, frame_phys); vdma.write(0xB4, frame_phys)
vdma.write(0xA8, STRIDE); vdma.write(0xA4, HSIZE)
vdma.write(0x30, 0x3)                       # RS=1, circular
vdma.write(0xA0, IMG_H)                      # VSIZE last = arm
print("VDMA S2MM after arm:", vdma_s2mm(vdma))

# ── SVO + scene + camera (identical to display_frame.py) ─────────────────────
grid = svo_builder.build_world(); root = svo_builder.build_svo(grid)
words = svo_builder.serialise_nodes(svo_builder.flatten_svo(root))
print(f"SVO: {len(words)} words")
ip.write(0x48, 0)
for w in words: ip.write(0x4C, w)
for off, c in [(0x50,(0,0,0)),(0x54,(128,128,128)),(0x58,(60,160,40)),
               (0x5C,(255,220,80)),(0x60,(0,0,0)),(0x64,(0,0,0)),
               (0x68,(135,206,235)),(0x6C,(180,200,220))]:
    ip.write(off, pack_rgb(*c))
ip.write(0x70, to_q16(15.0)); ip.write(0x74, to_q16(0.5))   # shadow_bias 0.5 (matches gen_reference_shaded.py; 0.01 self-shadows)
pos=[32.0,40.0,-20.0]; fwd=normalise([32-pos[0],4-pos[1],32-pos[2]])
right=normalise(cross(fwd,[0,1,0])); up=cross(right,fwd)
ip.write(0x38, to_q16(math.tan(math.radians(60)/2)/(IMG_W/2)))
for off,val in zip(range(0x08,0x38,4), pos+right+up+fwd): ip.write(off, to_q16(val))
ld=normalise([0.5,-0.7,0.5])
for off,val in zip((0x3C,0x40,0x44), ld): ip.write(off, to_q16(val))

print("Pre-trigger status:", hex(ip.read(0x04)), " dbg:", decode_dbg(ip.read(0x78), ip.read(0x7C)))

# ── trigger + tight-loop sample ──────────────────────────────────────────────
print("Triggering …")
samples = []
ip.write(0x00, 1)
t0 = time.time()
ever_busy = False; last_busy_t = None; t_first_busy = None
while time.time() - t0 < 20.0:
    s  = ip.read(0x04); d78 = ip.read(0x78); d7c = ip.read(0x7C)
    t  = time.time() - t0
    samples.append((t, s, d78, d7c))
    if s & 1:
        ever_busy = True; last_busy_t = t
        if t_first_busy is None: t_first_busy = t
    if ever_busy and (s & 1) == 0 and last_busy_t is not None and t - last_busy_t > 0.3:
        break

print(f"\n=== {len(samples)} polls in {samples[-1][0]:.2f}s ===")
print(f"ever_busy        : {ever_busy}")
print(f"first busy=1 at  : {t_first_busy}")
print(f"last  busy=1 at  : {last_busy_t}")
print(f"final status     : {hex(samples[-1][1])}  frame_done bit = {(samples[-1][1]>>1)&1}")

pxs = [decode_dbg(d78,d7c)['px'] for _,_,d78,d7c in samples]
pys = [decode_dbg(d78,d7c)['py'] for _,_,d78,d7c in samples]
sts = [d78 & 0xF for _,_,d78,_ in samples]
print(f"px range         : min={min(pxs)} max={max(pxs)}   (frame is 0..{IMG_W-1})")
print(f"py range         : min={min(pys)} max={max(pys)}   (frame is 0..{IMG_H-1})")
print(f"FSM states seen  : {[f'{s}:{STATE_NAMES.get(s,s)}' for s in sorted(set(sts))]}")

print("\n--- trace (only when state/px/py/busy change) ---")
prev=None; shown=0
for t,s,d78,d7c in samples:
    d = decode_dbg(d78,d7c); key=(d['state'],d['px'],d['py'],s&1)
    if key != prev:
        print(f"  t={t:6.3f}  busy={s&1} fd={(s>>1)&1}  {d['state']:2d}:{STATE_NAMES.get(d['state'],'?'):<11s} "
              f"px={d['px']:3d} py={d['py']:3d} rs={d['rs_wait']} tv={d['tvalid']} tr={d['tready']}")
        prev=key; shown+=1
    if shown > 60: print("  … (truncated)"); break

print("\nVDMA S2MM after  :", vdma_s2mm(vdma))

# ── frame readback (the allocated buffer is the DMA target) ───────────────────
frame_buf.invalidate()
nz = int(np.count_nonzero(frame_buf[:, :, :3].reshape(-1, 3).any(axis=1)))
print(f"\nframe buffer: {nz}/{IMG_W*IMG_H} non-black pixels")
try:
    import PIL.Image
    PIL.Image.fromarray(np.array(frame_buf[:, :, [2,1,0]]), 'RGB').save('/tmp/diag_render.png')
    print("saved /tmp/diag_render.png")
except Exception as e:
    print("png save skipped:", e)
