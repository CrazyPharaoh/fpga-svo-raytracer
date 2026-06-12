"""Cocotb tests for shared_qmul3.sv (3-lane Q16.16 pipelined multiplier)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random


def qmul_ref(a, b):
    """Q16.16 reference: signed 32×32 product, bits [47:16], wrapped to 32 bits."""
    def s32(x):
        return x - (1 << 32) if x & (1 << 31) else x
    return ((s32(a) * s32(b)) >> 16) & 0xFFFFFFFF


@cocotb.test()
async def test_latency_and_correctness(dut):
    """Stream random operands, discover pipeline latency L, and verify all three lanes
    match qmul_ref at a consistent offset L."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    N = 40
    inputs = [[(random.randint(0, 0xFFFFFFFF), random.randint(0, 0xFFFFFFFF))
               for _ in range(3)] for _ in range(N)]

    def rd(sig):
        # outputs are X until the pipeline fills
        try:
            return int(sig.value)
        except ValueError:
            return None

    captured = []  # (p0, p1, p2) sampled after each edge
    for c in range(N + 6):
        if c < N:
            (a0, b0), (a1, b1), (a2, b2) = inputs[c]
            dut.a0.value, dut.b0.value = a0, b0
            dut.a1.value, dut.b1.value = a1, b1
            dut.a2.value, dut.b2.value = a2, b2
        await RisingEdge(dut.clk)
        captured.append((rd(dut.p0), rd(dut.p1), rd(dut.p2)))

    detected = None
    for L in range(1, 6):
        ok = all(
            captured[c][lane] == qmul_ref(*inputs[c - L][lane])
            for c in range(L, N) for lane in range(3)
        )
        if ok:
            detected = L
            break

    assert detected is not None, "no consistent pipeline latency found in 1..5"
    dut._log.info(f"shared_qmul3 latency L={detected} (collect = issue + {detected}; +1 if operands are registered)")
