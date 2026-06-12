"""Cocotb tests for svo_traversal.sv — runs with Verilator.

Verilator fires VPI callbacks before NBA commits, so NB-assigned signals are not
yet visible when RisingEdge returns. Two consequences:
1. bram_model adds a one-cycle pipeline delay (pending_data) to match svo_bram.sv's
   registered output (address at edge E → data at edge E+1 → FSM reads at E+2).
2. NB-assigned signals (e.g. busy) must be checked on the FOLLOWING clock cycle.

--x-initial 0 (Makefile.common) ensures all signals start at 0.
"""
import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import math

CLK_NS    = 10
# RENDER_DIV crops the frame (same FOV) so the sim fits within MAX_CYCLES.
# Must match -GIMG_W/-GIMG_H in the Makefile.
RENDER_DIV = int(os.environ.get('RENDER_DIV', '5'))
IMG_W     = 320 // RENDER_DIV
IMG_H     = 240 // RENDER_DIV
MAX_CYCLES = 3_000_000

STATE_EMPTY = 0b00
STATE_SOLID = 0b11
STATE_MIXED = 0b01


def to_q16(f):
    return int(f * 65536) & 0xFFFF_FFFF


def build_node_words(bitmask, children, block_ids):
    words = [bitmask & 0xFFFF]
    for i in range(0, 8, 2):
        words.append(((children[i + 1] & 0xFFFF) << 16) | (children[i] & 0xFFFF))
    for i in range(0, 8, 4):
        w = 0
        for j in range(4):
            w |= (block_ids[i + j] & 0xFF) << (j * 8)
        words.append(w)
    words.append(0)
    return words


def all_solid_root():
    bitmask = sum(STATE_SOLID << (i * 2) for i in range(8))
    return build_node_words(bitmask, [0] * 8, [1] * 8)


def all_empty_root():
    return build_node_words(0x0000, [0] * 8, [0] * 8)


async def reset_dut(dut):
    dut.svo_rd_data.value    = 0
    dut.max_depth.value      = 15  # disable the depth cap (>= any real tree depth)
    dut.axis_tready.value    = 1   # hold high; S_WRITE_PIXEL stalls if 0
    dut.shade_done.value     = 0   # unused in SHADE_MODE=0
    dut.shade_pixel_color.value = 0
    dut.rst.value   = 1
    dut.start.value = 0
    await ClockCycles(dut.clk, 6)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 2)


def set_camera_looking_in(dut):
    """Camera at (32, 32, -5) looking along +Z."""
    dut.cam_pos_x.value   = to_q16( 32.0)
    dut.cam_pos_y.value   = to_q16( 32.0)
    dut.cam_pos_z.value   = to_q16( -5.0)
    dut.cam_fwd_x.value   = to_q16(  0.0)
    dut.cam_fwd_y.value   = to_q16(  0.0)
    dut.cam_fwd_z.value   = to_q16(  1.0)
    dut.cam_right_x.value = to_q16(  1.0)
    dut.cam_right_y.value = to_q16(  0.0)
    dut.cam_right_z.value = to_q16(  0.0)
    dut.cam_up_x.value    = to_q16(  0.0)
    dut.cam_up_y.value    = to_q16(  1.0)
    dut.cam_up_z.value    = to_q16(  0.0)
    # cam_scale = tan(FOV/2) / (IMG_W/2); use cropped IMG_W to keep FOV constant
    dut.cam_scale.value   = to_q16(math.tan(math.radians(30)) / (IMG_W / 2))
    dut.sky_color.value   = 0x87CEEB


async def bram_model(dut, mem: dict):
    """Python model of svo_bram.sv port B (1-cycle registered read).

    svo_bram: `always @(posedge clk_b) if (en_b) dout_b <= mem[addr_b]`.
    Address at edge E → dout_b valid after E+1 → FSM reads at E+2.
    S_BRAM_WAIT/field=7 is the wait state that absorbs this 2-edge delay.
    Timer(1) is required so Verilator NBA commits are visible before we sample.
    """
    pending_data = None
    dut.svo_rd_data.value = 0
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        if pending_data is not None:
            dut.svo_rd_data.value = pending_data
        if int(dut.svo_rd_en.value) == 1:
            pending_data = mem.get(int(dut.svo_rd_addr.value), 0)
        else:
            pending_data = None


