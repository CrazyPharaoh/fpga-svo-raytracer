#!/usr/bin/env python3
# host/hdmi_display.py — HDMI-output bring-up and diagnostics for the SVO raytracer.
# Runs the full flow in order: load overlay -> S2MM arm -> upload SVO -> camera ->
# shading registers -> render -> arm MM2S, printing status at each step.
# Run on the PYNQ: sudo python3 hdmi_display.py  (needs svo_builder.py + the bitstream)

import sys, time, math
import numpy as np
from pynq import Overlay, MMIO, allocate, Clocks
import svo_builder

BITSTREAM = '/home/xilinx/jupyter_notebooks/svo_system.bit'
IMG_W, IMG_H   = 320, 240
BYTES_PER_PIXEL = 4
HSIZE  = IMG_W * BYTES_PER_PIXEL      # 1280 bytes/line
STRIDE = IMG_W * BYTES_PER_PIXEL

FSM_STATES = {
    0:'S_IDLE', 1:'S_RAY_SETUP', 2:'S_ROOT_SLAB', 3:'S_ENTER_NODE',
    4:'S_BRAM_WAIT', 5:'S_CHECK_CHILD', 6:'S_EMPTY', 7:'S_SOLID',
    8:'S_MIXED', 9:'S_POP_STACK', 10:'S_MISS', 11:'S_WAIT_SHADE',
    12:'S_WRITE_PIXEL', 13:'S_NEXT_PIXEL',
}

def to_q16(f):      return int(f * 65536) & 0xFFFF_FFFF
def pack_rgb(r,g,b):return ((int(r)&0xFF)<<16)|((int(g)&0xFF)<<8)|(int(b)&0xFF)
def normalise(v):
    l = math.sqrt(sum(x*x for x in v));  return [x/l for x in v] if l>1e-9 else v
def cross(a,b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]

def banner(t): print('\n' + '='*64 + f'\n{t}\n' + '='*64)


# ── 1. Overlay ────────────────────────────────────────────────────────────────
banner('1. LOAD OVERLAY')
Clocks.fclk0_mhz = 100
ol  = Overlay(BITSTREAM)
ip  = ol.top_0
print(f'Bitstream loaded: {BITSTREAM}')
print('IPs in overlay (AXI-addressable only):')
for k, v in sorted(ol.ip_dict.items()):
    base = v.get('phys_addr')
    print(f'   {k:28s} @ {("0x%08X"%base) if base is not None else "n/a":12s} {v.get("type","")}')

VDMA_BASE = ol.ip_dict['axi_vdma_0']['phys_addr']
vdma = MMIO(VDMA_BASE, 0x1000)          # S2MM bank (0x30..)
mm2s = MMIO(VDMA_BASE, 0x100)           # MM2S bank (0x00..)

frame_buf  = allocate(shape=(IMG_H, IMG_W, BYTES_PER_PIXEL), dtype=np.uint8)
frame_phys = frame_buf.physical_address
print(f'Frame buffer: phys=0x{frame_phys:08X}  ({IMG_W}x{IMG_H}x{BYTES_PER_PIXEL})')


# ── 2. VDMA S2MM (write/render path) ──────────────────────────────────────────
def arm_s2mm():
    vdma.write(0x30, 0x4)                          # reset
    while vdma.read(0x30) & 0x4: pass
    vdma.write(0xAC, frame_phys); vdma.write(0xB0, frame_phys); vdma.write(0xB4, frame_phys)
    vdma.write(0xA8, STRIDE); vdma.write(0xA4, HSIZE)
    vdma.write(0x30, 0x3)                          # RS=1, circular
    vdma.write(0xA0, IMG_H)                        # VSIZE last = arm
    sr = vdma.read(0x34)
    if sr & 0x1: print(f'  WARNING: S2MM halted after arm (0x{sr:08X})')
    return sr

banner('2. VDMA S2MM (render write path)')
print(f'S2MM status after arm = 0x{arm_s2mm():08X}')


# ── 3. Upload SVO ─────────────────────────────────────────────────────────────
banner('3. UPLOAD SVO')
grid  = svo_builder.build_world()
nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
words = svo_builder.serialise_nodes(nodes)
print(f'{len(nodes)} nodes -> {len(words)} words')
ip.write(0x48, 0)
for w in words: ip.write(0x4C, w)
print('SVO uploaded.')


# ── 4. Camera ─────────────────────────────────────────────────────────────────
banner('4. CAMERA')
pos   = [32.0, 40.0, -20.0]
fwd   = normalise([32.0-pos[0], 4.0-pos[1], 32.0-pos[2]])
right = normalise(cross(fwd, [0,1,0]))
up    = cross(right, fwd)
fov_scale = math.tan(math.radians(60)/2) / (IMG_W/2)
ip.write(0x08,to_q16(pos[0]));   ip.write(0x0C,to_q16(pos[1]));   ip.write(0x10,to_q16(pos[2]))
ip.write(0x14,to_q16(right[0])); ip.write(0x18,to_q16(right[1])); ip.write(0x1C,to_q16(right[2]))
ip.write(0x20,to_q16(up[0]));    ip.write(0x24,to_q16(up[1]));    ip.write(0x28,to_q16(up[2]))
ip.write(0x2C,to_q16(fwd[0]));   ip.write(0x30,to_q16(fwd[1]));   ip.write(0x34,to_q16(fwd[2]))
ip.write(0x38,to_q16(fov_scale))
print(f'pos={pos}  fwd={[round(x,3) for x in fwd]}  scale={fov_scale:.6f}')


