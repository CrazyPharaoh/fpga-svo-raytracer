`timescale 1ns/1ps
// pixel_reorder.sv — in-order launch + retire for the multi-ray core (M1).
// Launches pixels in raster order into free slots (rotating pointer lp) and
// emits each finished slot's colour on AXIS in the SAME raster order (rotating
// pointer rp). Window = RAY_POOL_N, so the reorder buffer is just the slots.
// Out-of-order completion (done_valid for any slot) is buffered; emission waits
// for the oldest in-flight slot (rp). AXIS framing: tlast on px==IMG_W-1,
// tuser on the very first pixel (0,0).
module pixel_reorder #(
    parameter int IMG_W      = 320,
    parameter int IMG_H      = 240,
    parameter int RAY_POOL_N = 4,
    parameter int SLOT_W     = (RAY_POOL_N > 1) ? $clog2(RAY_POOL_N) : 1
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    // launch (to core): 1-cycle pulse to start a ray on launch_slot for (px,py)
    output logic              launch_valid,
    output logic [SLOT_W-1:0] launch_slot,
    output logic [8:0]        launch_px,
    output logic [7:0]        launch_py,

    // completion (from core): a ray finished with a colour
    input  logic              done_valid,
    input  logic [SLOT_W-1:0] done_slot,
    input  logic [23:0]       done_color,

    // AXIS pixel out
    output logic        axis_tvalid,
    output logic [31:0] axis_tdata,
    output logic        axis_tlast,
    output logic [0:0]  axis_tuser,
    input  logic        axis_tready,

    output logic busy,
    output logic frame_done
);
    localparam int CNT_W = $clog2(RAY_POOL_N + 1);

    logic [SLOT_W-1:0] lp, rp;       // rotating launch / retire slot pointers
    logic [CNT_W-1:0]  inflight;     // number of slots currently in flight (0..N)
    logic [8:0]        lpx;          // next pixel to launch (raster)
    logic [7:0]        lpy;
    logic              launched_all; // all IMG_W*IMG_H pixels have been launched

    // Edge-detect start: the hardware ctrl_trigger is a multi-cycle (32) pulse, but
    // the init below must fire ONCE — otherwise it re-zeros lp/rp/inflight every
    // cycle start is high while the core's launch-init is already launching slots,
    // desyncing the in-flight accounting and deadlocking. (Sim used a 1-cycle start
    // so never hit this.)
    logic              start_d;
    wire               start_pulse = start && !start_d;

    logic        sdone  [0:RAY_POOL_N-1];
    logic [23:0] scolor [0:RAY_POOL_N-1];
    logic [8:0]  spx    [0:RAY_POOL_N-1];
    logic [7:0]  spy    [0:RAY_POOL_N-1];

    // ---- launch decision (combinational) ----
    wire can_launch = busy && !launched_all && (inflight < CNT_W'(RAY_POOL_N));
    assign launch_valid = can_launch;
    assign launch_slot  = lp;
    assign launch_px    = lpx;
    assign launch_py    = lpy;

    // ---- retire / emit (combinational) ----
    wire emit_ready = busy && (inflight != 0) && sdone[rp];
    assign axis_tvalid = emit_ready;
    assign axis_tdata  = {8'h00, scolor[rp]};
    assign axis_tlast  = (spx[rp] == 9'(IMG_W-1));
    assign axis_tuser  = (spx[rp] == 9'd0) && (spy[rp] == 8'd0);
    wire retire_fire = emit_ready && axis_tready;
    wire last_pixel_retire = retire_fire && (spx[rp]==9'(IMG_W-1)) && (spy[rp]==8'(IMG_H-1));

    initial begin
        for (int i=0;i<RAY_POOL_N;i++) sdone[i]=1'b0;
        busy=1'b0; frame_done=1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            busy        <= 1'b0;
            frame_done  <= 1'b0;
            lp          <= '0;
            rp          <= '0;
            inflight    <= '0;
            lpx         <= '0;
            lpy         <= '0;
            launched_all <= 1'b0;
            start_d     <= 1'b0;
            for (int i=0;i<RAY_POOL_N;i++) sdone[i] <= 1'b0;
        end else begin
            frame_done <= 1'b0;
            start_d    <= start;
            if (start_pulse) begin
                busy        <= 1'b1;
                lp          <= '0;
                rp          <= '0;
                inflight    <= '0;
                lpx         <= '0;
                lpy         <= '0;
                launched_all <= 1'b0;
                for (int i=0;i<RAY_POOL_N;i++) sdone[i] <= 1'b0;
            end else if (busy) begin
                // record completion (done_slot is always an in-flight slot)
                if (done_valid) begin
                    sdone[done_slot]  <= 1'b1;
                    scolor[done_slot] <= done_color;
                end
                // launch into the next free slot
                if (can_launch) begin
                    spx[lp]   <= lpx;
                    spy[lp]   <= lpy;
                    sdone[lp] <= 1'b0;
                    lp <= (lp == SLOT_W'(RAY_POOL_N-1)) ? '0 : lp + SLOT_W'(1);
                    if (lpx == 9'(IMG_W-1)) begin
                        lpx <= '0;
                        if (lpy == 8'(IMG_H-1)) launched_all <= 1'b1;
                        else lpy <= lpy + 8'(1);
                    end else lpx <= lpx + 9'(1);
                end
                // retire the oldest slot when done
                if (retire_fire) begin
                    sdone[rp] <= 1'b0;
                    rp <= (rp == SLOT_W'(RAY_POOL_N-1)) ? '0 : rp + SLOT_W'(1);
                end
                // inflight bookkeeping
                inflight <= inflight
                    + (can_launch  ? CNT_W'(1) : CNT_W'(0))
                    - (retire_fire ? CNT_W'(1) : CNT_W'(0));
                if (last_pixel_retire) begin
                    busy       <= 1'b0;
                    frame_done <= 1'b1;
                end
            end
        end
    end
endmodule
