"""
Cocotb tests for stack_store.sv

stack_store is a synchronous-read RAM addressed by {slot, sp}.
One packed entry (ENTRY_W=240 bits) per address.
Read latency = 1 clock cycle: present r_slot/r_sp at edge N,
r_data is valid at edge N+1.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_NS = 10   # 100 MHz


async def init(dut):
    """Start clock and de-assert write-enable."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    dut.we.value     = 0
    dut.w_slot.value = 0
    dut.w_sp.value   = 0
    dut.w_data.value = 0
    dut.r_slot.value = 0
    dut.r_sp.value   = 0
    # Let the clock run for a few cycles before driving
    for _ in range(4):
        await RisingEdge(dut.clk)


async def wr(dut, slot, sp, data):
    """Write one entry.  Data is registered on the rising edge that sees we=1."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")   # drive a little after the edge (avoid hold issues)
    dut.we.value     = 1
    dut.w_slot.value = slot
    dut.w_sp.value   = sp
    dut.w_data.value = data
    await RisingEdge(dut.clk)   # write registers here
    await Timer(1, unit="ns")
    dut.we.value = 0


async def rd(dut, slot, sp) -> int:
    """Issue a read and return r_data the cycle after the address is registered."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.r_slot.value = slot
    dut.r_sp.value   = sp
    await RisingEdge(dut.clk)   # address registered here; data valid after this edge
    await Timer(1, unit="ns")
    return int(dut.r_data.value)


@cocotb.test()
async def test_write_then_read_per_slot(dut):
    """Spec example: same sp, different slot — values must not alias."""
    await init(dut)
    await wr(dut, 1, 3, 0xAAAA)
    await wr(dut, 2, 3, 0x5555)
    got1 = await rd(dut, 1, 3)
    assert got1 & 0xFFFF == 0xAAAA, f"slot=1,sp=3: expected 0xAAAA, got 0x{got1:X}"
    got2 = await rd(dut, 2, 3)
    assert got2 & 0xFFFF == 0x5555, f"slot=2,sp=3: expected 0x5555, got 0x{got2:X}"


@cocotb.test()
async def test_same_slot_different_sp(dut):
    """Different sp values within the same slot must be independent."""
    await init(dut)
    await wr(dut, 0, 0,  0x11)
    await wr(dut, 0, 1,  0x22)
    await wr(dut, 0, 11, 0xCC)   # STACK_DEPTH-1 = 11
    assert await rd(dut, 0, 0)  & 0xFF == 0x11,  "slot=0,sp=0 corrupted"
    assert await rd(dut, 0, 1)  & 0xFF == 0x22,  "slot=0,sp=1 corrupted"
    assert await rd(dut, 0, 11) & 0xFF == 0xCC,  "slot=0,sp=11 corrupted"


@cocotb.test()
async def test_full_240_bit_entry(dut):
    """Write a full 240-bit pattern and read it back exactly."""
    await init(dut)
    # Build a pattern that exercises every bit in the 240-bit word
    pattern = (1 << 240) - 1  # all-ones
    await wr(dut, 3, 7, pattern)
    got = await rd(dut, 3, 7)
    assert got == pattern, f"240-bit all-ones: expected {pattern:X}, got {got:X}"

    # alternating 0xAA…AA / 0x55…55
    aa_pat = int("AA" * 30, 16)   # 30 bytes = 240 bits
    await wr(dut, 3, 7, aa_pat)
    got = await rd(dut, 3, 7)
    assert got == aa_pat, f"AA pattern: expected {aa_pat:X}, got {got:X}"


@cocotb.test()
async def test_overwrite(dut):
    """Writing to the same {slot,sp} twice: second value must win."""
    await init(dut)
    await wr(dut, 0, 5, 0xDEAD)
    await wr(dut, 0, 5, 0xBEEF)
    got = await rd(dut, 0, 5)
    assert got & 0xFFFF == 0xBEEF, f"overwrite: expected 0xBEEF, got 0x{got:X}"


@cocotb.test()
async def test_all_slots_all_sp(dut):
    """Fill every {slot, sp} address with a unique value and verify all."""
    RAY_POOL_N  = 4
    STACK_DEPTH = 12
    await init(dut)
    # Write phase
    for slot in range(RAY_POOL_N):
        for sp in range(STACK_DEPTH):
            val = (slot << 8) | sp   # unique 12-bit value per address
            await wr(dut, slot, sp, val)
    # Read phase
    for slot in range(RAY_POOL_N):
        for sp in range(STACK_DEPTH):
            expected = (slot << 8) | sp
            got = await rd(dut, slot, sp)
            assert got & 0xFFF == expected, (
                f"slot={slot},sp={sp}: expected 0x{expected:03X}, got 0x{got:X}"
            )
