# sim/tb_svo_traversal.py
# Phase 1 testbench: drives svo_traversal_mr directly (no shading_pipeline DUT).
# Uses a shade_stub for SHADE_MODE=1 builds and a pixel_tracer for FSM debugging.
import sys, os, math
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'host'))
sys.path.insert(0, os.path.dirname(__file__))
import svo_builder
from sim_profiling import state_profiler, write_state_profile

# RENDER_DIV: integer downscale at constant FOV; RTL must be built with matching -GIMG_W/-GIMG_H.
RENDER_DIV = int(os.environ.get('RENDER_DIV', '1'))
IMG_W, IMG_H = 320 // RENDER_DIV, 240 // RENDER_DIV
CLK_PERIOD_NS = 10


def to_q16(f):
    v = int(f * 65536) & 0xFFFF_FFFF
    if v & 0x8000_0000:
        v -= 0x1_0000_0000
    return v


def normalise(v):
    l = math.sqrt(sum(x**2 for x in v))
    return [x / l for x in v] if l > 1e-9 else v


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


# ─── Q16.16 helpers ───────────────────────────────────────────────────────────

def _from_q16(v):
    """Q16.16 signed integer → Python float."""
    v = int(v) & 0xFFFF_FFFF
    if v & 0x8000_0000:
        v -= 0x1_0000_0000
    return v / 65536.0


def _qf(sig):
    """Format a DUT Q16.16 signal as a signed float string."""
    return f"{_from_q16(sig.value):+.4f}"


_STATE_NAMES = {
    0: 'S_IDLE',        1: 'S_RAY_SETUP',   2: 'S_ROOT_SLAB',    3: 'S_ENTER_NODE',
    4: 'S_BRAM_WAIT',   5: 'S_CHECK_CHILD', 6: 'S_EMPTY',        7: 'S_SOLID',
    8: 'S_MIXED',       9: 'S_POP_STACK',  10: 'S_MISS',         11: 'S_WAIT_SHADE',
    12: 'S_WRITE_PIXEL', 13: 'S_NEXT_PIXEL',
}
_CHILD_TYPES = {0: 'EMPTY', 1: 'MIXED', 2: 'UNDEF(10)', 3: 'SOLID'}


async def shade_stub(dut, latency=5):
    """Per-lane shading stub: asserts shade_done after latency cycles with white (hit) or sky (miss).
    shade_* ports are unpacked arrays [0:SHADE_LANES-1]. Harmless when SHADE_MODE=0."""
    SKY = (135 << 16) | (206 << 8) | 235
    nlanes = len(dut.shade_done)
    for L in range(nlanes):
        dut.shade_done[L].value        = 0
        dut.shade_pixel_color[L].value = 0

    async def lane(L):
        while True:
            await RisingEdge(dut.clk)
            if int(dut.shade_start[L].value):
                is_miss = int(dut.shade_is_miss[L].value)
                for _ in range(latency - 1):
                    await RisingEdge(dut.clk)
                dut.shade_pixel_color[L].value = SKY if is_miss else 0xFFFFFF
                dut.shade_done[L].value        = 1
                await RisingEdge(dut.clk)
                dut.shade_done[L].value        = 0

    for L in range(nlanes):
        cocotb.start_soon(lane(L))
    while True:
        await RisingEdge(dut.clk)


def build_svo_words():
    grid  = svo_builder.build_world()
    root  = svo_builder.build_svo(grid)
    nodes = svo_builder.flatten_svo(root)
    return svo_builder.serialise_nodes(nodes)


async def bram_model(dut, words):
    """1-cycle registered wide BRAM model (matches svo_bram_wide.sv).
    Returns full node (256 bits, word w at [w*32+:32]) when svo_rd_en asserted."""
    def rd(a):
        return int(words[a]) if a < len(words) else 0
    pending_data = None
    dut.svo_rd_wide.value = 0
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')
        if pending_data is not None:
            dut.svo_rd_wide.value = pending_data
        if int(dut.svo_rd_en.value):
            node = int(dut.svo_rd_node.value)
            pending_data = 0
            for w in range(8):
                pending_data |= rd(node * 8 + w) << (w * 32)
        else:
            pending_data = None


