`timescale 1ns/1ps
// pixel_reorder.sv — out-of-order-completion reorder buffer for the multi-ray core (M2).
//
// M1 was in-order retire: a slot could not relaunch until the OLDEST in-flight slot
// emitted (rp, raster order), so a fast ray that finished early sat idle behind a slow
// one — the head-of-line S_IDLE (~24% of the frame).
//
// M2 decouples completion from emission. A slot frees the instant its ray COMPLETES:
// its colour is written into a position-indexed reorder buffer and the slot relaunches
// immediately (into the next raster pixel, up to REORDER_DEPTH pixels ahead of the emit
// pointer). A separate emit pointer walks the buffer in raster order and streams to AXIS.
// Fast rays run ahead of a slow one instead of idling; AXIS still emits strict raster
// order with correct framing (tlast at line end, tuser at frame start).
//
// Window = REORDER_DEPTH pixels (power of 2). A slot may launch at most DEPTH pixels
// ahead of emit_idx; beyond that, launches stall (the buffer is full). DEPTH bounds how
// far fast rays can outrun a slow one — large enough hides typical slow rays.
//
// Interface is UNCHANGED from M1 (drop-in): the core launches on launch_valid and
// reports completion on done_valid; this module owns AXIS + busy/frame_done.
module pixel_reorder #(
    parameter int IMG_W         = 320,
    parameter int IMG_H         = 240,
    parameter int RAY_POOL_N    = 4,
    parameter int SLOT_W        = (RAY_POOL_N > 1) ? $clog2(RAY_POOL_N) : 1,
    parameter int REORDER_DEPTH = 64          // run-ahead window in pixels (power of 2)
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
    localparam int NPIX   = IMG_W * IMG_H;
    localparam int PIDX_W = $clog2(NPIX + 1);
    localparam int BUF_AW = $clog2(REORDER_DEPTH);

    logic [RAY_POOL_N-1:0] slot_free;            // 1 = slot idle and available to launch
    logic [PIDX_W-1:0]     launch_idx, emit_idx; // raster (linear) pixel indices
    logic [8:0]            lpx, epx;             // launch / emit pixel x (raster, tracked)
    logic [7:0]            lpy, epy;             // launch / emit pixel y
    logic                  launched_all;
    logic [BUF_AW-1:0]     slot_bidx [0:RAY_POOL_N-1]; // buffer slot each in-flight ray owns

    // Reorder buffer: colour + valid, indexed by pixel position mod DEPTH (circular).
    (* ram_style = "distributed" *) logic [23:0] buf_color [0:REORDER_DEPTH-1];
    logic [REORDER_DEPTH-1:0]                     buf_valid;

    // Edge-detect start (hardware ctrl_trigger is a multi-cycle pulse; init must fire once).
    logic start_d;
    wire  start_pulse = start && !start_d;

    // ---- launch decision (combinational) ----
    wire any_free = |slot_free;
    // Run-ahead window. If the buffer is at least the whole frame, never limit; otherwise
    // gate at DEPTH pixels ahead (PIDX_W'(DEPTH) is exact here since DEPTH < NPIX).
    wire win_ok = (REORDER_DEPTH >= NPIX) ? 1'b1
                                          : ((launch_idx - emit_idx) < PIDX_W'(REORDER_DEPTH));
    assign launch_valid = busy && !launched_all && any_free && win_ok;
    always_comb begin   // lowest-index free slot (iterate high->low; last write wins)
        launch_slot = '0;
        for (int s = RAY_POOL_N-1; s >= 0; s--) if (slot_free[s]) launch_slot = SLOT_W'(s);
    end
    assign launch_px = lpx;
    assign launch_py = lpy;

    // ---- emit (combinational) ----
    wire [BUF_AW-1:0] eptr = BUF_AW'(emit_idx);   // emit_idx mod DEPTH (safe truncate/extend)
    wire emit_ready = busy && buf_valid[eptr];
    assign axis_tvalid = emit_ready;
    assign axis_tdata  = {8'h00, buf_color[eptr]};
    assign axis_tlast  = (epx == 9'(IMG_W-1));
    assign axis_tuser  = (emit_idx == '0);
    wire emit_fire = emit_ready && axis_tready;
    wire last_emit = emit_fire && (emit_idx == PIDX_W'(NPIX-1));

    initial begin
        busy = 1'b0; frame_done = 1'b0; buf_valid = '0;
        for (int i=0;i<RAY_POOL_N;i++) slot_free[i]=1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0; frame_done <= 1'b0;
            slot_free <= '1; launch_idx <= '0; emit_idx <= '0;
            lpx <= '0; lpy <= '0; epx <= '0; epy <= '0;
            launched_all <= 1'b0; start_d <= 1'b0; buf_valid <= '0;
        end else begin
            frame_done <= 1'b0;
            start_d    <= start;
            if (start_pulse) begin
                busy <= 1'b1;
                slot_free <= '1; launch_idx <= '0; emit_idx <= '0;
                lpx <= '0; lpy <= '0; epx <= '0; epy <= '0;
                launched_all <= 1'b0; buf_valid <= '0;
            end else if (busy) begin
                // completion: free the slot, drop its colour into the buffer at its reserved idx
                if (done_valid) begin
                    slot_free[done_slot]            <= 1'b1;
                    buf_color[slot_bidx[done_slot]] <= done_color;
                    buf_valid[slot_bidx[done_slot]] <= 1'b1;
                end
                // launch: take the chosen free slot, reserve its buffer slot, advance raster pos
                if (launch_valid) begin
                    slot_free[launch_slot] <= 1'b0;
                    slot_bidx[launch_slot] <= BUF_AW'(launch_idx);   // launch_idx mod DEPTH
                    launch_idx <= launch_idx + PIDX_W'(1);
                    if (lpx == 9'(IMG_W-1)) begin
                        lpx <= '0;
                        if (lpy == 8'(IMG_H-1)) launched_all <= 1'b1;
                        else lpy <= lpy + 8'(1);
                    end else lpx <= lpx + 9'(1);
                end
                // emit: drain the buffer in strict raster order
                if (emit_fire) begin
                    buf_valid[eptr] <= 1'b0;
                    emit_idx <= emit_idx + PIDX_W'(1);
                    if (epx == 9'(IMG_W-1)) begin
                        epx <= '0; epy <= epy + 8'(1);
                    end else epx <= epx + 9'(1);
                end
                if (last_emit) begin
                    busy       <= 1'b0;
                    frame_done <= 1'b1;
                end
            end
        end
    end
endmodule
