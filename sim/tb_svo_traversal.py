
# sim/tb_svo_traversal.py
import sys, os, math
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
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
    """1-cycle registered BRAM model.
    In cocotb+Verilator, Python coroutines run after the DUT's always_ff
    evaluation at each rising edge — so signals written after a RisingEdge
    only become visible to the DUT at the *next* rising edge's pre-edge sample.
    By responding on the FallingEdge (half-cycle later), the written value is
    stable before the next rising edge, giving the DUT 1-cycle read latency."""
    dbg = 0
    while True:
        await FallingEdge(dut.clk)
        if dut.svo_rd_en.value:
            addr = int(dut.svo_rd_addr.value)
            data = int(words[addr]) if addr < len(words) else 0
            dut.svo_rd_data.value = data
            if dbg < 16:
                cocotb.log.info(f"BRAM rd: addr={addr} data={data:#010x}")
                dbg += 1


async def collect_pixels_axis(dut, pixels):
    """Collect pixels from AXI-Stream output (axis_tvalid/tdata)."""
    dut.axis_tready.value = 1
    while len(pixels) < IMG_W * IMG_H:
        await RisingEdge(dut.clk)
        if dut.axis_tvalid.value and dut.axis_tready.value:
            if dut.axis_tuser.value:
                pixels.clear()  # SOF: restart collection
            tdata = int(dut.axis_tdata.value) & 0xFFFF_FFFF
            pixels.append(((tdata >> 16) & 0xFF, (tdata >> 8) & 0xFF, tdata & 0xFF))


async def collect_pixels_bram(dut, pixels):
    """Collect pixels from legacy fb_wr_en/fb_wr_addr/fb_wr_data interface."""
    frame_buf = {}
    while True:
        await RisingEdge(dut.clk)
        if dut.fb_wr_en.value:
            addr  = int(dut.fb_wr_addr.value)
            data  = int(dut.fb_wr_data.value) & 0xFFFFFF
            frame_buf[addr] = ((data >> 16) & 0xFF, (data >> 8) & 0xFF, data & 0xFF)
        if dut.frame_done.value:
            # Reconstruct raster-order pixel list from address map
            pixels.clear()
            for py in range(IMG_H):
                for px in range(IMG_W):
                    addr = py * IMG_W + px
                    pixels.append(frame_buf.get(addr, (0, 0, 0)))
            break


STATE_NAMES = {0:'IDLE',1:'RAY_SETUP',2:'ROOT_SLAB',3:'ENTER_NODE',4:'BRAM_WAIT',
               5:'CHECK_CHILD',6:'EMPTY',7:'SOLID',8:'MIXED',9:'POP_STACK',
               10:'MISS',11:'WAIT_SHADE',12:'WRITE_PIXEL',13:'NEXT_PIXEL'}

async def debug_first_pixel(dut):
    """Trace first 30 cycles of pixel (160,120)."""
    started = False
    cycle_count = 0
    MAX_CYCLES = 30
    while cycle_count < MAX_CYCLES:
        await RisingEdge(dut.clk)
        try:
            px  = int(dut.px.value)
            py  = int(dut.py.value)
            st  = int(dut.state_raw.value)
            if px == 160 and py == 120:
                started = True
            if started:
                cycle_count += 1
                sn = STATE_NAMES.get(st, f'S{st}')
                tm  = int(dut.t_min.value)
                cx  = int(dut.cx.value)
                cy  = int(dut.cy.value)
                cz  = int(dut.cz.value)
                rbm = int(dut.r_bitmask.value)
                cid = int(dut.cidx.value)
                bf  = int(dut.bram_field.value)
                rd  = int(dut.svo_rd_data.value)
                cocotb.log.info(
                    f"[trace160] cy#{cycle_count:03d} state={sn} "
                    f"t_min={tm:#010x} cx={cx} cy={cy} cz={cz} "
                    f"r_bitmask={rbm:#06x} cidx={cid} "
                    f"bram_field={bf} svo_rd_data={rd:#010x}"
                )
        except Exception as e:
            cocotb.log.warning(f"[trace160] exception: {e}")


@cocotb.test()
async def test_render_frame(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())

    cocotb.log.info("Building SVO scene ...")
    svo_words = build_svo_words()
    cocotb.log.info(f"  {len(svo_words)} SVO words")

    # Tie off shading pipeline inputs
    dut.shade_done.value        = 0
    dut.shade_pixel_color.value = 0

    # Detect which output interface is present
    has_axis = hasattr(dut, 'axis_tvalid')
    cocotb.log.info(f"Output interface: {'AXI-Stream' if has_axis else 'BRAM fb_wr'}")

    cocotb.start_soon(bram_model(dut, svo_words))
    cocotb.start_soon(debug_first_pixel(dut))

    pixels = []
    if has_axis:
        sink_task = cocotb.start_soon(collect_pixels_axis(dut, pixels))

    # Reset
    dut.rst.value   = 1
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Camera -- matches main_phase1.py
    pos   = [32.0, 40.0, -20.0]
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

    # Start render
    cocotb.log.info("Triggering render ...")

    if not has_axis:
        bram_sink = cocotb.start_soon(collect_pixels_bram(dut, pixels))

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for frame_done with timeout
    timeout = IMG_W * IMG_H * 5000
    for cycle in range(timeout):
        await RisingEdge(dut.clk)
        if dut.frame_done.value:
            cocotb.log.info(f"frame_done at cycle {cycle}")
            break
    else:
        raise cocotb.result.TestFailure(f"Timeout after {timeout} cycles waiting for frame_done")

    # Drain final pixels
    for _ in range(20):
        await RisingEdge(dut.clk)

    assert len(pixels) == IMG_W * IMG_H, \
        f"Expected {IMG_W*IMG_H} pixels, got {len(pixels)}"

    arr = np.array(pixels, dtype=np.uint8).reshape(IMG_H, IMG_W, 3)
    os.makedirs(os.path.join(os.path.dirname(__file__), 'output'), exist_ok=True)
    out_path = os.path.join(os.path.dirname(__file__), 'output', 'hardware_render.png')
    Image.fromarray(arr, 'RGB').save(out_path)
    cocotb.log.info(f"Saved {out_path}")
