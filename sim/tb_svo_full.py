# sim/tb_svo_full.py
# Phase 2 testbench: drives svo_full_tb (primary traversal + shading_pipeline + shadow traversal).
# Signal hierarchy: DUT is svo_full_tb; traversal internals at dut.traversal.*

import sys, os, math
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'host'))
sys.path.insert(0, os.path.dirname(__file__))
import svo_builder
import vox_loader
from sim_profiling import state_profiler, write_state_profile

# RENDER_DIV: must match the -GIMG_W/-GIMG_H build (Makefile.shade) and gen_reference_shaded.py.
RENDER_DIV     = int(os.environ.get('RENDER_DIV', '1'))
IMG_W, IMG_H   = 320 // RENDER_DIV, 240 // RENDER_DIV
CLK_PERIOD_NS  = 10

_LM = math.sqrt(1.0**2 + 2.0**2 + 1.5**2)
LIGHT_DIR = (1.0/_LM, 2.0/_LM, 1.5/_LM)

# WORLD=vox (default): loads host/world.vox (64^3 grid + 16 LUT words, [31:24]=mat flag, [23:0]=RGB).
# WORLD=procedural: uses svo_builder.build_world(). gen_reference_shaded.py reads the same env var.
WORLD = os.environ.get('WORLD', 'vox')
if WORLD == 'procedural':
    GRID = svo_builder.build_world()
    _PROC_COLS = [(0,0,0),(120,120,120),(60,160,40),(255,0,0),(194,178,128),(235,240,250)]
    LUT_WORDS = [((r << 16) | (g << 8) | b) for (r, g, b) in _PROC_COLS] + [0]*10  # mat flag 0 (static)
else:
    WORLD_VOX = os.path.join(os.path.dirname(__file__), '..', 'host', 'world.vox')
    GRID, LUT_WORDS = vox_loader.load_world(WORLD_VOX)

SKY_COLOR   = (135, 206, 235)
FOG_COLOR   = (180, 200, 220)
FOG_START   = 15.0
SHADOW_BIAS = 0.5


# ─── Q16.16 / colour helpers ──────────────────────────────────────────────────

def to_q16(f):
    v = int(f * 65536) & 0xFFFF_FFFF
    if v & 0x8000_0000:
        v -= 0x1_0000_0000
    return v


def _from_q16(v):
    v = int(v) & 0xFFFF_FFFF
    if v & 0x8000_0000:
        v -= 0x1_0000_0000
    return v / 65536.0


def _qf(sig):
    return f"{_from_q16(sig.value):+.4f}"


def pack_rgb(r, g, b):
    return ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF)