async def collect_pixels_axis(dut, pixels):
    """Collect AXI-Stream pixels into list; tuser (SOF) resets the list."""
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



# ── Slot view for the multi-ray core ─────────────────────────────────────────
# Per-ray state lives in [slot] arrays in svo_traversal_mr; _SlotView auto-indexes slot 0.
_PER_RAY_SIGNALS = {
    'step_x', 'step_y', 'step_z', 'rd_x', 'rd_y', 'rd_z', 'ro_x', 'ro_y', 'ro_z',
    'inv_x', 'inv_y', 'inv_z', 't_min', 't_max', 'node_idx', 'node_half',
    'node_origin_x', 'node_origin_y', 'node_origin_z', 'sp', 'bitmask',
    'cx', 'cy', 'cz', 't_next_x', 't_next_y', 't_next_z',
    'dt_x', 'dt_y', 'dt_z', 'cidx', 'pixel_color',
}
_TRACE_SLOT = 0


class _SlotView:
    """Read-only dut wrapper: auto-indexes per-ray array signals to a fixed slot."""
    def __init__(self, dut):
        object.__setattr__(self, '_dut', dut)

    def __getattr__(self, name):
        sig = getattr(self._dut, name)
        return sig[_TRACE_SLOT] if name in _PER_RAY_SIGNALS else sig


