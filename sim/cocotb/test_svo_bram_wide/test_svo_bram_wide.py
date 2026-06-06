"""
Cocotb tests for svo_bram_wide.sv (M2 asymmetric SVO node RAM).

Proves the asymmetric mapping is functionally correct:
  - Port A writes 8x 32-bit words to node K at addr {K, 0..7}.
  - Port B reads node K (addr_b_node=K) and returns all 8 words packed into
    256 bits, with dout_b_wide[w*32 +: 32] == word w.
  - Port A 32-bit read (shadow path) returns the same words it wrote.

Both ports share the 100 MHz system clock (as in top.sv), driven from one
coroutine so there is zero phase difference. Registered reads have 1-cycle
latency: present addr at edge N, data appears at edge N+1.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLK_NS = 10  # 100 MHz


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
    dut.en_a.value = 0
    dut.en_b.value = 0
    dut.addr_a.value = 0
    dut.din_a.value = 0
    dut.addr_b_node.value = 0
    await ClockCycles(dut.clk_a, 4)


async def write_word(dut, addr: int, data: int):
    """Write one 32-bit word to port A (addr = {node, word}). Registered on next edge."""
    await RisingEdge(dut.clk_a)
    await Timer(1, units="ns")
    dut.en_a.value = 1
    dut.addr_a.value = addr
    dut.din_a.value = data
    await RisingEdge(dut.clk_a)
    await Timer(1, units="ns")
    dut.en_a.value = 0


async def read_node_wide(dut, node: int) -> int:
    """Read a whole node (256 bits) from port B. 1-cycle registered latency."""
    await RisingEdge(dut.clk_b)
    await Timer(1, units="ns")
    dut.en_b.value = 1
    dut.addr_b_node.value = node
    await RisingEdge(dut.clk_b)
    await Timer(1, units="ns")
    dut.en_b.value = 0
    await Timer(1, units="ns")
    return int(dut.dout_b_wide.value)


async def read_word_a(dut, addr: int) -> int:
    """Read one 32-bit word from port A (shadow path). 1-cycle registered latency."""
    await RisingEdge(dut.clk_a)
    await Timer(1, units="ns")
    dut.en_a.value = 1
    dut.addr_a.value = addr
    await RisingEdge(dut.clk_a)
    await Timer(1, units="ns")
    dut.en_a.value = 0
    await Timer(1, units="ns")
    return int(dut.dout_a.value)


def node_addr(node: int, word: int) -> int:
    return (node << 3) | word


@cocotb.test()
async def test_wide_read_packs_whole_node(dut):
    """8 narrow writes to node K -> one 256-bit read returns all 8 words in order."""
    await init(dut)
    K = 37
    words = [0x1111_0001, 0xBEEF_0002, 0x2222_0003, 0x3333_0004,
             0x4444_0005, 0xAABB_0006, 0xCCDD_0007, 0xDEAD_0008]
    for w, val in enumerate(words):
        await write_word(dut, node_addr(K, w), val)

    wide = await read_node_wide(dut, K)
    for w, val in enumerate(words):
        got = (wide >> (w * 32)) & 0xFFFF_FFFF
        assert got == val, f"word {w}: got 0x{got:08X} expected 0x{val:08X}"


@cocotb.test()
async def test_two_nodes_independent(dut):
    """Writes to node A must not bleed into node B's wide read."""
    await init(dut)
    A, B = 5, 6
    for w in range(8):
        await write_word(dut, node_addr(A, w), 0xA000_0000 | w)
        await write_word(dut, node_addr(B, w), 0xB000_0000 | w)
    wa = await read_node_wide(dut, A)
    wb = await read_node_wide(dut, B)
    for w in range(8):
        assert ((wa >> (w * 32)) & 0xFFFF_FFFF) == (0xA000_0000 | w)
        assert ((wb >> (w * 32)) & 0xFFFF_FFFF) == (0xB000_0000 | w)


@cocotb.test()
async def test_port_a_narrow_readback(dut):
    """Port A 32-bit read (shadow path) returns the written words verbatim."""
    await init(dut)
    K = 9
    words = [0x0BAD_0000 | w for w in range(8)]
    for w, val in enumerate(words):
        await write_word(dut, node_addr(K, w), val)
    for w, val in enumerate(words):
        got = await read_word_a(dut, node_addr(K, w))
        assert got == val, f"PortA word {w}: got 0x{got:08X} expected 0x{val:08X}"
