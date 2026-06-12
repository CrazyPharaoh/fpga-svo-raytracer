"""Cocotb tests for ray_scheduler.sv (N=4 round-robin arbiter)."""
import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_grants_only_ready(dut):
    """No ready slots → grant_valid must be low."""
    dut.ready.value = 0b0000
    dut.last_grant.value = 0
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 0


@cocotb.test()
async def test_round_robin_skips_blocked(dut):
    """Skips non-ready slots; wraps around after the highest granted slot."""
    dut.ready.value = 0b0101
    dut.last_grant.value = 0
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 1
    assert dut.grant.value == 2
    dut.last_grant.value = 2
    await Timer(1, unit="ns")
    assert dut.grant.value == 0


@cocotb.test()
async def test_single_ready(dut):
    """Single ready slot is always granted regardless of last_grant."""
    dut.ready.value = 0b0010
    dut.last_grant.value = 3
    await Timer(1, unit="ns")
    assert dut.grant_valid.value == 1
    assert dut.grant.value == 1