# ── 5. Shading registers (Phase 2) ────────────────────────────────────────────
banner('5. SHADING REGISTERS')
_lm = math.sqrt(1+4+2.25); ld = (1/_lm, 2/_lm, 1.5/_lm)
ip.write(0x3C,to_q16(ld[0])); ip.write(0x40,to_q16(ld[1])); ip.write(0x44,to_q16(ld[2]))
for i,(r,g,b) in enumerate([(0,0,0),(120,120,120),(60,160,40),(255,0,0),(0,0,0),(0,0,0)]):
    ip.write(0x50+i*4, pack_rgb(r,g,b))
ip.write(0x68, pack_rgb(135,206,235))   # sky
ip.write(0x6C, pack_rgb(180,200,220))   # fog
ip.write(0x70, to_q16(15.0))            # fog_start
ip.write(0x74, to_q16(0.5))             # shadow_bias
print('Shading registers written.')


# ── 6. Render ─────────────────────────────────────────────────────────────────
banner('6. RENDER')
arm_s2mm()
t0 = time.time(); ip.write(0x00, 1)                # trigger
while not (ip.read(0x04) & 0x1):                   # wait busy=1
    if time.time()-t0 > 0.5: print('  ERROR: trigger never fired'); break
while ip.read(0x04) & 0x1:                          # wait busy=0
    if time.time()-t0 > 15: print('  TIMEOUT: render hung'); break
    time.sleep(0.001)
elapsed = time.time()-t0
time.sleep(0.05); frame_buf.invalidate()
frame_rgb = np.array(frame_buf[:, :, [2,1,0]])
nonzero = int((frame_rgb.reshape(-1,3).any(axis=1)).sum())
print(f'Render done in {elapsed:.3f}s. Non-zero pixels: {nonzero}/{IMG_W*IMG_H}')
print(f'Frame pixel stats: min={frame_rgb.min()} max={frame_rgb.max()} mean={frame_rgb.mean():.1f}')
try:
    import PIL.Image
    PIL.Image.fromarray(frame_rgb,'RGB').save('/home/xilinx/jupyter_notebooks/hdmi_render.png')
    print('Saved hdmi_render.png (confirm the RENDER itself is correct before blaming HDMI)')
except Exception as e:
    print('  (PIL save skipped:', e, ')')
if nonzero == 0:
    print('  !! Frame is all-zero — the render failed; HDMI cannot show anything. Fix render first.')


# ── 7. Arm MM2S (HDMI read path) ──────────────────────────────────────────────
banner('7. ARM MM2S (HDMI output)')
MM2S_CR, MM2S_SR = 0x00, 0x04
MM2S_SA1, MM2S_STRIDE_REG, MM2S_HSIZE_REG, MM2S_VSIZE_REG = 0x5C, 0x58, 0x54, 0x50
MM2S_PARK_PTR = 0x28

mm2s.write(MM2S_CR, 0x4)                            # reset
while mm2s.read(MM2S_CR) & 0x4: pass
for off in (MM2S_SA1, MM2S_SA1+4, MM2S_SA1+8):
    mm2s.write(off, frame_phys)                     # all 3 fstores -> rendered frame
mm2s.write(MM2S_PARK_PTR, 0x0)                      # park on frame 0
mm2s.write(MM2S_STRIDE_REG, STRIDE)
mm2s.write(MM2S_HSIZE_REG, HSIZE)
mm2s.write(MM2S_CR, 0x1)                            # RS=1, park (bit1=0)
mm2s.write(MM2S_VSIZE_REG, IMG_H)                   # VSIZE last = arm
time.sleep(0.1)

def decode_mm2s_sr(sr):
    bits = {
        'Halted':sr&1, 'Idle':(sr>>1)&1,
        'IntErr':(sr>>4)&1, 'SlvErr':(sr>>5)&1, 'DecErr':(sr>>6)&1,
        'SOFEarlyErr':(sr>>7)&1, 'FrmCntIrq':(sr>>12)&1, 'ErrIrq':(sr>>14)&1,
    }
    return bits

cr = mm2s.read(MM2S_CR); sr = mm2s.read(MM2S_SR)
print(f'MM2S control = 0x{cr:08X}  (RS={cr&1}, Circular={(cr>>1)&1})')
print(f'MM2S status  = 0x{sr:08X}')
for k,v in decode_mm2s_sr(sr).items():
    flag = '  <-- !!' if (v and k!='Idle') else ''
    print(f'    {k:14s}= {v}{flag}')

# Watch it for ~2s: in park mode it should stay un-halted (it may show Idle/stalled
# if the downstream video pipeline isn't consuming — that points at the HDMI chain).
banner('8. MM2S LIVE WATCH (2s)')
for _ in range(8):
    sr = mm2s.read(MM2S_SR)
    print(f'  t+{_*0.25:.2f}s  SR=0x{sr:08X}  Halted={sr&1} Idle={(sr>>1)&1} err[6:4]={(sr>>4)&7}')
    time.sleep(0.25)

banner('VERDICT GUIDE')
print('If MM2S is NOT halted, no error bits, and the render PNG looks correct, then the')
print('SOFTWARE side is fully working — any remaining blank screen is the HDMI HARDWARE')
print('chain (clk_wiz lock / v_tc timing / rgb2dvi), not this script.')
print('Monitor reports:')
print('  "no signal"          -> no TMDS clock  -> clk_wiz not locking OR rgb2dvi in reset')
print('  "signal, black/garbage" -> VTC timing/PPC or sync polarity')
print('  correct image        -> done!')