async def pixel_tracer(dut, pixel_logs):
    """Log FSM state transitions per pixel. Appends (px, py, lines) to pixel_logs.
    Requires --public-flat-rw in Makefile EXTRA_ARGS to expose internal signals."""
    dut = _SlotView(dut)
    prev_state = -1
    step = 0
    cur_px = cur_py = 0
    cur_lines = []

    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')   # let NBA region commit

        if int(dut.rst.value):
            continue

        state = int(dut.dbg_state.value)
        if state == prev_state:
            continue

        prev_state = state
        step += 1
        sn  = _STATE_NAMES.get(state, f'S_{state}')
        pad = f"  [{step:03d}] {sn:<14s} | "

        if state == 1:   # S_RAY_SETUP: new pixel; flush previous
            if cur_lines:
                pixel_logs.append((cur_px, cur_py, cur_lines))
            cur_px  = int(dut.dbg_px.value)
            cur_py  = int(dut.dbg_py.value)
            cur_lines = []
            step    = 1
            pad     = f"  [{step:03d}] {sn:<14s} | "
            cur_lines.append(pad + f"px={cur_px} py={cur_py}")

        elif state == 2:   # S_ROOT_SLAB: ray params ready
            sx = '+1' if not (int(dut.step_x.value) & 4) else '-1'
            sy = '+1' if not (int(dut.step_y.value) & 4) else '-1'
            sz = '+1' if not (int(dut.step_z.value) & 4) else '-1'
            cur_lines.append(
                pad + f"rd=({_qf(dut.rd_x)},{_qf(dut.rd_y)},{_qf(dut.rd_z)})  "
                      f"ro=({_qf(dut.ro_x)},{_qf(dut.ro_y)},{_qf(dut.ro_z)})\n"
                f"  {'':3s} {'':14s} | inv=({_qf(dut.inv_x)},{_qf(dut.inv_y)},{_qf(dut.inv_z)})  "
                      f"step=({sx},{sy},{sz})"
            )

        elif state == 3:   # S_ENTER_NODE: t_min/t_max valid
            tmin = _qf(dut.t_min); tmax = _qf(dut.t_max)
            nidx = int(dut.node_idx.value); nh = int(dut.node_half.value)
            ox   = int(dut.node_origin_x.value)
            oy   = int(dut.node_origin_y.value)
            oz   = int(dut.node_origin_z.value)
            sp_v = int(dut.sp.value)
            cur_lines.append(
                pad + f"t_min={tmin} t_max={tmax}  node={nidx} half={nh}  "
                      f"origin=({ox},{oy},{oz}) sp={sp_v}"
            )

        elif state == 4:   # S_BRAM_WAIT: reading node words
            nidx = int(dut.node_idx.value)
            cur_lines.append(pad + f"loading BRAM for node={nidx}")

        elif state == 5:   # S_CHECK_CHILD: bitmask and cx/cy/cz valid
            bm   = int(dut.bitmask.value)
            cx_v = int(dut.cx.value)
            cy_v = int(dut.cy.value)
            cz_v = int(dut.cz.value)
            # cidx is computed inside S_CHECK_CHILD so it hasn't committed yet; recompute from cx/cy/cz.
            cidx_v    = ((cz_v & 1) << 2) | ((cy_v & 1) << 1) | (cx_v & 1)
            child_bits = (bm >> (cidx_v * 2)) & 3
            ct        = _CHILD_TYPES.get(child_bits, f'?({child_bits})')
            tnx = _qf(dut.t_next_x); tny = _qf(dut.t_next_y); tnz = _qf(dut.t_next_z)
            tmin = _qf(dut.t_min)
            cur_lines.append(
                pad + f"cx={cx_v} cy={cy_v} cz={cz_v} cidx={cidx_v}  "
                      f"bitmask=0x{bm:04X} → {ct}\n"
                f"  {'':3s} {'':14s} | t_min={tmin}  t_next=({tnx},{tny},{tnz})"
            )

        elif state == 6:   # S_EMPTY: cx/cy/cz are PRE-step values
            cx_v = int(dut.cx.value)
            cy_v = int(dut.cy.value)
            cz_v = int(dut.cz.value)
            tmin = _qf(dut.t_min)
            tnx_f = _from_q16(dut.t_next_x.value)
            tny_f = _from_q16(dut.t_next_y.value)
            tnz_f = _from_q16(dut.t_next_z.value)
            if tnx_f <= tny_f and tnx_f <= tnz_f:
                axis = 'X'
            elif tny_f <= tnz_f:
                axis = 'Y'
            else:
                axis = 'Z'
            dtx = _qf(dut.dt_x); dty = _qf(dut.dt_y); dtz = _qf(dut.dt_z)
            cur_lines.append(
                pad + f"PRE-step: cx={cx_v} cy={cy_v} cz={cz_v}  step_axis={axis}  "
                      f"t_min={tmin}\n"
                f"  {'':3s} {'':14s} | t_next=({tnx_f:+.4f},{tny_f:+.4f},{tnz_f:+.4f})  "
                      f"dt=({dtx},{dty},{dtz})"
            )

        elif state == 7:   # S_SOLID: hit
            tmin  = _qf(dut.t_min)
            sp_v  = int(dut.sp.value)
            cidx_v = int(dut.cidx.value)
            bm    = int(dut.bitmask.value)
            cur_lines.append(
                pad + f"t_hit={tmin}  cidx={cidx_v}  bitmask=0x{bm:04X}  sp={sp_v}  "
                      f"→ SOLID HIT (Phase1: pixel=WHITE)"
            )

        elif state == 8:   # S_MIXED: push stack and descend
            cidx_v = int(dut.cidx.value)
            sp_v   = int(dut.sp.value)     # sp before increment
            cx_v   = int(dut.cx.value)
            cy_v   = int(dut.cy.value)
            cz_v   = int(dut.cz.value)
            nh     = int(dut.node_half.value)
            nidx   = int(dut.node_idx.value)
            cur_lines.append(
                pad + f"descend: cidx={cidx_v}  push sp:{sp_v}→{sp_v+1}  "
                      f"parent_node={nidx} parent_cx/cy/cz=({cx_v},{cy_v},{cz_v}) "
                      f"parent_half={nh}"
            )

        elif state == 9:   # S_POP_STACK: child exhausted, restore parent
            sp_v = int(dut.sp.value)       # sp before pop
            cx_v = int(dut.cx.value)
            cy_v = int(dut.cy.value)
            cz_v = int(dut.cz.value)
            tmin = _qf(dut.t_min)
            cur_lines.append(
                pad + f"pop sp:{sp_v}→{max(0, sp_v-1)}  "
                      f"out-of-bounds cx={cx_v} cy={cy_v} cz={cz_v}  t_min={tmin}"
            )

        elif state == 10:   # S_MISS: ray exited world
            sky   = int(dut.sky_color.value)
            r, g, b = (sky >> 16) & 0xFF, (sky >> 8) & 0xFF, sky & 0xFF
            cur_lines.append(pad + f"sky_color=({r},{g},{b}) → MISS")

        elif state == 11:   # S_WAIT_SHADE: waiting for shade_done (SHADE_MODE=1)
            cur_lines.append(pad + "waiting for shade_done ...")

        elif state == 12:   # S_WRITE_PIXEL: emit pixel over AXI-Stream
            pc    = int(dut.pixel_color.value)
            r, g, b = (pc >> 16) & 0xFF, (pc >> 8) & 0xFF, pc & 0xFF
            result = "HIT" if (r == 255 and g == 255 and b == 255) else "MISS"
            cur_lines.append(
                pad + f"color=({r},{g},{b})  "
                      f"tlast={int(dut.axis_tlast.value)}  "
                      f"tuser={int(dut.axis_tuser.value)}"
            )
            cur_lines.append(f"  RESULT: {result} | color=({r},{g},{b})")

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


