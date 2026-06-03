import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_grants_only_ready(dut):
    # N=4. ready=0b0000 -> grant_valid low.
    dut.ready.value = 0b0000
    dut.last_grant.value = 0
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 0


@cocotb.test()
async def test_round_robin_skips_blocked(dut):
    # ready = slots 0 and 2 only. Starting after slot 0, next ready is 2.
    dut.ready.value = 0b0101
    dut.last_grant.value = 0
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 1
    assert dut.grant.value == 2
    # after slot 2, wrap to slot 0
    dut.last_grant.value = 2
    await Timer(1, unit="ns")
    assert dut.grant.value == 0


@cocotb.test()
async def test_single_ready(dut):
    dut.ready.value = 0b0010
    dut.last_grant.value = 3
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 1
    assert dut.grant.value == 1
