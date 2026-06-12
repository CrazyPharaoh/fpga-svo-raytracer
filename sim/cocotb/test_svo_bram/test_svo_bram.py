"""Cocotb tests for svo_bram.sv.

Both ports share the 100 MHz clock (as in top.sv), driven from one coroutine
to avoid cross-domain ordering ambiguity. Registered read latency = 1 cycle.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLK_NS = 10   # 100 MHz


async def _drive_both_clocks(dut):
    half = CLK_NS // 2
    while True:
        dut.clk_a.value = 0
        dut.clk_b.value = 0
        await Timer(half, units="ns")
        dut.clk_a.value = 1
        dut.clk_b.value = 1
        await Timer(half, units="ns")


async def init(dut):
    cocotb.start_soon(_drive_both_clocks(dut))
    dut.en_a.value   = 0
    dut.en_b.value   = 0
    dut.addr_a.value = 0
    dut.din_a.value  = 0
    dut.addr_b.value = 0
    await ClockCycles(dut.clk_a, 4)


async def write_word(dut, addr: int, data: int):
    """Write one 32-bit word to port A (data registered on 2nd posedge)."""
    await RisingEdge(dut.clk_a)
    await Timer(1, units="ns")
    dut.en_a.value   = 1
    dut.addr_a.value = addr
    dut.din_a.value  = data
    await RisingEdge(dut.clk_a)   # write registers here
    await Timer(1, units="ns")
    dut.en_a.value = 0


async def read_word(dut, addr: int) -> int:
    """Read one 32-bit word from port B (1-cycle registered latency)."""
    await RisingEdge(dut.clk_b)
    await Timer(1, units="ns")
    dut.en_b.value   = 1
    dut.addr_b.value = addr
    await RisingEdge(dut.clk_b)   # data latched here
    await Timer(1, units="ns")
    dut.en_b.value = 0
    return int(dut.dout_b.value)


@cocotb.test()
async def test_single_write_read(dut):
    """Write one word and read it back."""
    await init(dut)
    await write_word(dut, 0, 0xDEAD_BEEF)
    got = await read_word(dut, 0)
    assert got == 0xDEAD_BEEF, f"Expected 0xDEADBEEF, got 0x{got:08X}"


@cocotb.test()
async def test_multiple_addresses(dut):
    """Write 16 distinct values (8 words apart = 1 node spacing) then verify each."""
    await init(dut)
    test_data = {100 + i * 8: (0xB000_0000 | i) for i in range(16)}
    for addr, val in test_data.items():
        await write_word(dut, addr, val)
    for addr, expected in test_data.items():
        got = await read_word(dut, addr)
        assert got == expected, (
            f"addr=0x{addr:04X}: expected 0x{expected:08X}, got 0x{got:08X}"
        )


@cocotb.test()
async def test_write_does_not_corrupt_neighbours(dut):
    """Writing address N must not change N±1."""
    await init(dut)
    base = 500   # well away from earlier tests
    await write_word(dut, base,     0x1111_1111)
    await write_word(dut, base + 1, 0x2222_2222)
    await write_word(dut, base + 2, 0x3333_3333)
    await write_word(dut, base + 1, 0xFFFF_FFFF)   # overwrite middle
    assert await read_word(dut, base)     == 0x1111_1111, "Address below corrupted"
    assert await read_word(dut, base + 2) == 0x3333_3333, "Address above corrupted"
    assert await read_word(dut, base + 1) == 0xFFFF_FFFF, "Overwritten address wrong"


@cocotb.test()
async def test_last_address(dut):
    """Write and read the highest valid address (32767)."""
    await init(dut)
    await write_word(dut, 32767, 0xCAFE_BABE)
    got = await read_word(dut, 32767)
    assert got == 0xCAFE_BABE, f"Expected 0xCAFEBABE at top address, got 0x{got:08X}"


@cocotb.test()
async def test_sequential_svo_node(dut):
    """Write a full 8-word SVO node at index 7 and read all words back."""
    await init(dut)
    base = 7 * 8   # node 7 starts at word 56
    node_words = [
        0x0000_0155,   # word 0: bitmask
        0x0002_0001,   # word 1: child_ptr[1]=2, child_ptr[0]=1
        0x0004_0003,   # word 2: child_ptr[3]=4, child_ptr[2]=3
        0x0006_0005,   # word 3
        0x0008_0007,   # word 4
        0x0201_0100,   # word 5: block_ids 0-3
        0x0000_0000,   # word 6: block_ids 4-7
        0x0000_0000,   # word 7: padding
    ]
    for i, w in enumerate(node_words):
        await write_word(dut, base + i, w)
    for i, expected in enumerate(node_words):
        got = await read_word(dut, base + i)
        assert got == expected, (
            f"node word {i}: expected 0x{expected:08X}, got 0x{got:08X}"
        )
