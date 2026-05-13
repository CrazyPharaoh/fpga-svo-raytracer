"""
Cocotb tests for hdmi_timing.sv

Run:  cd sim/cocotb/test_hdmi_timing && make
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

# 640×480 @ 60 Hz VESA timings
H_ACTIVE, H_FP, H_SYNC, H_BP = 640, 16, 96, 48
V_ACTIVE, V_FP, V_SYNC, V_BP = 480, 10,  2, 33
H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP  # 800
V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP  # 525
PIXELS_PER_FRAME = H_ACTIVE * V_ACTIVE       # 307200


async def reset(dut):
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 4)
    dut.rst.value = 0
    await RisingEdge(dut.clk_pixel)


@cocotb.test()
async def test_reset_clears_counters(dut):
    """After reset hx and hy must be 0."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())  # ~25.175 MHz
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 4)
    assert int(dut.hx.value) == 0, f"hx={int(dut.hx.value)} after reset"
    assert int(dut.hy.value) == 0, f"hy={int(dut.hy.value)} after reset"


@cocotb.test()
async def test_hx_increments_each_cycle(dut):
    """hx must increment by 1 every pixel clock after reset."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    for expected in range(1, 10):
        await RisingEdge(dut.clk_pixel)
        assert int(dut.hx.value) == expected, (
            f"hx={int(dut.hx.value)}, expected {expected}"
        )


@cocotb.test()
async def test_hx_wraps_at_h_total(dut):
    """hx must wrap from H_TOTAL-1 back to 0 and hy must increment."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    # Run to the last column of line 0
    await ClockCycles(dut.clk_pixel, H_TOTAL - 1)
    assert int(dut.hx.value) == H_TOTAL - 1
    assert int(dut.hy.value) == 0
    # One more clock → hx wraps, hy increments
    await RisingEdge(dut.clk_pixel)
    assert int(dut.hx.value) == 0, f"hx={int(dut.hx.value)} expected 0 after wrap"
    assert int(dut.hy.value) == 1, f"hy={int(dut.hy.value)} expected 1"


@cocotb.test()
async def test_hy_wraps_at_v_total(dut):
    """hy must wrap to 0 after V_TOTAL lines."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    # Advance to last pixel of last line
    await ClockCycles(dut.clk_pixel, H_TOTAL * V_TOTAL - 1)
    assert int(dut.hy.value) == V_TOTAL - 1
    # One more clock → both wrap
    await RisingEdge(dut.clk_pixel)
    assert int(dut.hx.value) == 0
    assert int(dut.hy.value) == 0


@cocotb.test()
async def test_active_pixel_count_per_frame(dut):
    """Exactly H_ACTIVE*V_ACTIVE pixels must have data_en=1 per frame."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    active = 0
    for _ in range(H_TOTAL * V_TOTAL):
        await RisingEdge(dut.clk_pixel)
        if dut.data_en.value == 1:
            active += 1
    assert active == PIXELS_PER_FRAME, (
        f"active pixels={active}, expected {PIXELS_PER_FRAME}"
    )


@cocotb.test()
async def test_hsync_polarity_and_position(dut):
    """hsync must be low (active) only in columns [H_ACTIVE+H_FP, H_ACTIVE+H_FP+H_SYNC)."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    sync_start = H_ACTIVE + H_FP
    sync_end   = sync_start + H_SYNC
    for col in range(H_TOTAL):
        await RisingEdge(dut.clk_pixel)
        expected_low = (sync_start <= int(dut.hx.value) < sync_end)
        got_low      = (int(dut.hsync.value) == 0)
        assert got_low == expected_low, (
            f"hsync wrong at hx={int(dut.hx.value)}: got={int(dut.hsync.value)}"
        )


@cocotb.test()
async def test_vsync_polarity_and_position(dut):
    """vsync must be low only on lines [V_ACTIVE+V_FP, V_ACTIVE+V_FP+V_SYNC)."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    sync_start = V_ACTIVE + V_FP
    sync_end   = sync_start + V_SYNC
    # Sample vsync at hx=0 for each line
    for line in range(V_TOTAL):
        # Wait until hx==0 for this line (it already is at start, then each H_TOTAL clocks)
        if line > 0:
            await ClockCycles(dut.clk_pixel, H_TOTAL)
        expected_low = (sync_start <= line < sync_end)
        got_low      = (int(dut.vsync.value) == 0)
        assert got_low == expected_low, (
            f"vsync wrong at line {line}: got={int(dut.vsync.value)}"
        )


@cocotb.test()
async def test_data_en_only_in_active_region(dut):
    """data_en must be 0 outside the 640×480 active window."""
    cocotb.start_soon(Clock(dut.clk_pixel, 39_720, units="ps").start())
    await reset(dut)
    for _ in range(H_TOTAL * V_TOTAL):
        await RisingEdge(dut.clk_pixel)
        hx = int(dut.hx.value)
        hy = int(dut.hy.value)
        de = int(dut.data_en.value)
        expected = 1 if (hx < H_ACTIVE and hy < V_ACTIVE) else 0
        assert de == expected, (
            f"data_en={de} at hx={hx} hy={hy}, expected {expected}"
        )
