import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

IMG_W = 4
IMG_H = 2
NPIX  = IMG_W * IMG_H


async def run_frame(dut, start_cycles):
    """Drive one frame, holding `start` high for `start_cycles` cycles. Emulates
    the core: captures launches, completes slots NEWEST-first (forces reorder),
    acts as the always-ready AXIS sink, and checks raster-ordered emission.
    start_cycles=1 is the cocotb-style 1-cycle start; start_cycles=32 mirrors the
    hardware ctrl_trigger pulse (which must still trigger exactly ONE frame)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst.value = 1; dut.start.value = 0
    dut.done_valid.value = 0; dut.done_slot.value = 0; dut.done_color.value = 0
    dut.axis_tready.value = 1
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1   # asserted; dropped after start_cycles inside the loop

    active  = {}    # slot -> raster index, for slots launched in PRIOR cycles
    emitted = []
    cycles  = 0
    while len(emitted) < NPIX and cycles < 5000:
        # hold start high for start_cycles, then drop it
        dut.start.value = 1 if cycles < start_cycles else 0
        # capture an emission this cycle
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
        # capture THIS cycle's launch; add to active only AFTER the edge
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
    # The hardware ctrl_trigger is a 32-cycle pulse. start must be edge-detected so
    # this triggers exactly one frame; without that, the per-cycle re-init desyncs
    # the in-flight accounting and the frame never completes (the FPGA hang).
    await run_frame(dut, start_cycles=32)
