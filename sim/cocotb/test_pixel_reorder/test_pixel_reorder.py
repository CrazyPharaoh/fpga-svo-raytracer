"""Cocotb tests for pixel_reorder.sv."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

IMG_W = 4
IMG_H = 2
NPIX  = IMG_W * IMG_H


async def run_frame(dut, start_cycles):
    """Drive one frame, holding start high for start_cycles cycles.
    Completes slots newest-first (maximises reorder pressure) and checks raster-ordered emission."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst.value = 1; dut.start.value = 0
    dut.done_valid.value = 0; dut.done_slot.value = 0; dut.done_color.value = 0
    dut.axis_tready.value = 1
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1

    active  = {}    # slot -> raster index (slots launched in prior cycles)
    emitted = []
    cycles  = 0
    while len(emitted) < NPIX and cycles < 5000:
        # hold start high for start_cycles, then drop it
        dut.start.value = 1 if cycles < start_cycles else 0
        if int(dut.axis_tvalid.value) and int(dut.axis_tready.value):
            emitted.append((int(dut.axis_tdata.value) & 0xFFFFFF,
                            int(dut.axis_tlast.value), int(dut.axis_tuser.value)))
        # drive a scrambled completion: complete the NEWEST active slot
        dut.done_valid.value = 0
        if active:
            slot = max(active, key=lambda s: active[s])
            dut.done_valid.value = 1
            dut.done_slot.value  = slot
            dut.done_color.value = active[slot]
            del active[slot]
        # Add this cycle's launch to active only AFTER the edge
        newly = None
        if int(dut.launch_valid.value):
            newly = (int(dut.launch_slot.value),
                     int(dut.launch_py.value) * IMG_W + int(dut.launch_px.value))
        await RisingEdge(dut.clk)
        if newly is not None:
            active[newly[0]] = newly[1]
        cycles += 1
    dut.done_valid.value = 0

    assert len(emitted) == NPIX, f"emitted {len(emitted)} != {NPIX} (timeout/stall — desync?)"
    for i, (payload, tlast, tuser) in enumerate(emitted):
        assert payload == i, f"raster {i} out of order; sequence={[e[0] for e in emitted]}"
        px = i % IMG_W
        assert tlast == (1 if px == IMG_W-1 else 0), f"tlast wrong at raster {i}"
        assert tuser == (1 if i == 0 else 0),        f"tuser wrong at raster {i}"
    assert int(dut.busy.value) == 0


@cocotb.test()
async def test_inorder_retire_outoforder_complete(dut):
    await run_frame(dut, start_cycles=1)


@cocotb.test()
async def test_multicycle_start(dut):
    """start is edge-detected; a 32-cycle pulse (matching ctrl_trigger) triggers exactly one frame."""
    await run_frame(dut, start_cycles=32)
