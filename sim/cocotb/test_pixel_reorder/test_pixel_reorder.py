import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

IMG_W = 4
IMG_H = 2
NPIX  = IMG_W * IMG_H

@cocotb.test()
async def test_inorder_retire_outoforder_complete(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst.value = 1; dut.start.value = 0
    dut.done_valid.value = 0; dut.done_slot.value = 0; dut.done_color.value = 0
    dut.axis_tready.value = 1
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    active  = {}    # slot -> raster index, for slots launched in PRIOR cycles
    emitted = []
    cycles  = 0
    while len(emitted) < NPIX and cycles < 5000:
        # capture an emission this cycle
        if int(dut.axis_tvalid.value) and int(dut.axis_tready.value):
            emitted.append((int(dut.axis_tdata.value) & 0xFFFFFF,
                            int(dut.axis_tlast.value), int(dut.axis_tuser.value)))
        # drive a scrambled completion: complete the NEWEST active slot (forces reorder)
        dut.done_valid.value = 0
        if active:
            slot = max(active, key=lambda s: active[s])
            dut.done_valid.value = 1
            dut.done_slot.value  = slot
            dut.done_color.value = active[slot]
            del active[slot]
        # capture THIS cycle's launch; add to active only AFTER the edge so it
        # cannot be completed in the same cycle it is launched
        newly = None
        if int(dut.launch_valid.value):
            newly = (int(dut.launch_slot.value),
                     int(dut.launch_py.value) * IMG_W + int(dut.launch_px.value))
        await RisingEdge(dut.clk)
        if newly is not None:
            active[newly[0]] = newly[1]
        cycles += 1
    dut.done_valid.value = 0

    assert len(emitted) == NPIX, f"emitted {len(emitted)} != {NPIX} (timeout/stall?)"
    for i, (payload, tlast, tuser) in enumerate(emitted):
        assert payload == i, f"raster {i} out of order; sequence={[e[0] for e in emitted]}"
        px = i % IMG_W
        assert tlast == (1 if px == IMG_W-1 else 0), f"tlast wrong at raster {i}"
        assert tuser == (1 if i == 0 else 0),        f"tuser wrong at raster {i}"
    # frame_done should have pulsed; busy should now be low
    assert int(dut.busy.value) == 0
