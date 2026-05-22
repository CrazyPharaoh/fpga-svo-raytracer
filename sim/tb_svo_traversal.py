
# sim/tb_svo_traversal.py
import sys, os, math
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'host'))
import svo_builder

IMG_W, IMG_H = 320, 240
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


def build_svo_words():
    grid  = svo_builder.build_world()
    root  = svo_builder.build_svo(grid)
    nodes = svo_builder.flatten_svo(root)
    return svo_builder.serialise_nodes(nodes)


async def bram_model(dut, words):
    """1-cycle registered BRAM model matching svo_bram.sv behaviour.

    svo_bram uses 'always @(posedge clk) if (en) dout <= mem[addr]'.
    Address committed after edge E is sampled by the BRAM at edge E+1 and
    data is valid after E+1 — the FSM reads it at edge E+2.  The pending_data
    pipeline delivers this: sample address this cycle, drive data next cycle.
    Timer(1) waits past the NBA region so committed NB values are visible.
    """
    pending_data = None
    dut.svo_rd_data.value = 0
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')
        if pending_data is not None:
            dut.svo_rd_data.value = pending_data
        if int(dut.svo_rd_en.value):
            addr = int(dut.svo_rd_addr.value)
            pending_data = int(words[addr]) if addr < len(words) else 0
        else:
            pending_data = None


async def collect_pixels_axis(dut, pixels):
    """Collect pixels from AXI-Stream output; log progress every 1000 pixels."""
    dut.axis_tready.value = 1
    while len(pixels) < IMG_W * IMG_H:
        await RisingEdge(dut.clk)
        if dut.axis_tvalid.value and dut.axis_tready.value:
            if dut.axis_tuser.value:
                pixels.clear()  # SOF: restart collection
            tdata = int(dut.axis_tdata.value) & 0xFFFF_FFFF
            pixels.append(((tdata >> 16) & 0xFF, (tdata >> 8) & 0xFF, tdata & 0xFF))
            if len(pixels) % 1000 == 0:
                cocotb.log.info(f"  {len(pixels)}/{IMG_W*IMG_H} pixels collected")


@cocotb.test()
async def test_render_frame(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    cocotb.log.info("Building SVO scene ...")
    svo_words = build_svo_words()
    cocotb.log.info(f"  {len(svo_words)} SVO words")

    # Tie off shading pipeline inputs (unused in SHADE_MODE=0)
    dut.shade_done.value        = 0
    dut.shade_pixel_color.value = 0

    pixels = []
    cocotb.start_soon(bram_model(dut, svo_words))
    cocotb.start_soon(collect_pixels_axis(dut, pixels))

    # Reset
    dut.rst.value   = 1
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Camera — matches main_phase1.py
    pos   = [40.0, 60.0, 10.0]
    fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])
    right = normalise(cross(fwd, [0, 1, 0]))
    up    = cross(right, fwd)
    fov_scale = math.tan(math.radians(60) / 2) / 160.0

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

    # Wait for frame_done
    timeout = IMG_W * IMG_H * 5000
    for cycle in range(timeout):
        await RisingEdge(dut.clk)
        if dut.frame_done.value:
            cocotb.log.info(f"frame_done at cycle {cycle}")
            break
    else:
        raise cocotb.result.TestFailure(f"Timeout after {timeout} cycles")

    # Drain any in-flight pixel
    for _ in range(20):
        await RisingEdge(dut.clk)

    assert len(pixels) == IMG_W * IMG_H, \
        f"Expected {IMG_W*IMG_H} pixels, got {len(pixels)}"

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    os.makedirs(os.path.join(os.path.dirname(__file__), 'output'), exist_ok=True)
    out_path = os.path.join(os.path.dirname(__file__), 'output', 'hardware_render.png')
    Image.fromarray(arr, 'RGB').save(out_path)
    cocotb.log.info(f"Saved {out_path}")