async def axis_sink(dut, pixels: list):
    """Collect AXI-Stream pixels as (sequential_index, 24-bit_colour) tuples."""
    while True:
        await RisingEdge(dut.clk)
        if int(dut.axis_tvalid.value) and int(dut.axis_tready.value):
            tdata = int(dut.axis_tdata.value)
            pixels.append((len(pixels), tdata & 0xFF_FFFF))


async def trigger_render(dut):
    """Pulse start for one cycle."""
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0


async def wait_for_frame_done(dut, max_cycles: int = MAX_CYCLES) -> bool:
    """Poll frame_done for up to max_cycles; returns True if seen."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if int(dut.frame_done.value) == 1:
            return True
    return False


@cocotb.test()
async def test_frame_done_pulses(dut):
    """frame_done must pulse at least once after a render completes."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    await reset_dut(dut)
    set_camera_looking_in(dut)

    mem = {i: w for i, w in enumerate(all_empty_root())}
    cocotb.start_soon(bram_model(dut, mem))

    await trigger_render(dut)
    done = await wait_for_frame_done(dut)
    assert done, f"frame_done never pulsed within {MAX_CYCLES} cycles"


@cocotb.test()
async def test_busy_deasserts_after_frame(dut):
    """busy must be 1 during render and 0 after frame_done."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    await reset_dut(dut)
    set_camera_looking_in(dut)

    mem = {i: w for i, w in enumerate(all_empty_root())}
    cocotb.start_soon(bram_model(dut, mem))

    await trigger_render(dut)
    await RisingEdge(dut.clk)  # NB commit not visible until next cycle (Verilator)
    assert int(dut.busy.value) == 1, "busy not asserted after start"

    done = await wait_for_frame_done(dut)
    assert done, "Timed out waiting for frame_done"

    await RisingEdge(dut.clk)
    assert int(dut.busy.value) == 0, "busy must de-assert after frame_done"


@cocotb.test()
async def test_all_miss_writes_sky_colour(dut):
    """With an all-empty SVO every pixel must be written with sky_color."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    await reset_dut(dut)
    set_camera_looking_in(dut)
    dut.sky_color.value = 0x87CEEB

    mem    = {i: w for i, w in enumerate(all_empty_root())}
    pixels = []
    cocotb.start_soon(bram_model(dut, mem))
    cocotb.start_soon(axis_sink(dut, pixels))

    await trigger_render(dut)
    assert await wait_for_frame_done(dut), "Timed out"

    assert len(pixels) == IMG_W * IMG_H, (
        f"Expected {IMG_W*IMG_H} writes, got {len(pixels)}"
    )
    wrong = [(a, c) for a, c in pixels if c != 0x87CEEB]
    assert not wrong, f"{len(wrong)} pixels were not sky colour: {wrong[:5]}"


@cocotb.test()
async def test_all_solid_writes_white(dut):
    """With an all-solid root node every pixel must be white (Phase 1)."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    await reset_dut(dut)
    set_camera_looking_in(dut)
    dut.sky_color.value = 0x87CEEB

    mem    = {i: w for i, w in enumerate(all_solid_root())}
    pixels = []
    cocotb.start_soon(bram_model(dut, mem))
    cocotb.start_soon(axis_sink(dut, pixels))

    await trigger_render(dut)
    assert await wait_for_frame_done(dut), "Timed out"

    assert len(pixels) == IMG_W * IMG_H, (
        f"Expected {IMG_W*IMG_H} writes, got {len(pixels)}"
    )
    non_white = [(a, c) for a, c in pixels if c != 0xFF_FF_FF]
    assert not non_white, (
        f"{len(non_white)} pixels were not white: {non_white[:5]}"
    )


@cocotb.test()
async def test_pixel_addresses_cover_full_frame(dut):
    """Every framebuffer address 0..76799 must be written exactly once."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    await reset_dut(dut)
    set_camera_looking_in(dut)

    mem    = {i: w for i, w in enumerate(all_empty_root())}
    pixels = []
    cocotb.start_soon(bram_model(dut, mem))
    cocotb.start_soon(axis_sink(dut, pixels))

    await trigger_render(dut)
    assert await wait_for_frame_done(dut), "Timed out"

    written = sorted(a for a, _ in pixels)
    assert written == list(range(IMG_W * IMG_H)), (
        "Pixel addresses do not cover 0..76799 exactly once"
    )
