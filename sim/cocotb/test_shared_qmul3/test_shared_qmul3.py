import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random


def qmul_ref(a, b):
    # signed 32x32 -> bits [47:16], 32-bit two's complement
    def s32(x):
        return x - (1 << 32) if x & (1 << 31) else x
    return ((s32(a) * s32(b)) >> 16) & 0xFFFFFFFF


@cocotb.test()
async def test_latency_and_correctness(dut):
    """Streams random operands, then DISCOVERS the pipeline latency L (the offset
    at which every lane's output matches qmul of its operands). Passes if a single
    consistent L exists across all three lanes, and reports it (that's the offset
    the FSM consumer needs to use when collecting)."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    N = 40
    inputs = [[(random.randint(0, 0xFFFFFFFF), random.randint(0, 0xFFFFFFFF))
               for _ in range(3)] for _ in range(N)]

    def rd(sig):
        # outputs are X for the first cycles until the pipeline fills; treat as None
        try:
            return int(sig.value)
        except ValueError:
            return None

    captured = []  # captured[c] = (p0, p1, p2) read just after edge c
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
    dut._log.info(f"shared_qmul3 measured latency L = {detected} "
                  f"(FSM collect = issue-stage + {detected}; +1 more if operands are registered)")
