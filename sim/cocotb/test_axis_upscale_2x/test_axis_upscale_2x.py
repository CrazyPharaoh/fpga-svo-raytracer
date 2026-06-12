"""Cocotb tests for axis_upscale_2x.sv."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

IN_W, IN_H = 4, 3
OUT_W, OUT_H = 2 * IN_W, 2 * IN_H


async def reset(dut):
    dut.aresetn.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tuser.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tkeep.value = 0xF
    dut.m_axis_tready.value = 0
    for _ in range(5):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


@cocotb.test()
async def test_2x2_replication(dut):
    cocotb.start_soon(Clock(dut.aclk, 10, units="ns").start())
    await reset(dut)

    src = [[((r << 16) | c) for c in range(IN_W)] for r in range(IN_H)]  # pixel value encodes (row, col)
    in_pixels = []
    for r in range(IN_H):
        for c in range(IN_W):
            in_pixels.append((src[r][c],
                              1 if (r == 0 and c == 0) else 0,   # tuser = SOF
                              1 if c == IN_W - 1 else 0))         # tlast = EOL

    out = []

    async def producer():
        i = 0
        while i < len(in_pixels):
            data, tuser, tlast = in_pixels[i]
            dut.s_axis_tdata.value = data
            dut.s_axis_tuser.value = tuser
            dut.s_axis_tlast.value = tlast
            dut.s_axis_tvalid.value = 1
            await RisingEdge(dut.aclk)
            if dut.s_axis_tready.value == 1:
                i += 1
        dut.s_axis_tvalid.value = 0

    async def consumer():
        while len(out) < OUT_W * OUT_H:
            dut.m_axis_tready.value = random.randint(0, 1)
            await RisingEdge(dut.aclk)
            if dut.m_axis_tvalid.value == 1 and dut.m_axis_tready.value == 1:
                out.append((int(dut.m_axis_tdata.value),
                            int(dut.m_axis_tuser.value),
                            int(dut.m_axis_tlast.value)))
        dut.m_axis_tready.value = 1

    cocotb.start_soon(producer())
    await consumer()

    assert len(out) == OUT_W * OUT_H, f"got {len(out)} output pixels, want {OUT_W*OUT_H}"
    for idx, (data, tuser, tlast) in enumerate(out):
        orow, ocol = idx // OUT_W, idx % OUT_W
        exp = src[orow >> 1][ocol >> 1]
        assert data == exp, f"px({orow},{ocol}) = {data:#x}, expected {exp:#x}"
        assert tuser == (1 if idx == 0 else 0), f"tuser wrong at out beat {idx} (got {tuser})"
        assert tlast == (1 if ocol == OUT_W - 1 else 0), \
            f"tlast wrong at ({orow},{ocol}) (got {tlast})"


@cocotb.test()
async def test_locks_to_sof(dut):
    """Upscaler must suppress output until the first SOF (tuser) and align framing to it."""
    cocotb.start_soon(Clock(dut.aclk, 10, units="ns").start())
    await reset(dut)

    src = [[((r << 16) | c) for c in range(IN_W)] for r in range(IN_H)]
    frame = []
    for r in range(IN_H):
        for c in range(IN_W):
            frame.append((src[r][c],
                          1 if (r == 0 and c == 0) else 0,
                          1 if c == IN_W - 1 else 0))

    out = []

    async def producer():
        # 6 garbage pixels before SOF — must be ignored while unsynced
        for _ in range(6):
            dut.s_axis_tdata.value = 0xDEAD0000
            dut.s_axis_tuser.value = 0
            dut.s_axis_tlast.value = 0
            dut.s_axis_tvalid.value = 1
            await RisingEdge(dut.aclk)
        i = 0
        while i < len(frame):
            data, tuser, tlast = frame[i]
            dut.s_axis_tdata.value = data
            dut.s_axis_tuser.value = tuser
            dut.s_axis_tlast.value = tlast
            dut.s_axis_tvalid.value = 1
            await RisingEdge(dut.aclk)
            if dut.s_axis_tready.value == 1:
                i += 1
        dut.s_axis_tvalid.value = 0

    async def consumer():
        dut.m_axis_tready.value = 1
        while len(out) < OUT_W * OUT_H:
            await RisingEdge(dut.aclk)
            if dut.m_axis_tvalid.value == 1 and dut.m_axis_tready.value == 1:
                out.append((int(dut.m_axis_tdata.value),
                            int(dut.m_axis_tuser.value),
                            int(dut.m_axis_tlast.value)))

    cocotb.start_soon(producer())
    await consumer()

    assert len(out) == OUT_W * OUT_H, f"got {len(out)} output pixels, want {OUT_W*OUT_H}"
    for idx, (data, tuser, tlast) in enumerate(out):
        orow, ocol = idx // OUT_W, idx % OUT_W
        exp = src[orow >> 1][ocol >> 1]
        assert data == exp, f"px({orow},{ocol})={data:#x} exp {exp:#x} (pre-roll leaked / not locked to SOF)"
        assert tuser == (1 if idx == 0 else 0), f"tuser wrong at beat {idx}"
        assert tlast == (1 if ocol == OUT_W - 1 else 0), f"tlast wrong at ({orow},{ocol})"
