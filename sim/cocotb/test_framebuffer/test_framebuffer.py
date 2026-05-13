"""
Cocotb tests for framebuffer.sv

wr_clk runs at 100 MHz (ray pipeline).
rd_clk runs at 25 MHz (pixel clock) — period 4× longer.

After a write on wr_clk we must wait for enough rd_clk cycles for the data to
cross the clock domain before reading.  We wait using Timer so that both clock
domains advance independently, then check rd_data after enough rd_clk cycles.

Each test uses a unique address range to prevent result contamination between
the shared-state tests.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

WR_CLK_NS = 10    # 100 MHz
RD_CLK_NS = 40    # 25 MHz
FB_SIZE   = 320 * 240   # 76800 pixels

# Per-test address slots (non-overlapping)
ADDR = {
    "single":    0,
    "last":      FB_SIZE - 1,
    "multi":     list(range(200, 250)),   # 50 addresses
    "overwrite": 1000,
    "rd_en":     2000,
}


async def write_pixel(dut, addr: int, rgb: int):
    """Write one pixel via the write port (registered on 2nd posedge)."""
    await RisingEdge(dut.wr_clk)
    await Timer(1, units="ns")    # step past the edge before driving
    dut.wr_en.value   = 1
    dut.wr_addr.value = addr
    dut.wr_data.value = rgb
    await RisingEdge(dut.wr_clk)  # write registers here
    await Timer(1, units="ns")
    dut.wr_en.value = 0


async def read_pixel(dut, addr: int) -> int:
    """Read with 1-cycle registered latency on rd_clk."""
    await RisingEdge(dut.rd_clk)
    await Timer(1, units="ns")     # step past the edge
    dut.rd_en.value   = 1
    dut.rd_addr.value = addr
    await RisingEdge(dut.rd_clk)  # data latched here
    await Timer(1, units="ns")
    dut.rd_en.value = 0
    return int(dut.rd_data.value)


async def cdc_wait(dut):
    """Wait long enough for a wr_clk write to be visible on rd_clk."""
    await Timer(RD_CLK_NS * 4, units="ns")   # 4 full rd_clk periods


async def start_clocks(dut):
    cocotb.start_soon(Clock(dut.wr_clk, WR_CLK_NS, units="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, RD_CLK_NS, units="ns").start())
    dut.wr_en.value   = 0
    dut.rd_en.value   = 0
    dut.wr_addr.value = 0
    dut.rd_addr.value = 0
    dut.wr_data.value = 0
    await ClockCycles(dut.wr_clk, 4)


@cocotb.test()
async def test_write_read_single_pixel(dut):
    """Write one pixel and read it back."""
    await start_clocks(dut)
    await write_pixel(dut, ADDR["single"], 0xFF_80_40)
    await cdc_wait(dut)
    got = await read_pixel(dut, ADDR["single"])
    assert got == 0xFF_80_40, f"Expected 0xFF8040, got 0x{got:06X}"


@cocotb.test()
async def test_write_read_last_pixel(dut):
    """Write and read the last pixel address (76799)."""
    await start_clocks(dut)
    await write_pixel(dut, ADDR["last"], 0x12_34_56)
    await cdc_wait(dut)
    got = await read_pixel(dut, ADDR["last"])
    assert got == 0x12_34_56, f"Expected 0x123456, got 0x{got:06X}"


@cocotb.test()
async def test_multiple_pixels_no_corruption(dut):
    """Write 10 distinct pixels and verify each reads back correctly."""
    await start_clocks(dut)
    addrs = ADDR["multi"][:10]
    pixels = {a: (0x10_00_00 + i * 0x01_01_01) & 0xFF_FF_FF
              for i, a in enumerate(addrs)}
    for a, rgb in pixels.items():
        await write_pixel(dut, a, rgb)
    await cdc_wait(dut)
    for a, expected in pixels.items():
        got = await read_pixel(dut, a)
        assert got == expected, (
            f"addr={a}: expected 0x{expected:06X}, got 0x{got:06X}"
        )


@cocotb.test()
async def test_write_overwrites_previous_value(dut):
    """Writing the same address twice keeps only the latest value."""
    await start_clocks(dut)
    addr = ADDR["overwrite"]
    await write_pixel(dut, addr, 0xAA_BB_CC)
    await cdc_wait(dut)
    await write_pixel(dut, addr, 0x11_22_33)
    await cdc_wait(dut)
    got = await read_pixel(dut, addr)
    assert got == 0x11_22_33, f"Expected latest 0x112233, got 0x{got:06X}"


@cocotb.test()
async def test_rd_en_gates_update(dut):
    """When rd_en goes low the output holds its last-read value."""
    await start_clocks(dut)
    addr = ADDR["rd_en"]
    await write_pixel(dut, addr, 0x55_66_77)
    await cdc_wait(dut)
    first = await read_pixel(dut, addr)
    assert first == 0x55_66_77, f"First read: expected 0x556677, got 0x{first:06X}"
    # rd_en is now 0; rd_data should hold the latched value
    await ClockCycles(dut.rd_clk, 3)
    still = int(dut.rd_data.value)
    assert still == 0x55_66_77, (
        f"rd_data changed while rd_en=0: now 0x{still:06X}"
    )
