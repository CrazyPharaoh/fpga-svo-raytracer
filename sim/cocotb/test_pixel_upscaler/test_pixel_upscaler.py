"""
Cocotb tests for pixel_upscaler.sv

The module is purely combinatorial, so we just drive inputs and check outputs.
Formula: fb_addr = (hy>>1)*320 + (hx>>1)
"""
import cocotb
from cocotb.triggers import Timer


def expected_addr(hx, hy):
    fx = hx >> 1   # 0..319
    fy = hy >> 1   # 0..239
    return fy * 320 + fx


async def check(dut, hx, hy):
    dut.hx.value = hx
    dut.hy.value = hy
    await Timer(1, units="ns")  # combinatorial — settle after 1 ns
    got  = int(dut.fb_addr.value)
    want = expected_addr(hx, hy)
    assert got == want, f"hx={hx} hy={hy}: fb_addr={got}, expected {want}"


@cocotb.test()
async def test_origin(dut):
    """(0,0) → address 0."""
    await check(dut, 0, 0)


@cocotb.test()
async def test_bottom_right(dut):
    """(638,478) → last pixel of framebuffer (fx=319, fy=239 → 76799)."""
    await check(dut, 638, 478)


@cocotb.test()
async def test_2x_upscale_pairs(dut):
    """Each 2×2 block of HDMI pixels must map to the same framebuffer address."""
    for fy in range(0, 240, 40):
        for fx in range(0, 320, 40):
            base_addr = fy * 320 + fx
            for dy in range(2):
                for dx in range(2):
                    await check(dut, fx * 2 + dx, fy * 2 + dy)
                    assert int(dut.fb_addr.value) == base_addr, (
                        f"2×2 block at ({fx},{fy}): "
                        f"hdmi ({fx*2+dx},{fy*2+dy}) → {int(dut.fb_addr.value)}, "
                        f"expected {base_addr}"
                    )


@cocotb.test()
async def test_row_boundary(dut):
    """Last column of row 0 and first column of row 1 map to different rows."""
    await check(dut, 638, 0)   # fb_addr = 319
    addr_last_col = int(dut.fb_addr.value)
    await check(dut, 0, 2)     # fb_addr = 320
    addr_first_next = int(dut.fb_addr.value)
    assert addr_first_next == addr_last_col + 1, (
        f"Row boundary: {addr_last_col} → {addr_first_next}"
    )


@cocotb.test()
async def test_full_hdmi_range(dut):
    """Spot-check 200 evenly spaced HDMI coordinates against the formula."""
    import itertools
    hx_vals = range(0, 640, 7)
    hy_vals = range(0, 480, 7)
    for hx, hy in itertools.islice(itertools.product(hx_vals, hy_vals), 200):
        await check(dut, hx, hy)
