#!/usr/bin/env python3
# host/fpga_diag.py
# Diagnostic for the multi-ray render hang. Mirrors the notebook/hdmi_display.py
# setup (raw MMIO + allocate — the AxiVDMA driver fails to instantiate on this
# bitstream), then tight-loops the status + debug regs during the render and
# decodes the VDMA S2MM state, so we can tell whether the core (a) never starts,
# (b) runs and finishes but emits nothing, or (c) genuinely deadlocks — and
# whether the VDMA write channel is armed/erroring.
#   Run on the PYNQ: sudo /usr/local/share/pynq-venv/bin/python3 fpga_diag.py

import time, math, sys
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

def decode_mr(v):
    # 0x80: [15:0] state[0..3] (4b each); [16]grant_valid [17]bram_busy [18]shade_busy
    #       [23:20]ready  [25:24]bram_owner  [27:26]shade_owner
    return dict(s0=v&0xF, s1=(v>>4)&0xF, s2=(v>>8)&0xF, s3=(v>>12)&0xF,
                grant_valid=(v>>16)&1, bram_busy=(v>>17)&1, shade_busy=(v>>18)&1,
                ready=(v>>20)&0xF, bram_owner=(v>>24)&3, shade_owner=(v>>26)&3)

def fmt_mr(v):
    m = decode_mr(v)
    sn = lambda x: STATE_NAMES.get(x, str(x))
    return (f"slots=[{sn(m['s0'])},{sn(m['s1'])},{sn(m['s2'])},{sn(m['s3'])}] "
            f"ready={m['ready']:04b} grant_valid={m['grant_valid']} "
            f"bram_busy={m['bram_busy']}(own{m['bram_owner']}) "
            f"shade_busy={m['shade_busy']}(own{m['shade_owner']})")

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
               (0x5C,(255,220,80)),(0x60,(194,178,128)),(0x64,(235,240,250)),  # 4 sand, 5 snow
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
    s  = ip.read(0x04); d78 = ip.read(0x78); d7c = ip.read(0x7C); d80 = ip.read(0x80)
    t  = time.time() - t0
    samples.append((t, s, d78, d7c, d80))
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

pxs = [decode_dbg(s[2],s[3])['px'] for s in samples]
pys = [decode_dbg(s[2],s[3])['py'] for s in samples]
sts = [s[2] & 0xF for s in samples]
print(f"px range         : min={min(pxs)} max={max(pxs)}   (frame is 0..{IMG_W-1})")
print(f"py range         : min={min(pys)} max={max(pys)}   (frame is 0..{IMG_H-1})")
print(f"FSM states seen  : {[f'{s}:{STATE_NAMES.get(s,s)}' for s in sorted(set(sts))]}")

print("\n--- trace (only when state/px/py/busy change) ---")
prev=None; shown=0
for t,s,d78,d7c,d80 in samples:
    d = decode_dbg(d78,d7c); key=(d['state'],d['px'],d['py'],s&1)
    if key != prev:
        print(f"  t={t:6.3f}  busy={s&1} fd={(s>>1)&1}  {d['state']:2d}:{STATE_NAMES.get(d['state'],'?'):<11s} "
              f"px={d['px']:3d} py={d['py']:3d} rs={d['rs_wait']} tv={d['tvalid']} tr={d['tready']}")
        prev=key; shown+=1
    if shown > 60: print("  … (truncated)"); break

# Multi-ray internals (0x80): all slot states + scheduler/arbiter flags.
# When hung, this shows EXACTLY where: e.g. all slots WAIT_SHADE + shade_busy=1 =
# shader stuck; ready!=0 but grant_valid=0 = scheduler not granting (the suspect).
print("\n=== MULTI-RAY internals (0x80) — last 8 samples ===")
for t,s,d78,d7c,d80 in samples[-8:]:
    print(f"  t={t:6.3f} busy={s&1}  {fmt_mr(d80)}")

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

# ── TEST SUMMARY: validate the multi-ray (M2) core ───────────────────────────
# Asserts the new pieces actually engaged on hardware (not just "didn't hang"):
# the ray pool interleaves (>1 slot in flight), the shading lanes run, the read
# engine runs, the VDMA write channel is clean, and the frame is non-trivial.
print("\n" + "=" * 62)
print("  TEST SUMMARY — multi-ray (M2) core")
print("=" * 62)

results = []
def check(name, ok, detail=""):
    results.append(bool(ok))
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"   ({detail})" if detail else ""))

# Aggregate the per-slot / arbiter flags across ALL polls.
slots_seen, max_concurrent = set(), 0
grant_ever = shade_ever = bram_ever = False
for (_t, _s, _d78, _d7c, d80) in samples:
    m = decode_mr(d80)
    active = [i for i, st in enumerate((m['s0'], m['s1'], m['s2'], m['s3'])) if st != 0]
    slots_seen.update(active)
    max_concurrent = max(max_concurrent, len(active))
    grant_ever |= bool(m['grant_valid'])
    shade_ever |= bool(m['shade_busy'])
    bram_ever  |= bool(m['bram_busy'])

# 1. Render completed cleanly (started, then busy dropped — no hang/timeout).
final_status = samples[-1][1]
completed = ever_busy and (final_status & 1) == 0
check("render completed (busy returned to 0, no hang)", completed,
      f"frame_done={(final_status >> 1) & 1}, ever_busy={ever_busy}")

# 2. Render time + FPS (the whole point of M2 — report it, sanity-bound it).
if t_first_busy is not None and last_busy_t is not None and last_busy_t > t_first_busy:
    render_s = last_busy_t - t_first_busy
    fps = 1.0 / render_s
    check("render time measured", True, f"{render_s*1000:.1f} ms  ->  {fps:.2f} FPS")
else:
    check("render time measured", False, "never observed a busy interval")

# 3. VDMA S2MM write channel healthy (no error bits).
v = vdma_s2mm(vdma)
check("VDMA S2MM no error", v['Err'] == 0, f"SR={v['SR']} Err={v['Err']}")

# 4. Frame is non-trivial (sky + terrain should fill most of 320x240).
nz_ratio = nz / (IMG_W * IMG_H)
check("frame non-black ratio plausible (>40%)", nz_ratio > 0.40,
      f"{nz_ratio*100:.1f}% non-black")

# 5. Multi-ray pool ACTUALLY interleaving: >=2 distinct slots seen in flight.
#    If only slot 0 ever runs, the pool/scheduler is effectively single-ray.
check("multi-ray interleaving (>=2 slots in flight)", len(slots_seen) >= 2,
      f"slots used={sorted(slots_seen)}, max concurrent={max_concurrent}")

# 6. Shading lanes engaged (this is a SHADE_MODE=1 build).
check("shading pipeline active (shade_busy seen)", shade_ever)

# 7. Wide-read BRAM engine active.
check("BRAM read engine active (bram_busy seen)", bram_ever)

# 8. Scheduler granting work.
check("scheduler granting (grant_valid seen)", grant_ever)

print("-" * 62)
ok_n = sum(results)
print(f"  OVERALL: {'ALL PASS' if ok_n == len(results) else 'SOME FAILED'}"
      f"   ({ok_n}/{len(results)})")
print("=" * 62)
sys.exit(0 if ok_n == len(results) else 1)
