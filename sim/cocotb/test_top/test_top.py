"""Cocotb integration tests for top.sv (SHADE_MODE=0, Phase 1).

rgb2dvi is not present in simulation; HDMI outputs are driven directly by top.sv.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import math

SYS_CLK_NS  = 10
PIX_CLK_NS  = 40
TIMEOUT_NS  = 15_000_000  # 15 ms — one 320×240 frame budget at 100 MHz
IMG_W, IMG_H = 320, 240


def to_q16(f):
    return int(f * 65536) & 0xFFFF_FFFF


def pack_rgb(r, g, b):
    return (int(r) & 0xFF) | ((int(g) & 0xFF) << 8) | ((int(b) & 0xFF) << 16)


def build_all_empty_svo_words():
    """8 words for a single all-empty root node (bitmask=0)."""
    return [0x0000, 0, 0, 0, 0, 0, 0, 0]


async def axi_write(dut, addr: int, data: int):
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_awaddr.value  = addr
    dut.s_axi_awvalid.value = 1
    dut.s_axi_wdata.value   = data
    dut.s_axi_wstrb.value   = 0xF
    dut.s_axi_wvalid.value  = 1
    dut.s_axi_bready.value  = 1
    while not dut.s_axi_awready.value:
        await RisingEdge(dut.s_axi_aclk)
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_awvalid.value = 0
    dut.s_axi_wvalid.value  = 0
    while not dut.s_axi_bvalid.value:
        await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_bready.value = 0
    await RisingEdge(dut.s_axi_aclk)


async def reset(dut):
    cocotb.start_soon(Clock(dut.s_axi_aclk, SYS_CLK_NS, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_pixel,  PIX_CLK_NS,  units="ns").start())
    dut.s_axi_aresetn.value  = 0
    dut.s_axi_awvalid.value  = 0
    dut.s_axi_wvalid.value   = 0
    dut.s_axi_bready.value   = 0
    dut.s_axi_arvalid.value  = 0
    dut.s_axi_rready.value   = 0
    dut.s_axi_awaddr.value   = 0
    dut.s_axi_wdata.value    = 0
    dut.s_axi_wstrb.value    = 0xF
    dut.s_axi_araddr.value   = 0
    await ClockCycles(dut.s_axi_aclk, 8)
    dut.s_axi_aresetn.value = 1
    await ClockCycles(dut.s_axi_aclk, 4)


async def load_svo(dut, words):
    await axi_write(dut, 0x48, 0)
    for w in words:
        await axi_write(dut, 0x4C, w)


async def set_camera(dut):
    """Camera at (32,32,-5) looking along +Z."""
    vals = [32.0, 32.0, -5.0,   # pos
             1.0,  0.0,  0.0,   # right
             0.0,  1.0,  0.0,   # up
             0.0,  0.0,  1.0]   # fwd
    for off, v in zip(range(0x08, 0x38, 4), vals):
        await axi_write(dut, off, to_q16(v))
    await axi_write(dut, 0x38, to_q16(math.tan(math.radians(30)) / 160))  # cam_scale = tan(30°)/160
    await axi_write(dut, 0x68, pack_rgb(135, 206, 235))  # sky colour


async def trigger_and_wait(dut) -> bool:
    """Write CTRL=1, poll until irq pulses; returns True if done within timeout."""
    await axi_write(dut, 0x00, 1)
    max_cycles = TIMEOUT_NS // SYS_CLK_NS
    for _ in range(max_cycles):
        await RisingEdge(dut.s_axi_aclk)
        if int(dut.irq.value) == 1:
            return True
    return False


@cocotb.test()
async def test_irq_pulses_after_render(dut):
    """irq must pulse once after a complete frame is rendered."""
    await reset(dut)
    await load_svo(dut, build_all_empty_svo_words())
    await set_camera(dut)
    done = await trigger_and_wait(dut)
    assert done, f"irq never pulsed within {TIMEOUT_NS} ns"


@cocotb.test()
async def test_second_render_after_first(dut):
    """A second trigger after the first frame_done must produce another irq."""
    await reset(dut)
    await load_svo(dut, build_all_empty_svo_words())
    await set_camera(dut)
    assert await trigger_and_wait(dut), "First frame did not complete"
    await ClockCycles(dut.s_axi_aclk, 4)
    assert await trigger_and_wait(dut), "Second frame did not complete"


@cocotb.test()
async def test_hdmi_data_en_active_per_frame(dut):
    """data_en on the HDMI path must be high for exactly 640×480 clocks per frame."""
    await reset(dut)

    de_count = 0

    async def count_de():
        nonlocal de_count
        for _ in range(800 * 525):
            await RisingEdge(dut.clk_pixel)
            if int(dut.hdmi_de.value) == 1:
                de_count += 1

    cocotb.start_soon(count_de())
    await ClockCycles(dut.clk_pixel, 800 * 525)
    assert de_count == 640 * 480, (
        f"HDMI data_en active for {de_count} clocks, expected {640*480}"
    )


@cocotb.test()
async def test_busy_signal_visible_via_axi(dut):
    """STATUS.busy must be 1 while a render is in progress."""
    await reset(dut)
    await load_svo(dut, build_all_empty_svo_words())
    await set_camera(dut)

    # Trigger without using the helper so STATUS can be sampled before the frame finishes
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_awaddr.value  = 0x00
    dut.s_axi_awvalid.value = 1
    dut.s_axi_wdata.value   = 1
    dut.s_axi_wstrb.value   = 0xF
    dut.s_axi_wvalid.value  = 1
    dut.s_axi_bready.value  = 1
    while not dut.s_axi_awready.value:
        await RisingEdge(dut.s_axi_aclk)
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_awvalid.value = 0
    dut.s_axi_wvalid.value  = 0
    await ClockCycles(dut.s_axi_aclk, 2)
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_araddr.value  = 0x04
    dut.s_axi_arvalid.value = 1
    dut.s_axi_rready.value  = 1
    while not int(dut.s_axi_arready.value):
        await RisingEdge(dut.s_axi_aclk)
    await RisingEdge(dut.s_axi_aclk)
    dut.s_axi_arvalid.value = 0
    while not int(dut.s_axi_rvalid.value):
        await RisingEdge(dut.s_axi_aclk)
    status = int(dut.s_axi_rdata.value)
    dut.s_axi_rready.value = 0

    assert status & 0x1, (
        f"STATUS.busy=0 during render (STATUS=0x{status:08X})"
    )
