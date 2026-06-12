"""Cocotb tests for qmul_bank_tagged.sv."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

Q = 1 << 16


@cocotb.test()
async def test_tag_follows_product(dut):
    """Two back-to-back issues with different tags; products must return tagged and in order.
    QCOL = LAT+1 = 4 (1 input-reg + 3-cycle shared_qmul3)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.iss_valid.value = 0
    await RisingEdge(dut.clk)

    dut.iss_valid.value = 1
    dut.iss_tag.value = 0b101
    dut.a0.value = 3 * Q
    dut.b0.value = 4 * Q
    dut.a1.value = 5 * Q
    dut.b1.value = 6 * Q
    dut.a2.value = 7 * Q
    dut.b2.value = 8 * Q
    await RisingEdge(dut.clk)

    # Cycle B: tag 0b010
    dut.iss_tag.value = 0b010
    dut.a0.value = 2 * Q
    dut.b0.value = 2 * Q
    dut.a1.value = 0
    dut.b1.value = 0
    dut.a2.value = 0
    dut.b2.value = 0
    await RisingEdge(dut.clk)
    dut.iss_valid.value = 0

    seen = []
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.res_valid.value):
            seen.append((
                int(dut.res_tag.value),
                int(dut.p0.value),
                int(dut.p1.value),
                int(dut.p2.value),
            ))

    assert len(seen) >= 2, f"expected >=2 tagged results, got {seen}"
    assert seen[0][0] == 0b101, \
        f"first tag: expected 0b101=5, got {seen[0][0]}"
    assert seen[0][1] == 12 * Q, \
        f"first p0: expected {12*Q}, got {seen[0][1]}"
    assert seen[0][2] == 30 * Q, \
        f"first p1: expected {30*Q}, got {seen[0][2]}"
    assert seen[0][3] == 56 * Q, \
        f"first p2: expected {56*Q}, got {seen[0][3]}"
    assert seen[1][0] == 0b010, \
        f"second tag: expected 0b010=2, got {seen[1][0]}"
    assert seen[1][1] == 4 * Q, \
        f"second p0: expected {4*Q}, got {seen[1][1]}"

    dut._log.info(
        f"PASS: two tagged results returned in order: {seen[0]}, {seen[1]}"
    )
