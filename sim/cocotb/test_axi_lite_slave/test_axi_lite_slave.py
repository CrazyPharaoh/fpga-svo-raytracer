"""
Cocotb tests for axi_lite_slave.sv

Covers:
- AXI4-Lite write handshake (AWVALID/AWREADY, WVALID/WREADY, BVALID/BREADY)
- AXI4-Lite read handshake (ARVALID/ARREADY, RVALID/RREADY)
- Every register in the map: write then verify output port changes
- ctrl_trigger auto-clears after one cycle  (caught by background monitor)
- SVO_DATA auto-increments svo_wr_addr and pulses svo_wr_en (monitor)
- STATUS register returns {frame_done, busy}
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLK_NS = 10


def to_q16(f):
    return int(f * 65536) & 0xFFFF_FFFF


async def axi_write(dut, addr: int, data: int):
    """Perform one AXI4-Lite write transaction."""
    await RisingEdge(dut.S_AXI_ACLK)
    dut.S_AXI_AWADDR.value  = addr
    dut.S_AXI_AWVALID.value = 1
    dut.S_AXI_WDATA.value   = data
    dut.S_AXI_WSTRB.value   = 0xF
    dut.S_AXI_WVALID.value  = 1
    dut.S_AXI_BREADY.value  = 1
    while not dut.S_AXI_AWREADY.value:
        await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)
    dut.S_AXI_AWVALID.value = 0
    dut.S_AXI_WVALID.value  = 0
    while not dut.S_AXI_BVALID.value:
        await RisingEdge(dut.S_AXI_ACLK)
    dut.S_AXI_BREADY.value = 0
    await RisingEdge(dut.S_AXI_ACLK)


async def axi_read(dut, addr: int) -> int:
    """Perform one AXI4-Lite read transaction. Returns read data."""
    await RisingEdge(dut.S_AXI_ACLK)
    dut.S_AXI_ARADDR.value  = addr
    dut.S_AXI_ARVALID.value = 1
    dut.S_AXI_RREADY.value  = 1
    while not dut.S_AXI_ARREADY.value:
        await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)
    dut.S_AXI_ARVALID.value = 0
    while not dut.S_AXI_RVALID.value:
        await RisingEdge(dut.S_AXI_ACLK)
    data = int(dut.S_AXI_RDATA.value)
    dut.S_AXI_RREADY.value = 0
    return data


async def reset(dut):
    cocotb.start_soon(Clock(dut.S_AXI_ACLK, CLK_NS, units="ns").start())
    dut.S_AXI_ARESETN.value      = 0
    dut.S_AXI_AWVALID.value      = 0
    dut.S_AXI_WVALID.value       = 0
    dut.S_AXI_BREADY.value       = 0
    dut.S_AXI_ARVALID.value      = 0
    dut.S_AXI_RREADY.value       = 0
    dut.status_busy.value        = 0
    dut.status_frame_done.value  = 0
    await ClockCycles(dut.S_AXI_ACLK, 4)
    dut.S_AXI_ARESETN.value = 1
    await ClockCycles(dut.S_AXI_ACLK, 2)


@cocotb.test()
async def test_write_response_okay(dut):
    """Every write must receive BRESP=OKAY (2'b00)."""
    await reset(dut)
    await axi_write(dut, 0x08, to_q16(1.0))
    assert int(dut.S_AXI_BRESP.value) == 0, "BRESP was not OKAY"


@cocotb.test()
async def test_cam_pos_registers(dut):
    """Writing CAM_POS_X/Y/Z updates the output ports."""
    await reset(dut)
    await axi_write(dut, 0x08, to_q16(1.5))
    await axi_write(dut, 0x0C, to_q16(2.5))
    await axi_write(dut, 0x10, to_q16(3.5))
    assert int(dut.cam_pos_x.value) == to_q16(1.5), "cam_pos_x mismatch"
    assert int(dut.cam_pos_y.value) == to_q16(2.5), "cam_pos_y mismatch"
    assert int(dut.cam_pos_z.value) == to_q16(3.5), "cam_pos_z mismatch"


@cocotb.test()
async def test_cam_basis_registers(dut):
    """Writing all camera basis vectors updates output ports."""
    await reset(dut)
    vecs = {
        0x14: to_q16(0.1), 0x18: to_q16(0.2), 0x1C: to_q16(0.3),  # right
        0x20: to_q16(0.4), 0x24: to_q16(0.5), 0x28: to_q16(0.6),  # up
        0x2C: to_q16(0.7), 0x30: to_q16(0.8), 0x34: to_q16(0.9),  # fwd
        0x38: to_q16(0.577),                                         # scale
    }
    for addr, val in vecs.items():
        await axi_write(dut, addr, val)
    assert int(dut.cam_right_x.value) == to_q16(0.1)
    assert int(dut.cam_fwd_z.value)   == to_q16(0.9)
    assert int(dut.cam_scale.value)   == to_q16(0.577)


@cocotb.test()
async def test_light_dir_registers(dut):
    """Writing LIGHT_DIR_{X,Y,Z} updates output ports."""
    await reset(dut)
    await axi_write(dut, 0x3C, to_q16( 0.5))
    await axi_write(dut, 0x40, to_q16(-0.7))
    await axi_write(dut, 0x44, to_q16( 0.5))
    assert int(dut.light_dir_x.value) == to_q16( 0.5)
    assert int(dut.light_dir_y.value) == to_q16(-0.7) & 0xFFFF_FFFF
    assert int(dut.light_dir_z.value) == to_q16( 0.5)


@cocotb.test()
async def test_ctrl_trigger_pulses_then_clears(dut):
    """Writing 0x00 bit0 arms a multi-cycle ctrl_trigger pulse that then auto-clears.

    The design uses a 32-cycle pulse (trig_cnt <= 6'd32 in axi_lite_slave.sv) so the
    trigger survives the traversal FSM's multicycle path; sample a wide window and
    assert it goes high for a stretch and returns low on its own.
    """
    await reset(dut)
    await axi_write(dut, 0x00, 1)

    samples = []
    for _ in range(80):
        await RisingEdge(dut.S_AXI_ACLK)
        samples.append(int(dut.ctrl_trigger.value))

    assert 1 in samples, "ctrl_trigger never pulsed high after write to 0x00"
    assert samples[-1] == 0, "ctrl_trigger never auto-cleared (stuck high)"


@cocotb.test()
async def test_svo_data_auto_increments_addr(dut):
    """Each SVO_DATA write must pulse svo_wr_en and increment svo_wr_addr.
    Again we monitor during the write because both signals are single-cycle.
    """
    await reset(dut)
    await axi_write(dut, 0x48, 0)   # SVO_ADDR = 0
    assert int(dut.svo_wr_addr.value) == 0

    for i in range(4):
        wr_en_seen  = []
        addr_after  = []

        async def monitor():
            while True:
                await RisingEdge(dut.S_AXI_ACLK)
                if int(dut.svo_wr_en.value) == 1:
                    wr_en_seen.append(int(dut.svo_wr_data.value))
                    addr_after.append(int(dut.svo_wr_addr.value))

        mon = cocotb.start_soon(monitor())
        await axi_write(dut, 0x4C, 0xA000_0000 + i)
        mon.cancel()

        assert wr_en_seen, f"svo_wr_en did not pulse on write {i}"
        assert wr_en_seen[0] == (0xA000_0000 + i), (
            f"write {i}: data 0x{wr_en_seen[0]:08X} expected 0x{0xA000_0000+i:08X}"
        )
        # After the write, addr should have been incremented
        assert int(dut.svo_wr_addr.value) == i + 1, (
            f"svo_wr_addr={int(dut.svo_wr_addr.value)}, expected {i+1}"
        )
        # svo_wr_en must be cleared one cycle after the transaction
        await RisingEdge(dut.S_AXI_ACLK)
        assert int(dut.svo_wr_en.value) == 0, "svo_wr_en did not de-assert"


@cocotb.test()
async def test_lut_autoinc(dut):
    """LUT upload via the auto-incrementing register pair: 0x50=index, 0x54=data(++).

    Covers all 16 entries, a mid-stream index reset, and the material-flag byte
    [31:24] surviving (the LUT word is now [31:24]=flag, [23:0]=RGB)."""
    await reset(dut)
    # full 0..15 stream from index 0
    words = [(0x01_00_00_00 | (i << 16) | (i << 8) | i) for i in range(16)]
    await axi_write(dut, 0x50, 0)                 # lut_index = 0
    for w in words:
        await axi_write(dut, 0x54, w)             # write + auto-increment
    for i, expected in enumerate(words):
        got = int(dut.lut[i].value)
        assert got == expected, f"lut[{i}]=0x{got:08X}, expected 0x{expected:08X}"
    # mid-stream index reset: point at 3, write two -> lut[3], lut[4]
    await axi_write(dut, 0x50, 3)
    await axi_write(dut, 0x54, 0x02_AA_BB_CC)     # lut[3], index -> 4
    await axi_write(dut, 0x54, 0x03_DD_EE_FF)     # lut[4], index -> 5
    await Timer(20, units="ns")
    assert int(dut.lut[3].value) == 0x02_AA_BB_CC
    assert int(dut.lut[4].value) == 0x03_DD_EE_FF


@cocotb.test()
async def test_time_phase_register(dut):
    """0x84 (word 6'h21) latches the per-frame animation counter."""
    await reset(dut)
    await axi_write(dut, 0x84, 0xDEAD_BEEF)
    await Timer(20, units="ns")
    assert int(dut.time_phase.value) == 0xDEAD_BEEF


@cocotb.test()
async def test_sky_fog_colour_registers(dut):
    """Writing SKY_COLOR and FOG_COLOR updates those output ports."""
    await reset(dut)
    await axi_write(dut, 0x68, 0x00_EB_CE_87)
    await axi_write(dut, 0x6C, 0x00_DC_C8_B4)
    assert int(dut.sky_color.value) == 0x00_EB_CE_87
    assert int(dut.fog_color.value) == 0x00_DC_C8_B4


@cocotb.test()
async def test_status_register_read(dut):
    """STATUS register must reflect {frame_done, busy} input ports."""
    await reset(dut)
    dut.status_busy.value       = 1
    dut.status_frame_done.value = 0
    await ClockCycles(dut.S_AXI_ACLK, 1)
    data = await axi_read(dut, 0x04)
    assert (data & 0x3) == 0b01, f"STATUS=0x{data:08X}, expected busy=1 fd=0"

    dut.status_busy.value       = 0
    dut.status_frame_done.value = 1
    await ClockCycles(dut.S_AXI_ACLK, 1)
    data = await axi_read(dut, 0x04)
    assert (data & 0x3) == 0b10, f"STATUS=0x{data:08X}, expected busy=0 fd=1"


@cocotb.test()
async def test_dbg_mr_register_0x80(dut):
    """0x80 returns the dbg_mr debug word verbatim (multi-ray slot/scheduler state)."""
    await reset(dut)
    dut.dbg_mr.value = 0xDEAD_BEEF
    await ClockCycles(dut.S_AXI_ACLK, 2)
    data = await axi_read(dut, 0x80)
    assert data == 0xDEAD_BEEF, f"0x80 read = 0x{data:08X}, expected 0xDEADBEEF"
    dut.dbg_mr.value = 0x0BAD_F00D
    await ClockCycles(dut.S_AXI_ACLK, 2)
    data = await axi_read(dut, 0x80)
    assert data == 0x0BAD_F00D, f"0x80 read = 0x{data:08X}, expected 0x0BADF00D"