def normalise(v):
    l = math.sqrt(sum(x**2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def build_svo_words():
    root  = svo_builder.build_svo(GRID)
    nodes = svo_builder.flatten_svo(root)
    return svo_builder.serialise_nodes(nodes)


# ─── State / child-type name tables ───────────────────────────────────────────

_STATE_NAMES = {
    0: 'S_IDLE',        1: 'S_RAY_SETUP',   2: 'S_ROOT_SLAB',    3: 'S_ENTER_NODE',
    4: 'S_BRAM_WAIT',   5: 'S_CHECK_CHILD', 6: 'S_EMPTY',        7: 'S_SOLID',
    8: 'S_MIXED',       9: 'S_POP_STACK',  10: 'S_MISS',         11: 'S_WAIT_SHADE',
    12: 'S_WRITE_PIXEL', 13: 'S_NEXT_PIXEL',
}
_CHILD_TYPES = {0: 'EMPTY', 1: 'MIXED', 2: 'UNDEF(10)', 3: 'SOLID'}
_FACE_NAMES  = {0: 'X', 1: 'Y', 2: 'Z'}


# ─── BRAM model ───────────────────────────────────────────────────────────────

async def bram_model(dut, words):
    """1-cycle registered BRAM model (matches hardware svo_bram_shadow).
    Port B wide (gated, primary): svo_rd_wide_prim = 256-bit node, word w at bits [w*32+:32].
    Two shadow lanes (always read): svo_rd_data_shad / svo_rd_data_shad1 = 32-bit word."""
    def rd(addr):
        a = int(addr)
        return int(words[a]) if a < len(words) else 0
    def rd_node(node):
        n = int(node)
        v = 0
        for w in range(8):
            v |= rd(n * 8 + w) << (w * 32)
        return v
    pend_prim = None
    pend_shad = None
    pend_shad1 = None
    dut.svo_rd_wide_prim.value = 0
    dut.svo_rd_data_shad.value = 0
    dut.svo_rd_data_shad1.value = 0
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')
        if pend_prim is not None:
            dut.svo_rd_wide_prim.value = pend_prim
        if pend_shad is not None:
            dut.svo_rd_data_shad.value = pend_shad
        if pend_shad1 is not None:
            dut.svo_rd_data_shad1.value = pend_shad1
        pend_prim  = rd_node(dut.svo_rd_node_prim.value) if int(dut.svo_rd_en_prim.value) else None
        pend_shad  = rd(dut.svo_rd_addr_shad.value)
        pend_shad1 = rd(dut.svo_rd_addr_shad1.value)


# ─── Pixel collector ──────────────────────────────────────────────────────────

async def collect_pixels_axis(dut, pixels):
    """Collect AXI-Stream pixels into list; tuser resets on SOF."""
    dut.axis_tready.value = 1
    while len(pixels) < IMG_W * IMG_H:
        await RisingEdge(dut.clk)
        if dut.axis_tvalid.value and dut.axis_tready.value:
            if dut.axis_tuser.value:
                pixels.clear()
            tdata = int(dut.axis_tdata.value) & 0xFFFF_FFFF
            pixels.append(((tdata >> 16) & 0xFF, (tdata >> 8) & 0xFF, tdata & 0xFF))
            if len(pixels) % 1000 == 0:
                cocotb.log.info(f"  {len(pixels)}/{IMG_W*IMG_H} pixels collected")


# ─── Pixel tracer ─────────────────────────────────────────────────────────────
# Accesses traversal internals via dut.traversal.* (requires --public-flat-rw).
# Per-ray signals are [slot] arrays in svo_traversal_mr; _SlotView auto-indexes slot 0.
_PER_RAY_SIGNALS = {
    'bitmask', 'cidx', 'cx', 'cy', 'cz', 'dt_x', 'dt_y', 'dt_z',
    'hit_face', 'hit_face_sign_r', 'inv_x', 'inv_y', 'inv_z',
    'node_half', 'node_idx', 'node_origin_x', 'node_origin_y', 'node_origin_z',
    'r_block', 'rd_x', 'rd_y', 'rd_z', 'ro_x', 'ro_y', 'ro_z', 'sp',
    'step_x', 'step_y', 'step_z', 't_max', 't_min',
    't_next_x', 't_next_y', 't_next_z',
}
_TRACE_SLOT = 0


class _SlotView:
    """Read-only wrapper: auto-indexes per-ray array signals to a fixed slot."""
    def __init__(self, hier):
        object.__setattr__(self, '_hier', hier)

    def __getattr__(self, name):
        sig = getattr(self._hier, name)
        return sig[_TRACE_SLOT] if name in _PER_RAY_SIGNALS else sig


async def pixel_tracer(dut, pixel_logs):
    """Log FSM state transitions per pixel from dut.traversal (primary core)."""
    t = _SlotView(dut.traversal)

    prev_state = -1
    step = 0
    cur_px = cur_py = 0
    cur_lines = []

    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')

        if int(dut.rst.value):
            continue

        state = int(dut.dbg_state.value)
        if state == prev_state:
            continue

        prev_state = state
        step += 1
        sn  = _STATE_NAMES.get(state, f'S_{state}')
        pad = f"  [{step:03d}] {sn:<14s} | "

        if state == 1:   # S_RAY_SETUP: new pixel
            if cur_lines:
                pixel_logs.append((cur_px, cur_py, cur_lines))
            cur_px  = int(dut.dbg_px.value)
            cur_py  = int(dut.dbg_py.value)
            cur_lines = []
            step    = 1
            pad     = f"  [{step:03d}] {sn:<14s} | "
            cur_lines.append(pad + f"px={cur_px} py={cur_py}")

        elif state == 2:   # S_ROOT_SLAB: ray params ready
            sx = '+1' if not (int(t.step_x.value) & 4) else '-1'
            sy = '+1' if not (int(t.step_y.value) & 4) else '-1'
            sz = '+1' if not (int(t.step_z.value) & 4) else '-1'
            cur_lines.append(
                pad + f"rd=({_qf(t.rd_x)},{_qf(t.rd_y)},{_qf(t.rd_z)})  "
                      f"ro=({_qf(t.ro_x)},{_qf(t.ro_y)},{_qf(t.ro_z)})\n"
                f"  {'':3s} {'':14s} | inv=({_qf(t.inv_x)},{_qf(t.inv_y)},{_qf(t.inv_z)})  "
                      f"step=({sx},{sy},{sz})"
            )

        elif state == 3:   # S_ENTER_NODE: issue BRAM read
            cur_lines.append(
                pad + f"t_min={_qf(t.t_min)} t_max={_qf(t.t_max)}  "
                      f"node={int(t.node_idx.value)} half={int(t.node_half.value)}  "
                      f"origin=({int(t.node_origin_x.value)},{int(t.node_origin_y.value)},{int(t.node_origin_z.value)}) "
                      f"sp={int(t.sp.value)}"
            )

        elif state == 4:   # S_BRAM_WAIT: reading node words
            cur_lines.append(pad + f"loading BRAM for node={int(t.node_idx.value)}")

        elif state == 5:   # S_CHECK_CHILD: classify child from bitmask
            bm     = int(t.bitmask.value)
            cx_v   = int(t.cx.value)
            cy_v   = int(t.cy.value)
            cz_v   = int(t.cz.value)
            cidx_v = ((cz_v & 1) << 2) | ((cy_v & 1) << 1) | (cx_v & 1)
            ct     = _CHILD_TYPES.get((bm >> (cidx_v * 2)) & 3, '?')
            cur_lines.append(
                pad + f"cx={cx_v} cy={cy_v} cz={cz_v} cidx={cidx_v}  "
                      f"bitmask=0x{bm:04X} → {ct}\n"
                f"  {'':3s} {'':14s} | t_min={_qf(t.t_min)}  "
                      f"t_next=({_qf(t.t_next_x)},{_qf(t.t_next_y)},{_qf(t.t_next_z)})"
            )

        elif state == 6:   # S_EMPTY: advance DDA
            tnx = _from_q16(t.t_next_x.value)
            tny = _from_q16(t.t_next_y.value)
            tnz = _from_q16(t.t_next_z.value)
            axis = 'X' if tnx <= tny and tnx <= tnz else ('Y' if tny <= tnz else 'Z')
            cur_lines.append(
                pad + f"PRE-step: cx={int(t.cx.value)} cy={int(t.cy.value)} cz={int(t.cz.value)}  "
                      f"step_axis={axis}  t_min={_qf(t.t_min)}\n"
                f"  {'':3s} {'':14s} | t_next=({tnx:+.4f},{tny:+.4f},{tnz:+.4f})  "
                      f"dt=({_qf(t.dt_x)},{_qf(t.dt_y)},{_qf(t.dt_z)})"
            )

        elif state == 7:   # S_SOLID: hit; shade_start asserted this cycle
            face_n   = _FACE_NAMES.get(int(t.hit_face.value), '?')
            face_s   = '-' if int(t.hit_face_sign_r.value) else '+'
            blk      = int(t.r_block[int(t.cidx.value)].value) if hasattr(t, 'r_block') else '?'
            cur_lines.append(
                pad + f"t_hit={_qf(t.t_min)}  cidx={int(t.cidx.value)}  "
                      f"face={face_n}{face_s}  block_id={blk}  sp={int(t.sp.value)}\n"
                f"  {'':3s} {'':14s} | → shade_start=1"
            )

        elif state == 8:   # S_MIXED: push stack and descend
            sp_v = int(t.sp.value)
            cur_lines.append(
                pad + f"descend: cidx={int(t.cidx.value)}  push sp:{sp_v}→{sp_v+1}  "
                      f"parent_node={int(t.node_idx.value)} "
                      f"cx/cy/cz=({int(t.cx.value)},{int(t.cy.value)},{int(t.cz.value)}) "
                      f"half={int(t.node_half.value)}"
            )

        elif state == 9:   # S_POP_STACK: child exhausted, restore parent
            sp_v = int(t.sp.value)
            cur_lines.append(
                pad + f"pop sp:{sp_v}→{max(0, sp_v-1)}  "
                      f"cx={int(t.cx.value)} cy={int(t.cy.value)} cz={int(t.cz.value)}  "
                      f"t_min={_qf(t.t_min)}"
            )

        elif state == 10:   # S_MISS: ray exited world; shade_start asserted for sky colour
            cur_lines.append(
                pad + f"sky_color=({SKY_COLOR[0]},{SKY_COLOR[1]},{SKY_COLOR[2]}) → MISS\n"
                f"  {'':3s} {'':14s} | → shade_start=1"
            )

        elif state == 11:   # S_WAIT_SHADE: waiting for shade_done
            cur_lines.append(pad + "waiting for shade_done ...")

        elif state == 12:   # S_WRITE_PIXEL: emit pixel over AXI-Stream
            pc    = int(dut.axis_tdata.value) & 0xFFFFFF
            r_out = (pc >> 16) & 0xFF
            g_out = (pc >> 8)  & 0xFF
            b_out =  pc        & 0xFF
            cur_lines.append(
                pad + f"color=({r_out},{g_out},{b_out})  "
                      f"tlast={int(dut.axis_tlast.value)}  "
                      f"tuser={int(dut.axis_tuser.value)}"
            )
            cur_lines.append(f"  RESULT: color=({r_out},{g_out},{b_out})")

        elif state == 13:   # S_NEXT_PIXEL: pixel complete, flush and advance
            if cur_lines:
                pixel_logs.append((cur_px, cur_py, cur_lines))
            cur_lines = []
            step = 0


def write_pixel_trace_log(pixel_logs, log_path):
    """Write per-pixel trace lines to log_path."""
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    sep = '=' * 80
    with open(log_path, 'w') as f:
        for px, py, lines in pixel_logs:
            f.write(f"{sep}\n")
            f.write(f"PIXEL (px={px}, py={py})\n")
            f.write(f"{sep}\n")
            for line in lines:
                f.write(line + '\n')
            f.write('\n')
    cocotb.log.info(f"Pixel trace log written: {log_path}")


# ─── Main test ────────────────────────────────────────────────────────────────

@cocotb.test()
async def test_render_frame_shaded(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    cocotb.log.info("Building SVO scene ...")
    svo_words = build_svo_words()
    cocotb.log.info(f"  {len(svo_words)} SVO words")

    pixels    = []
    pixel_logs = []
    state_counts = {}
    cocotb.start_soon(bram_model(dut, svo_words))
    cocotb.start_soon(collect_pixels_axis(dut, pixels))
    cocotb.start_soon(pixel_tracer(dut, pixel_logs))
    cocotb.start_soon(state_profiler(dut, state_counts))

    # Reset
    dut.rst.value   = 1
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Camera — must stay identical to gen_reference_shaded.py.
    if WORLD == 'procedural':
        # original build_world() view (looks at the terrain centre)
        pos   = [30.0, 15.0, 0.0]
        fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
        right = normalise(cross(fwd, [0, 1, 0]))
        up    = cross(right, fwd)
    else:
        pos   = [48.0095, 16.7627, 27.9686]
        fwd   = [-0.9094, -0.337, 0.2437]
        right = [-0.2588, 0.0, -0.9659]
        up    = [-0.3255, 0.9415, 0.0872]
    fov_scale = math.tan(math.radians(60) / 2) / (IMG_W / 2)  # same FOV at any RENDER_DIV

    dut.cam_pos_x.value   = to_q16(pos[0]);   dut.cam_pos_y.value   = to_q16(pos[1]);   dut.cam_pos_z.value   = to_q16(pos[2])
    dut.cam_right_x.value = to_q16(right[0]); dut.cam_right_y.value = to_q16(right[1]); dut.cam_right_z.value = to_q16(right[2])
    dut.cam_up_x.value    = to_q16(up[0]);    dut.cam_up_y.value    = to_q16(up[1]);    dut.cam_up_z.value    = to_q16(up[2])
    dut.cam_fwd_x.value   = to_q16(fwd[0]);   dut.cam_fwd_y.value   = to_q16(fwd[1]);   dut.cam_fwd_z.value   = to_q16(fwd[2])
    dut.cam_scale.value   = to_q16(fov_scale)

    dut.sky_color.value   = pack_rgb(*SKY_COLOR)
    dut.fog_color.value   = pack_rgb(*FOG_COLOR)
    dut.fog_start.value   = to_q16(FOG_START)
    dut.shadow_bias.value = to_q16(SHADOW_BIAS)

    dut.light_dir_x.value = to_q16(LIGHT_DIR[0])
    dut.light_dir_y.value = to_q16(LIGHT_DIR[1])
    dut.light_dir_z.value = to_q16(LIGHT_DIR[2])

    for i in range(16):
        getattr(dut, f"lut_{i}").value = LUT_WORDS[i]
    dut.time_phase.value = 0   # static frame; matches gen_reference_shaded.py TIME_PHASE=0
    dut.shadow_on.value = 1    # must match gen_reference_shaded.py SHADOWS_ENABLED
    dut.max_depth.value = 6    # full detail; no LOD cap

    await RisingEdge(dut.clk)

    cocotb.log.info("Triggering render ...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = IMG_W * IMG_H * 50000
    for cycle in range(timeout):
        await RisingEdge(dut.clk)
        if dut.frame_done.value:
            cocotb.log.info(f"frame_done at cycle {cycle}")
            break
    else:
        raise cocotb.result.TestFailure(f"Timeout after {timeout} cycles")

    for _ in range(20):
        await RisingEdge(dut.clk)

    assert len(pixels) == IMG_W * IMG_H, \
        f"Expected {IMG_W*IMG_H} pixels, got {len(pixels)}"

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    out_dir = os.path.join(os.path.dirname(__file__), 'output')
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(arr, 'RGB').save(os.path.join(out_dir, 'hardware_render_shaded.png'))
    cocotb.log.info(f"Saved hardware_render_shaded.png")

    write_pixel_trace_log(
        pixel_logs,
        os.path.join(out_dir, 'logs', 'pixel_trace_shaded.txt')
    )
    write_state_profile(state_counts, os.path.join(out_dir, 'logs', 'state_profile_shaded.txt'),
                        IMG_W, IMG_H,
                        archive_dir=os.path.join(out_dir, 'profiles'), label='shade')