@cocotb.test()
async def test_render_frame(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    cocotb.log.info("Building SVO scene ...")
    svo_words = build_svo_words()
    cocotb.log.info(f"  {len(svo_words)} SVO words")

    pixels = []
    pixel_logs = []
    state_counts = {}
    cocotb.start_soon(bram_model(dut, svo_words))
    cocotb.start_soon(collect_pixels_axis(dut, pixels))
    cocotb.start_soon(pixel_tracer(dut, pixel_logs))
    cocotb.start_soon(state_profiler(dut, state_counts))
    # shade_stub handles shade_done/shade_pixel_color; safe in SHADE_MODE=0 too
    cocotb.start_soon(shade_stub(dut))

    # Reset
    dut.rst.value   = 1
    dut.start.value = 0
    dut.max_depth.value = 15   # no LOD cap; 0 would cap at root (all white)
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Camera — must match gen_reference.py.
    pos   = [40.0, 60.0, 10.0]
    fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
    right = normalise(cross(fwd, [0, 1, 0]))
    up    = cross(right, fwd)
    fov_scale = math.tan(math.radians(60) / 2) / (IMG_W / 2)

    dut.cam_pos_x.value   = to_q16(pos[0]);   dut.cam_pos_y.value   = to_q16(pos[1]);   dut.cam_pos_z.value   = to_q16(pos[2])
    dut.cam_right_x.value = to_q16(right[0]); dut.cam_right_y.value = to_q16(right[1]); dut.cam_right_z.value = to_q16(right[2])
    dut.cam_up_x.value    = to_q16(up[0]);    dut.cam_up_y.value    = to_q16(up[1]);    dut.cam_up_z.value    = to_q16(up[2])
    dut.cam_fwd_x.value   = to_q16(fwd[0]);   dut.cam_fwd_y.value   = to_q16(fwd[1]);   dut.cam_fwd_z.value   = to_q16(fwd[2])
    dut.cam_scale.value   = to_q16(fov_scale)
    dut.sky_color.value   = (135 << 16) | (206 << 8) | 235

    await RisingEdge(dut.clk)

    cocotb.log.info("Triggering render ...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = IMG_W * IMG_H * 5000
    for cycle in range(timeout):
        await RisingEdge(dut.clk)
        if dut.frame_done.value:
            cocotb.log.info(f"frame_done at cycle {cycle}")
            break
    else:
        raise cocotb.result.TestFailure(f"Timeout after {timeout} cycles")

    for _ in range(20):   # drain any in-flight pixel
        await RisingEdge(dut.clk)

    assert len(pixels) == IMG_W * IMG_H, \
        f"Expected {IMG_W*IMG_H} pixels, got {len(pixels)}"

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    os.makedirs(os.path.join(os.path.dirname(__file__), 'output'), exist_ok=True)
    out_path = os.path.join(os.path.dirname(__file__), 'output', 'hardware_render.png')
    Image.fromarray(arr, 'RGB').save(out_path)
    cocotb.log.info(f"Saved {out_path}")
    logs_dir   = os.path.join(os.path.dirname(__file__), 'output', 'logs')
    trace_path = os.path.join(logs_dir, 'pixel_trace.txt')
    write_pixel_trace_log(pixel_logs, trace_path)
    profiles_dir = os.path.join(os.path.dirname(__file__), 'output', 'profiles')
    write_state_profile(state_counts, os.path.join(logs_dir, 'state_profile.txt'),
                        IMG_W, IMG_H, archive_dir=profiles_dir, label='phase1')
