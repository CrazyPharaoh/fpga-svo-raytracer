"""Cocotb tests for svo_bram_shadow.sv (geometry-only shadow SVO RAM, GW=5).

Port A writes words 0..7; only words 0..4 are stored (geometry planes only).
Port B reads with 1-cycle latency: words 0..4 return as written, words 5..7 return 0.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLK_NS = 10  # 100 MHz


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    dut.en_a.value = 0
    dut.addr_a.value = 0
    dut.din_a.value = 0
    dut.addr_b.value = 0
    await ClockCycles(dut.clk, 4)


def node_addr(node: int, word: int) -> int:
    return (node << 3) | (word & 0x7)


async def write_word(dut, node: int, word: int, data: int):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.en_a.value = 1
    dut.addr_a.value = node_addr(node, word)
    dut.din_a.value = data
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.en_a.value = 0


async def read_word(dut, node: int, word: int) -> int:
    """Read one word from port B (1-cycle registered latency)."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.addr_b.value = node_addr(node, word)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    return int(dut.dout_b.value)


@cocotb.test()
async def test_geometry_words_readback(dut):
    """Words 0..4 read back what was written; words 5..7 read 0."""
    await init(dut)
    node = 7
    vals = {w: (0xC0DE_0000 | (w << 8) | 0x11 * w) for w in range(8)}
    for w in range(8):
        await write_word(dut, node, w, vals[w])
    for w in range(5):
        got = await read_word(dut, node, w)
        assert got == vals[w], f"word {w}: got 0x{got:08X} expected 0x{vals[w]:08X}"
    for w in range(5, 8):
        got = await read_word(dut, node, w)
        assert got == 0, f"word {w} (unused): got 0x{got:08X} expected 0"


@cocotb.test()
async def test_two_nodes_independent(dut):
    """Different nodes keep independent geometry words."""
    await init(dut)
    for w in range(5):
        await write_word(dut, 3, w, 0xA000_0000 | w)
        await write_word(dut, 9, w, 0xB000_0000 | w)
    for w in range(5):
        assert (await read_word(dut, 3, w)) == (0xA000_0000 | w)
        assert (await read_word(dut, 9, w)) == (0xB000_0000 | w)


@cocotb.test()
async def test_sequential_word_reads(dut):
    """Back-to-back reads of words 0..4 (matching the traversal's field sequence) track
    the 1-cycle-delayed address correctly with no stale data."""
    await init(dut)
    node = 21
    for w in range(5):
        await write_word(dut, node, w, 0x5A5A_0000 | w)
    # issue reads with addr changing every cycle, sample with the registered latency
    await RisingEdge(dut.clk); await Timer(1, unit="ns")
    dut.addr_b.value = node_addr(node, 0)
    seen = []
    for w in range(1, 6):
        await RisingEdge(dut.clk); await Timer(1, unit="ns")
        dut.addr_b.value = node_addr(node, w & 0x7)
        seen.append(int(dut.dout_b.value))  # reflects PREVIOUS addr (w-1)
    for w in range(5):
        exp = 0x5A5A_0000 | w
        assert seen[w] == exp, f"seq word {w}: got 0x{seen[w]:08X} expected 0x{exp:08X}"
