// svo_traversal.sv
// SVO DDA traversal FSM. Processes one ray at a time.
// All arithmetic in Q16.16 signed fixed-point.
//
// Parameters:
//   SHADOW_MODE = 0  Primary-ray mode: renders full 320×240 frame.
//                    When SHADE_MODE=0 (Phase 1) hits write white pixels.
//                    When SHADE_MODE=1 (Phase 2) hits hand off to shading pipeline.
//   SHADOW_MODE = 1  Shadow-ray mode: terminates at first hit, pulses frame_done.
//                    Ignores camera registers; uses cam_pos/fwd as ray origin/dir.
//   SHADE_MODE  = 0  Phase 1: hit → white, miss → sky_color (no shading pipeline).
//   SHADE_MODE  = 1  Phase 2: hit → trigger shading pipeline, await shade_done.
`timescale 1ns/1ps
module svo_traversal #(
    parameter int IMG_W       = 320,
    parameter int IMG_H       = 240,
    parameter int STACK_DEPTH = 12,
    parameter int WORLD_SIZE  = 64,
    parameter bit SHADOW_MODE = 0,   // 1 = shadow-ray instance
    parameter bit SHADE_MODE  = 0    // 1 = hand off to shading_pipeline
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // Camera / ray-origin registers (Q16.16)
    // In SHADOW_MODE: cam_pos = ray origin, cam_fwd = ray direction (normalised)
    input  logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    input  logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    input  logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    input  logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    input  logic signed [31:0] cam_scale,   // ignored in SHADOW_MODE

    // Sky colour (Phase 1 miss path)
    input  logic [23:0] sky_color,

    // SVO BRAM read port
    output logic [14:0] svo_rd_addr,
    input  logic [31:0] svo_rd_data,
    output logic        svo_rd_en,

    // Framebuffer write port (legacy — undriven when AXI-Stream path is active)
    output logic [16:0] fb_wr_addr,
    output logic [23:0] fb_wr_data,
    output logic        fb_wr_en,

    // AXI-Stream pixel output (primary-ray mode only, SHADOW_MODE=0)
    output logic        axis_tvalid,
    output logic [31:0] axis_tdata,   // [31:24]=0x00, [23:16]=R, [15:8]=G, [7:0]=B
    output logic        axis_tlast,   // high on last pixel of each line (px == IMG_W-1)
    output logic [0:0]  axis_tuser,   // high on first pixel of frame (px==0, py==0)
    input  logic        axis_tready,

    // Shading pipeline handoff (SHADE_MODE=1 only)
    output logic        shade_start,
    output logic        shade_is_miss,
    output logic [1:0]  shade_hit_face,
    output logic        shade_hit_face_sign,
    output logic [7:0]  shade_block_id,
    output logic signed [31:0] shade_t_hit,
    output logic signed [31:0] shade_ray_dx,  shade_ray_dy,  shade_ray_dz,
    output logic signed [31:0] shade_hit_px,  shade_hit_py,  shade_hit_pz,
    input  logic        shade_done,
    input  logic [23:0] shade_pixel_color,

    // Status
    output logic        busy,
    output logic        frame_done,   // also used as "any_hit" pulse in SHADOW_MODE
    output logic        any_hit,      // SHADOW_MODE: 1 when first solid hit found

    // Debug: readable via AXI at run-time to diagnose hangs
    output logic [3:0]  dbg_state,    // current FSM state integer (S_WRITE_PIXEL=12)
    output logic [4:0]  dbg_rs_wait,  // pipeline stage counter (0-13 primary, 0-4 shadow)
    output logic [8:0]  dbg_px,       // current pixel X
    output logic [7:0]  dbg_py,       // current pixel Y
    output logic        dbg_tvalid,   // axis_tvalid: IP is outputting a pixel
    output logic        dbg_tready    // axis_tready: VDMA is accepting the pixel
);

    // -------------------------------------------------------------------------
    // Q16.16 helpers
    // -------------------------------------------------------------------------
    function automatic logic signed [31:0] qmul(
        input logic signed [31:0] a, b
    );
        logic signed [63:0] p;
        p = a * b;
        return p[47:16];
    endfunction

    // qrecip is no longer used as a single-cycle combinational call.
    // The pipelined S_RAY_SETUP spreads the two N-R iterations across
    // registered stages; qrecip_r0 returns the initial estimate only.
    function automatic logic signed [31:0] qrecip_r0(input logic signed [31:0] xabs);
        if      (|xabs[31:16]) return 32'h0001_0000;
        else if (xabs[15])     return 32'h0001_8000;
        else if (xabs[14])     return 32'h0003_0000;
        else if (xabs[13])     return 32'h0006_0000;
        else if (xabs[12])     return 32'h000C_0000;
        else                   return 32'h0018_0000;
    endfunction

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE        = 4'd0,
        S_RAY_SETUP   = 4'd1,
        S_ROOT_SLAB   = 4'd2,
        S_ENTER_NODE  = 4'd3,
        S_BRAM_WAIT   = 4'd4,
        S_CHECK_CHILD = 4'd5,
        S_EMPTY       = 4'd6,
        S_SOLID       = 4'd7,
        S_MIXED       = 4'd8,
        S_POP_STACK   = 4'd9,
        S_MISS        = 4'd10,
        S_WAIT_SHADE  = 4'd11,
        S_WRITE_PIXEL = 4'd12,
        S_NEXT_PIXEL  = 4'd13
    } state_t;

    (* fsm_encoding = "sequential" *) state_t state;
    logic [3:0] state_raw; assign state_raw = state;
    assign dbg_state   = state_raw;
    assign dbg_rs_wait = rs_wait;
    assign dbg_px      = px;
    assign dbg_py      = py;
    assign dbg_tvalid  = axis_tvalid;
    assign dbg_tready  = axis_tready;

    // -------------------------------------------------------------------------
    // Pixel counters (primary-ray mode only)
    // -------------------------------------------------------------------------
    logic [8:0] px;
    logic [7:0] py;

    // -------------------------------------------------------------------------
    // Ray registers (Q16.16)
    // -------------------------------------------------------------------------
    logic signed [31:0] ro_x, ro_y, ro_z;
    logic signed [31:0] rd_x, rd_y, rd_z;
    // keep prevents Vivado retiming these across the stage 13→0 pipeline boundary
    (* keep = "true" *) logic signed [31:0] inv_x, inv_y, inv_z;

    // -------------------------------------------------------------------------
    // DDA registers
    // -------------------------------------------------------------------------
    logic signed [31:0] t_min, t_max;
    logic signed [31:0] t_next_x, t_next_y, t_next_z;
    logic signed [31:0] dt_x, dt_y, dt_z;
    logic signed [2:0]  step_x, step_y, step_z;
    logic [5:0] cx, cy, cz;
    logic [5:0] node_half;
    logic [5:0] node_origin_x, node_origin_y, node_origin_z;

    // S_ROOT_SLAB pipeline registers (5 stages via rs_wait 0→4)
    // keep prevents Vivado retiming these across the stage 0→1 pipeline boundary
    (* keep = "true" *) logic signed [31:0] rs_tx0, rs_tx1, rs_ty0, rs_ty1, rs_tz0, rs_tz1; // stage 0: qmul results
    logic signed [31:0] rs_min_x, rs_max_x, rs_min_y, rs_max_y, rs_min_z, rs_max_z; // stage 1: sorted pairs
    logic signed [31:0] rs_tmin_xy, rs_tmax_xy; // stage 2: partial XY max/min
    logic [6:0]         bw_icx_c, bw_icy_c, bw_icz_c;
    logic [1:0]         em_face;
    logic               em_fsign;

    // Pre-registered negated/offset ro values for S_ROOT_SLAB stage 0 (avoids CARRY4 before DSP)
    logic signed [31:0] ro_neg_x_r, ro_neg_y_r, ro_neg_z_r;
    logic signed [31:0] ro_ws_x_r,  ro_ws_y_r,  ro_ws_z_r;

    // Ray-setup pipeline registers.
    // Primary mode uses stages 0-13 (14 cycles).  Shadow mode uses stages 0-4 (5 cycles).
    // Each stage performs at most one dependent qmul chain, keeping every path < 10 ns.
    // Naming convention: rs_<var>_r = registered output of a pipeline stage.
    logic signed [31:0] rs_rsu_r,    rs_rsv_r;           // stage 0: pixel offsets
    logic signed [31:0] rs_rsdx_r,   rs_rsdy_r,  rs_rsdz_r;  // stage 1: raw ray dir
    logic signed [31:0] rs_rslen2_r;                     // stage 2: |raw dir|²
    logic signed [31:0] rs_rilinv_r;                     // stage 3: first inv_len estimate
    logic signed [31:0] rs_rilsq_r;                      // stage 4: rilinv²
    logic signed [31:0] rs_riltmp_r;                     // stage 5: rslen2 · rilinv²
    logic signed [31:0] rs_rilsub_r;                     // stage 6: 1.5 − 0.5·riltmp
    logic signed [31:0] rs_rilinv2_r;                    // stage 7: refined inv_len
    logic signed [31:0] rs_ndx_r,    rs_ndy_r,   rs_ndz_r;   // stage 8: normalised dir
    logic signed [31:0] rs_ax_r,     rs_ay_r,    rs_az_r;    // stage 9: |nd|
    logic signed [31:0] rs_r0x_r,    rs_r0y_r,   rs_r0z_r;   // stage 9: initial reciprocal
    logic signed [31:0] rs_rma_x_r,  rs_rma_y_r, rs_rma_z_r; // stage 10: xabs·r0
    logic signed [31:0] rs_r1x_r,    rs_r1y_r,   rs_r1z_r;   // stage 11: after N-R iter 1
    logic signed [31:0] rs_rmb_x_r,  rs_rmb_y_r, rs_rmb_z_r; // stage 13 primary / stage 4 shadow: xabs·r1
    logic signed [31:0] rs_sub1x_r, rs_sub1y_r, rs_sub1z_r;   // stage 11 primary / stage 2 shadow: 2 − rma
    logic signed [31:0] rs_sub2x_r, rs_sub2y_r, rs_sub2z_r;   // stage 14 primary / stage 5 shadow: 2 − rmb

    // -------------------------------------------------------------------------
    // SVO node registers
    // -------------------------------------------------------------------------
    logic [15:0] node_idx;
    logic [15:0] bitmask;
    logic [2:0]  cidx;
    logic [15:0] r_child [0:7];
    logic [7:0]  r_block [0:7];
    logic [15:0] r_bitmask;
    logic [2:0]  bram_field;

    // Hit info
    logic [7:0]  block_id_hit;
    logic signed [31:0] t_hit;
    logic [1:0]  hit_face;
    logic        hit_face_sign_r;
    logic signed [31:0] hit_px_r, hit_py_r, hit_pz_r;

    // -------------------------------------------------------------------------
    // Stack
    // -------------------------------------------------------------------------
    logic [3:0]  sp;
    logic [15:0] stk_node_idx    [0:STACK_DEPTH-1];
    logic [15:0] stk_bitmask     [0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_min      [0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_max      [0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_x   [0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_y   [0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_z   [0:STACK_DEPTH-1];
    logic [5:0]  stk_cx          [0:STACK_DEPTH-1];
    logic [5:0]  stk_cy          [0:STACK_DEPTH-1];
    logic [5:0]  stk_cz          [0:STACK_DEPTH-1];
    logic [5:0]  stk_node_half   [0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_x      [0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_y      [0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_z      [0:STACK_DEPTH-1];

    logic [23:0] pixel_color;

    // Pipeline stage counter for S_RAY_SETUP.
    // Primary mode: stages 0-13 (14 cycles). Shadow mode: stages 0-4 (5 cycles).
    // No multicycle path constraint required — every stage fits in one 10 ns cycle.
    logic [4:0] rs_wait;

    // Set when S_POP_STACK redirects through S_ENTER_NODE to reload r_child[]/r_block[].
    // Suppresses the cx/cy/cz and t_next recomputation in S_BRAM_WAIT field=6.
    logic post_pop;

    // -------------------------------------------------------------------------
    // Combinational pre-computations — DSP runs unconditionally (CE='1').
    // Each qmul result is captured only on the relevant FSM cycle.
    // -------------------------------------------------------------------------

    // Ray entry point: ro + t_min * rd  (used by both S_BRAM_WAIT and S_SOLID)
    // Free-running pipeline registers for bw_qmul: breaks DSP→CARRY4 chain on bw_e*_c.
    // Consumers and timing guarantees:
    //   S_BRAM_WAIT field=6: t_min last written in S_ROOT_SLAB stage 3; field=6 is
    //     10+ cycles later — bw_qmul_*_r has settled with correct t_min for 9+ cycles.
    //   S_SOLID: t_min updated in S_EMPTY; S_CHECK_CHILD (1 cycle) provides the
    //     required gap — bw_qmul_*_r holds qmul(new_t_min, rd_*) by the time S_SOLID fires.
    //     WARNING: do not add a direct S_EMPTY→S_SOLID path; S_CHECK_CHILD gap is required.
    logic signed [31:0] bw_ex_c, bw_ey_c, bw_ez_c;
    logic signed [31:0] bw_qmul_x_r, bw_qmul_y_r, bw_qmul_z_r;
    always_ff @(posedge clk) begin
        bw_qmul_x_r <= qmul(t_min, rd_x);
        bw_qmul_y_r <= qmul(t_min, rd_y);
        bw_qmul_z_r <= qmul(t_min, rd_z);
    end
    assign bw_ex_c = ro_x + bw_qmul_x_r;
    assign bw_ey_c = ro_y + bw_qmul_y_r;
    assign bw_ez_c = ro_z + bw_qmul_z_r;

    // |inv_dir| per axis (S_BRAM_WAIT and S_POP_STACK)
    logic signed [31:0] bw_abs_ix_c, bw_abs_iy_c, bw_abs_iz_c;
    assign bw_abs_ix_c = inv_x[31] ? -inv_x : inv_x;
    assign bw_abs_iy_c = inv_y[31] ? -inv_y : inv_y;
    assign bw_abs_iz_c = inv_z[31] ? -inv_z : inv_z;

    // node_half in Q16.16 (S_BRAM_WAIT)
    logic signed [31:0] bw_nh_c;
    assign bw_nh_c = $signed(32'(node_half)) << 16;

    // dt = node_half * |inv|  (S_BRAM_WAIT)
    logic signed [31:0] dt_x_bw_c, dt_y_bw_c, dt_z_bw_c;
    assign dt_x_bw_c = qmul(bw_nh_c, bw_abs_ix_c);
    assign dt_y_bw_c = qmul(bw_nh_c, bw_abs_iy_c);
    assign dt_z_bw_c = qmul(bw_nh_c, bw_abs_iz_c);

    // Entry-point child index, relative position, and distance to next boundary
    logic signed [31:0] bw_ex_rel_c, bw_ey_rel_c, bw_ez_rel_c;
    logic signed [31:0] bw_dist_x_c, bw_dist_y_c, bw_dist_z_c;

    always_comb begin
        bw_icx_c = ($signed(bw_ex_c) < 0) ? 7'd0 : bw_ex_c[22:16];
        bw_icy_c = ($signed(bw_ey_c) < 0) ? 7'd0 : bw_ey_c[22:16];
        bw_icz_c = ($signed(bw_ez_c) < 0) ? 7'd0 : bw_ez_c[22:16];
        // Clamp on underflow: rounding can land bw_ic* just below node origin
        bw_icx_c = (bw_icx_c >= node_origin_x) ? bw_icx_c - node_origin_x : 7'd0;
        bw_icy_c = (bw_icy_c >= node_origin_y) ? bw_icy_c - node_origin_y : 7'd0;
        bw_icz_c = (bw_icz_c >= node_origin_z) ? bw_icz_c - node_origin_z : 7'd0;
        bw_ex_rel_c = bw_ex_c - ($signed(32'(node_origin_x)) << 16);
        bw_ey_rel_c = bw_ey_c - ($signed(32'(node_origin_y)) << 16);
        bw_ez_rel_c = bw_ez_c - ($signed(32'(node_origin_z)) << 16);
        if (!step_x[2])
            bw_dist_x_c = (bw_icx_c >= node_half) ? ((bw_nh_c <<< 1) - bw_ex_rel_c) : (bw_nh_c - bw_ex_rel_c);
        else
            bw_dist_x_c = (bw_icx_c >= node_half) ? (bw_ex_rel_c - bw_nh_c) : bw_ex_rel_c;
        if (!step_y[2])
            bw_dist_y_c = (bw_icy_c >= node_half) ? ((bw_nh_c <<< 1) - bw_ey_rel_c) : (bw_nh_c - bw_ey_rel_c);
        else
            bw_dist_y_c = (bw_icy_c >= node_half) ? (bw_ey_rel_c - bw_nh_c) : bw_ey_rel_c;
        if (!step_z[2])
            bw_dist_z_c = (bw_icz_c >= node_half) ? ((bw_nh_c <<< 1) - bw_ez_rel_c) : (bw_nh_c - bw_ez_rel_c);
        else
            bw_dist_z_c = (bw_icz_c >= node_half) ? (bw_ez_rel_c - bw_nh_c) : bw_ez_rel_c;
    end

    // t_next = t_min + dist * |inv|  (S_BRAM_WAIT)
    logic signed [31:0] t_next_x_bw_c, t_next_y_bw_c, t_next_z_bw_c;
    assign t_next_x_bw_c = t_min + qmul(bw_dist_x_c, bw_abs_ix_c);
    assign t_next_y_bw_c = t_min + qmul(bw_dist_y_c, bw_abs_iy_c);
    assign t_next_z_bw_c = t_min + qmul(bw_dist_z_c, bw_abs_iz_c);

    // dt recomputation after stack pop: node_half[sp-1] * |inv|
    logic signed [31:0] dt_x_pop_c, dt_y_pop_c, dt_z_pop_c;
    assign dt_x_pop_c = qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), bw_abs_ix_c);
    assign dt_y_pop_c = qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), bw_abs_iy_c);
    assign dt_z_pop_c = qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), bw_abs_iz_c);

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= S_IDLE;
            busy       <= '0;
            frame_done <= '0;
            any_hit    <= '0;
            fb_wr_en    <= '0;
            svo_rd_en   <= '0;
            shade_start <= '0;
            axis_tvalid <= '0;
            axis_tdata  <= '0;
            axis_tlast  <= '0;
            axis_tuser  <= '0;
            px <= '0; py <= '0; sp <= '0; rs_wait <= '0; post_pop <= '0;
        end else begin
            fb_wr_en    <= '0;
            frame_done  <= '0;
            any_hit     <= '0;
            shade_start <= '0;
            axis_tvalid <= '0;

            unique case (state)

            // -----------------------------------------------------------------
            S_IDLE: begin
                busy <= '0;
                if (start) begin
                    busy      <= 1'b1;
                    px        <= '0;
                    py        <= '0;
                    sp        <= '0;
                    rs_wait   <= '0;
                    node_half <= 6'(WORLD_SIZE >> 1);
                    state     <= S_RAY_SETUP;
                end
            end

            // -----------------------------------------------------------------
            // S_RAY_SETUP: pipelined ray-direction computation.
            //
            // Every stage performs at most one pure subtract OR one pure multiply,
            // so every combinational path fits well within the 10 ns clock period.
            // No multicycle path constraint required.
            //
            // Primary mode (SHADOW_MODE=0): 16 stages, rs_wait 0→15.
            //   0  rsu/rsv   = (px/py − centre) · scale            [1 qmul each]
            //   1  rsdx/y/z  = fwd + rsu·right − rsv·up            [2 parallel qmuls + adds]
            //   2  rslen2    = Σ rsd·rsd                            [3 parallel qmuls + adds]
            //   3  rilinv    = 1.5 − 0.5·rslen2                    [1 qmul]
            //   4  rilsq     = rilinv²                              [1 qmul]
            //   5  riltmp    = rslen2 · rilsq                       [1 qmul]
            //   6  rilsub    = 1.5 − 0.5·riltmp                    [1 qmul]
            //   7  rilinv2   = rilinv · rilsub  (refined inv_len)   [1 qmul]
            //   8  ndx/y/z   = rsd · rilinv2    (normalised dir)    [3 parallel qmuls]
            //   9  ax/y/z    = |nd|, r0 = initial reciprocal est.   [mux + priority enc]
            //  10  rma       = ax · r0                               [3 parallel qmuls]
            //  11  sub1      = 2 − rma                              [pure subtract, ~3 ns]
            //  12  r1        = r0 · sub1   (N-R iter 1)             [3 parallel qmuls]
            //  13  rmb       = ax · r1                              [3 parallel qmuls]
            //  14  sub2      = 2 − rmb                              [pure subtract, ~3 ns]
            //  15  inv       = sign · r1·sub2, capture → ROOT       [3 parallel qmuls + mux]
            //
            // Shadow mode (SHADOW_MODE=1): 7 stages, rs_wait 0→6.
            //   0  ax/y/z = |cam_fwd|, r0 = initial est.
            //   1  rma    = ax · r0
            //   2  sub1   = 2 − rma
            //   3  r1     = r0 · sub1
            //   4  rmb    = ax · r1
            //   5  sub2   = 2 − rmb
            //   6  inv    = sign · r1·sub2, capture → ROOT
            S_RAY_SETUP: begin
                rs_wait <= rs_wait + 1'b1;   // advance each cycle; cleared by S_NEXT_PIXEL / S_IDLE
                if (SHADOW_MODE) begin
                    unique case (rs_wait)
                    5'd0: begin
                        rs_ax_r  <= cam_fwd_x[31] ? -cam_fwd_x : cam_fwd_x;
                        rs_ay_r  <= cam_fwd_y[31] ? -cam_fwd_y : cam_fwd_y;
                        rs_az_r  <= cam_fwd_z[31] ? -cam_fwd_z : cam_fwd_z;
                        rs_r0x_r <= qrecip_r0(cam_fwd_x[31] ? -cam_fwd_x : cam_fwd_x);
                        rs_r0y_r <= qrecip_r0(cam_fwd_y[31] ? -cam_fwd_y : cam_fwd_y);
                        rs_r0z_r <= qrecip_r0(cam_fwd_z[31] ? -cam_fwd_z : cam_fwd_z);
                    end
                    5'd1: begin   // rma = ax · r0  (pure multiply)
                        rs_rma_x_r <= qmul(rs_ax_r, rs_r0x_r);
                        rs_rma_y_r <= qmul(rs_ay_r, rs_r0y_r);
                        rs_rma_z_r <= qmul(rs_az_r, rs_r0z_r);
                    end
                    5'd2: begin   // sub1 = 2 − rma  (pure subtraction, ~3 ns)
                        rs_sub1x_r <= 32'sh0002_0000 - rs_rma_x_r;
                        rs_sub1y_r <= 32'sh0002_0000 - rs_rma_y_r;
                        rs_sub1z_r <= 32'sh0002_0000 - rs_rma_z_r;
                    end
                    5'd3: begin   // r1 = r0 · sub1  (pure multiply)
                        rs_r1x_r <= qmul(rs_r0x_r, rs_sub1x_r);
                        rs_r1y_r <= qmul(rs_r0y_r, rs_sub1y_r);
                        rs_r1z_r <= qmul(rs_r0z_r, rs_sub1z_r);
                    end
                    5'd4: begin   // rmb = ax · r1  (pure multiply)
                        rs_rmb_x_r <= qmul(rs_ax_r, rs_r1x_r);
                        rs_rmb_y_r <= qmul(rs_ay_r, rs_r1y_r);
                        rs_rmb_z_r <= qmul(rs_az_r, rs_r1z_r);
                    end
                    5'd5: begin   // sub2 = 2 − rmb  (pure subtraction, ~3 ns)
                        rs_sub2x_r <= 32'sh0002_0000 - rs_rmb_x_r;
                        rs_sub2y_r <= 32'sh0002_0000 - rs_rmb_y_r;
                        rs_sub2z_r <= 32'sh0002_0000 - rs_rmb_z_r;
                    end
                    5'd6: begin   // inv = sign · r1·sub2, capture
                        ro_x <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                        rd_x <= cam_fwd_x; rd_y <= cam_fwd_y; rd_z <= cam_fwd_z;
                        inv_x <= cam_fwd_x[31] ? -qmul(rs_r1x_r, rs_sub2x_r)
                                               :  qmul(rs_r1x_r, rs_sub2x_r);
                        inv_y <= cam_fwd_y[31] ? -qmul(rs_r1y_r, rs_sub2y_r)
                                               :  qmul(rs_r1y_r, rs_sub2y_r);
                        inv_z <= cam_fwd_z[31] ? -qmul(rs_r1z_r, rs_sub2z_r)
                                               :  qmul(rs_r1z_r, rs_sub2z_r);
                        step_x <= (cam_fwd_x >= 0) ? 3'sd1 : -3'sd1;
                        step_y <= (cam_fwd_y >= 0) ? 3'sd1 : -3'sd1;
                        step_z <= (cam_fwd_z >= 0) ? 3'sd1 : -3'sd1;
                        ro_neg_x_r <= -cam_pos_x;
                        ro_neg_y_r <= -cam_pos_y;
                        ro_neg_z_r <= -cam_pos_z;
                        ro_ws_x_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_x;
                        ro_ws_y_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_y;
                        ro_ws_z_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_z;
                        sp      <= '0;
                        rs_wait <= '0;
                        state   <= S_ROOT_SLAB;
                    end
                    default: ;
                    endcase
                end else begin
                    // ---- Primary mode pipeline ----
                    unique case (rs_wait)
                    5'd0: begin   // pixel offset × scale
                        rs_rsu_r <= qmul($signed({1'b0, px, 16'd0}) - 32'sh00A0_0000, cam_scale);
                        rs_rsv_r <= qmul($signed({1'b0, py, 16'd0}) - 32'sh0078_0000, cam_scale);
                    end
                    5'd1: begin   // raw ray direction (two parallel qmuls per component)
                        rs_rsdx_r <= cam_fwd_x + qmul(rs_rsu_r, cam_right_x) - qmul(rs_rsv_r, cam_up_x);
                        rs_rsdy_r <= cam_fwd_y + qmul(rs_rsu_r, cam_right_y) - qmul(rs_rsv_r, cam_up_y);
                        rs_rsdz_r <= cam_fwd_z + qmul(rs_rsu_r, cam_right_z) - qmul(rs_rsv_r, cam_up_z);
                    end
                    5'd2: begin   // squared length of raw direction
                        rs_rslen2_r <= qmul(rs_rsdx_r, rs_rsdx_r)
                                     + qmul(rs_rsdy_r, rs_rsdy_r)
                                     + qmul(rs_rsdz_r, rs_rsdz_r);
                    end
                    5'd3: begin   // first inverse-length estimate: 1.5 − 0.5·|d|²
                        rs_rilinv_r <= 32'sh0001_8000 - qmul(32'sh0000_8000, rs_rslen2_r);
                    end
                    5'd4: begin   // rilinv²
                        rs_rilsq_r <= qmul(rs_rilinv_r, rs_rilinv_r);
                    end
                    5'd5: begin   // |d|² · rilinv²
                        rs_riltmp_r <= qmul(rs_rslen2_r, rs_rilsq_r);
                    end
                    5'd6: begin   // 1.5 − 0.5·tmp  (N-R correction factor)
                        rs_rilsub_r <= 32'sh0001_8000 - qmul(32'sh0000_8000, rs_riltmp_r);
                    end
                    5'd7: begin   // refined inverse length
                        rs_rilinv2_r <= qmul(rs_rilinv_r, rs_rilsub_r);
                    end
                    5'd8: begin   // normalised direction
                        rs_ndx_r <= qmul(rs_rsdx_r, rs_rilinv2_r);
                        rs_ndy_r <= qmul(rs_rsdy_r, rs_rilinv2_r);
                        rs_ndz_r <= qmul(rs_rsdz_r, rs_rilinv2_r);
                    end
                    5'd9: begin   // |nd| and initial reciprocal estimate (no qmul)
                        rs_ax_r  <= rs_ndx_r[31] ? -rs_ndx_r : rs_ndx_r;
                        rs_ay_r  <= rs_ndy_r[31] ? -rs_ndy_r : rs_ndy_r;
                        rs_az_r  <= rs_ndz_r[31] ? -rs_ndz_r : rs_ndz_r;
                        rs_r0x_r <= qrecip_r0(rs_ndx_r[31] ? -rs_ndx_r : rs_ndx_r);
                        rs_r0y_r <= qrecip_r0(rs_ndy_r[31] ? -rs_ndy_r : rs_ndy_r);
                        rs_r0z_r <= qrecip_r0(rs_ndz_r[31] ? -rs_ndz_r : rs_ndz_r);
                    end
                    5'd10: begin  // xabs · r0
                        rs_rma_x_r <= qmul(rs_ax_r, rs_r0x_r);
                        rs_rma_y_r <= qmul(rs_ay_r, rs_r0y_r);
                        rs_rma_z_r <= qmul(rs_az_r, rs_r0z_r);
                    end
                    5'd11: begin  // sub1 = 2 − rma  (pure subtraction, ~3 ns)
                        rs_sub1x_r <= 32'sh0002_0000 - rs_rma_x_r;
                        rs_sub1y_r <= 32'sh0002_0000 - rs_rma_y_r;
                        rs_sub1z_r <= 32'sh0002_0000 - rs_rma_z_r;
                    end
                    5'd12: begin  // r1 = r0 · sub1  N-R iter 1  (pure multiply)
                        rs_r1x_r <= qmul(rs_r0x_r, rs_sub1x_r);
                        rs_r1y_r <= qmul(rs_r0y_r, rs_sub1y_r);
                        rs_r1z_r <= qmul(rs_r0z_r, rs_sub1z_r);
                    end
                    5'd13: begin  // rmb = ax · r1  (pure multiply)
                        rs_rmb_x_r <= qmul(rs_ax_r, rs_r1x_r);
                        rs_rmb_y_r <= qmul(rs_ay_r, rs_r1y_r);
                        rs_rmb_z_r <= qmul(rs_az_r, rs_r1z_r);
                    end
                    5'd14: begin  // sub2 = 2 − rmb  (pure subtraction, ~3 ns)
                        rs_sub2x_r <= 32'sh0002_0000 - rs_rmb_x_r;
                        rs_sub2y_r <= 32'sh0002_0000 - rs_rmb_y_r;
                        rs_sub2z_r <= 32'sh0002_0000 - rs_rmb_z_r;
                    end
                    5'd15: begin  // inv = sign · r1·sub2, capture  (pure multiply)
                        rd_x <= rs_ndx_r; rd_y <= rs_ndy_r; rd_z <= rs_ndz_r;
                        ro_x <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                        inv_x <= rs_ndx_r[31] ? -qmul(rs_r1x_r, rs_sub2x_r)
                                              :  qmul(rs_r1x_r, rs_sub2x_r);
                        inv_y <= rs_ndy_r[31] ? -qmul(rs_r1y_r, rs_sub2y_r)
                                              :  qmul(rs_r1y_r, rs_sub2y_r);
                        inv_z <= rs_ndz_r[31] ? -qmul(rs_r1z_r, rs_sub2z_r)
                                              :  qmul(rs_r1z_r, rs_sub2z_r);
                        step_x <= (rs_ndx_r >= 0) ? 3'sd1 : -3'sd1;
                        step_y <= (rs_ndy_r >= 0) ? 3'sd1 : -3'sd1;
                        step_z <= (rs_ndz_r >= 0) ? 3'sd1 : -3'sd1;
                        ro_neg_x_r <= -cam_pos_x;
                        ro_neg_y_r <= -cam_pos_y;
                        ro_neg_z_r <= -cam_pos_z;
                        ro_ws_x_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_x;
                        ro_ws_y_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_y;
                        ro_ws_z_r  <= $signed(32'(WORLD_SIZE) << 16) - cam_pos_z;
                        sp      <= '0;
                        rs_wait <= '0;
                        state   <= S_ROOT_SLAB;
                    end
                    default: ;
                    endcase
                end
            end

            // -----------------------------------------------------------------
            // S_ROOT_SLAB: 5-stage pipelined AABB slab intersection.
            // rs_wait is 0 on entry (set by S_RAY_SETUP stage 15/6).
            // Stage 0: register 6 qmul results         (~13 ns each, parallel)
            // Stage 1: sort each axis pair              (32-bit compare+mux, ~4 ns)
            // Stage 2: partial XY max/min               (~4 ns)
            // Stage 3: final t_min/t_max into registers (~4 ns)
            // Stage 4: miss check → state transition    (~5 ns)
            S_ROOT_SLAB: begin
                unique case (rs_wait)
                5'd0: begin
                    rs_tx0  <= qmul(ro_neg_x_r, inv_x);
                    rs_tx1  <= qmul(ro_ws_x_r,  inv_x);
                    rs_ty0  <= qmul(ro_neg_y_r, inv_y);
                    rs_ty1  <= qmul(ro_ws_y_r,  inv_y);
                    rs_tz0  <= qmul(ro_neg_z_r, inv_z);
                    rs_tz1  <= qmul(ro_ws_z_r,  inv_z);
                    rs_wait <= 5'd1;
                end
                5'd1: begin
                    rs_min_x <= (rs_tx0 < rs_tx1) ? rs_tx0 : rs_tx1;
                    rs_max_x <= (rs_tx0 < rs_tx1) ? rs_tx1 : rs_tx0;
                    rs_min_y <= (rs_ty0 < rs_ty1) ? rs_ty0 : rs_ty1;
                    rs_max_y <= (rs_ty0 < rs_ty1) ? rs_ty1 : rs_ty0;
                    rs_min_z <= (rs_tz0 < rs_tz1) ? rs_tz0 : rs_tz1;
                    rs_max_z <= (rs_tz0 < rs_tz1) ? rs_tz1 : rs_tz0;
                    rs_wait  <= 5'd2;
                end
                5'd2: begin
                    rs_tmin_xy <= (rs_min_x > rs_min_y) ? rs_min_x : rs_min_y;
                    rs_tmax_xy <= (rs_max_x < rs_max_y) ? rs_max_x : rs_max_y;
                    rs_wait    <= 5'd3;
                end
                5'd3: begin
                    t_min   <= (rs_tmin_xy > rs_min_z) ? rs_tmin_xy : rs_min_z;
                    t_max   <= (rs_tmax_xy < rs_max_z) ? rs_tmax_xy : rs_max_z;
                    rs_wait <= 5'd4;
                end
                5'd4: begin
                    rs_wait <= 5'd0;
                    if (t_min > t_max)
                        state <= S_MISS;
                    else begin
                        node_idx      <= '0;
                        node_origin_x <= '0; node_origin_y <= '0; node_origin_z <= '0;
                        state         <= S_ENTER_NODE;
                    end
                end
                default: ;
                endcase
            end

            // -----------------------------------------------------------------
            S_ENTER_NODE: begin
                bram_field  <= 3'd7;   // sentinel: first S_BRAM_WAIT cycle absorbs BRAM latency
                svo_rd_en   <= 1'b1;
                svo_rd_addr <= {node_idx[11:0], 3'd0};
                state       <= S_BRAM_WAIT;
            end

            // -----------------------------------------------------------------
            // svo_bram has a registered output (1-cycle read latency after addr
            // is registered by the FSM), so data is valid 2 edges after the FSM
            // sets svo_rd_addr.  bram_field=7 is a pure wait that absorbs this
            // extra cycle; fields 0-6 then read words 0-6 with correct alignment.
            S_BRAM_WAIT: begin
                unique case (bram_field)
                    3'd7: begin   // wait: word-0 addr issued in S_ENTER_NODE, data ready next cycle
                        svo_rd_addr <= {node_idx[11:0], 3'd1};
                        bram_field  <= 3'd0;
                    end
                    3'd0: begin   // read word 0 = bitmask
                        r_bitmask <= svo_rd_data[15:0];
                        svo_rd_addr <= {node_idx[11:0], 3'd2};
                        bram_field  <= 3'd1;
                    end
                    3'd1: begin   // read word 1 = child ptrs 0-1
                        r_child[0]<=svo_rd_data[15:0]; r_child[1]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[11:0], 3'd3};
                        bram_field  <= 3'd2;
                    end
                    3'd2: begin   // read word 2 = child ptrs 2-3
                        r_child[2]<=svo_rd_data[15:0]; r_child[3]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[11:0], 3'd4};
                        bram_field  <= 3'd3;
                    end
                    3'd3: begin   // read word 3 = child ptrs 4-5
                        r_child[4]<=svo_rd_data[15:0]; r_child[5]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[11:0], 3'd5};
                        bram_field  <= 3'd4;
                    end
                    3'd4: begin   // read word 4 = child ptrs 6-7
                        r_child[6]<=svo_rd_data[15:0]; r_child[7]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[11:0], 3'd6};
                        bram_field  <= 3'd5;
                    end
                    3'd5: begin   // read word 5 = block IDs 0-3; word-6 addr already issued
                        r_block[0]<=svo_rd_data[7:0];   r_block[1]<=svo_rd_data[15:8];
                        r_block[2]<=svo_rd_data[23:16]; r_block[3]<=svo_rd_data[31:24];
                        svo_rd_en  <= '0;
                        bram_field <= 3'd6;
                    end
                    3'd6: begin   // read word 6 = block IDs 4-7; done
                        r_block[4]<=svo_rd_data[7:0];   r_block[5]<=svo_rd_data[15:8];
                        r_block[6]<=svo_rd_data[23:16]; r_block[7]<=svo_rd_data[31:24];
                    end
                    default: ;
                endcase
                if (bram_field == 3'd6) begin
                    svo_rd_en <= '0;
                    bitmask   <= r_bitmask;
                    if (post_pop) begin
                        // r_child[]/r_block[] now hold the parent node's data.
                        // cx/cy/cz, t_next, and dt were already restored by S_POP_STACK.
                        post_pop <= 1'b0;
                        state    <= S_EMPTY;
                    end else begin
                    cx       <= (bw_icx_c >= node_half) ? 6'd1 : 6'd0;
                    cy       <= (bw_icy_c >= node_half) ? 6'd1 : 6'd0;
                    cz       <= (bw_icz_c >= node_half) ? 6'd1 : 6'd0;
                    dt_x     <= dt_x_bw_c;
                    dt_y     <= dt_y_bw_c;
                    dt_z     <= dt_z_bw_c;
                    t_next_x <= t_next_x_bw_c;
                    t_next_y <= t_next_y_bw_c;
                    t_next_z <= t_next_z_bw_c;
                    state    <= S_CHECK_CHILD;
                    end  // end else (not post_pop)
                end
            end

            // -----------------------------------------------------------------
            S_CHECK_CHILD: begin
                cidx <= {cz[0], cy[0], cx[0]};
                unique case (2'((r_bitmask >> ({cz[0],cy[0],cx[0]} * 2)) & 16'h0003))
                    2'b00:   state <= S_EMPTY;
                    2'b11:   state <= S_SOLID;
                    2'b01:   state <= S_MIXED;
                    default: state <= S_EMPTY;
                endcase
            end

            // -----------------------------------------------------------------
            S_EMPTY: begin
                if (t_next_x <= t_next_y && t_next_x <= t_next_z) begin
                    cx       <= cx + {{3{step_x[2]}}, step_x};  // sign-extend 3-bit step
                    t_min    <= t_next_x; t_next_x <= t_next_x + dt_x;
                    em_face  = 2'd0; em_fsign = step_x[2];      // MSB is sign
                    state    <= (step_x[2] ^ cx[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else if (t_next_y <= t_next_z) begin
                    cy       <= cy + {{3{step_y[2]}}, step_y};
                    t_min    <= t_next_y; t_next_y <= t_next_y + dt_y;
                    em_face  = 2'd1; em_fsign = step_y[2];
                    state    <= (step_y[2] ^ cy[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else begin
                    cz       <= cz + {{3{step_z[2]}}, step_z};
                    t_min    <= t_next_z; t_next_z <= t_next_z + dt_z;
                    em_face  = 2'd2; em_fsign = step_z[2];
                    state    <= (step_z[2] ^ cz[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end
                hit_face        <= em_face;
                hit_face_sign_r <= em_fsign;
            end

            // -----------------------------------------------------------------
            S_SOLID: begin
                t_hit        <= t_min;
                block_id_hit <= r_block[cidx];
                hit_px_r     <= bw_ex_c;
                hit_py_r     <= bw_ey_c;
                hit_pz_r     <= bw_ez_c;
                if (SHADOW_MODE) begin
                    // Shadow mode: immediately signal hit and stop
                    any_hit    <= 1'b1;
                    frame_done <= 1'b1;
                    state      <= S_IDLE;
                end else if (SHADE_MODE) begin
                    // hand off to shading pipeline
                    shade_is_miss       <= 1'b0;
                    shade_hit_face      <= hit_face;
                    shade_hit_face_sign <= hit_face_sign_r;
                    shade_block_id      <= r_block[cidx];
                    shade_t_hit         <= t_min;
                    shade_ray_dx        <= rd_x;
                    shade_ray_dy        <= rd_y;
                    shade_ray_dz        <= rd_z;
                    shade_hit_px        <= bw_ex_c;
                    shade_hit_py        <= bw_ey_c;
                    shade_hit_pz        <= bw_ez_c;
                    shade_start         <= 1'b1;
                    state               <= S_WAIT_SHADE;
                end else begin
                    pixel_color <= 24'hFF_FF_FF;
                    state       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            S_MIXED: begin
                stk_node_idx [sp] <= node_idx;
                stk_bitmask  [sp] <= r_bitmask;
                stk_t_min    [sp] <= t_min;     stk_t_max    [sp] <= t_max;
                stk_t_next_x [sp] <= t_next_x;  stk_t_next_y [sp] <= t_next_y;
                stk_t_next_z [sp] <= t_next_z;
                stk_cx       [sp] <= cx;  stk_cy [sp] <= cy;  stk_cz [sp] <= cz;
                stk_node_half[sp] <= node_half;
                stk_orig_x   [sp] <= node_origin_x;
                stk_orig_y   [sp] <= node_origin_y;
                stk_orig_z   [sp] <= node_origin_z;
                sp            <= sp + 1'b1;
                node_idx      <= r_child[cidx];
                node_origin_x <= node_origin_x + (cx[0] ? node_half : 6'd0);
                node_origin_y <= node_origin_y + (cy[0] ? node_half : 6'd0);
                node_origin_z <= node_origin_z + (cz[0] ? node_half : 6'd0);
                node_half     <= node_half >> 1;
                state <= S_ENTER_NODE;
            end

            // -----------------------------------------------------------------
            S_POP_STACK: begin
                if (sp == '0)
                    state <= S_MISS;
                else begin
                    sp            <= sp - 1'b1;
                    node_idx      <= stk_node_idx [sp-1];
                    r_bitmask     <= stk_bitmask  [sp-1];
                    t_min         <= stk_t_min    [sp-1]; t_max <= stk_t_max [sp-1];
                    t_next_x      <= stk_t_next_x [sp-1];
                    t_next_y      <= stk_t_next_y [sp-1];
                    t_next_z      <= stk_t_next_z [sp-1];
                    // Recompute dt from restored node_half and per-ray inv (no stack needed)
                    dt_x          <= dt_x_pop_c;
                    dt_y          <= dt_y_pop_c;
                    dt_z          <= dt_z_pop_c;
                    cx            <= stk_cx       [sp-1];
                    cy            <= stk_cy       [sp-1];
                    cz            <= stk_cz       [sp-1];
                    node_half     <= stk_node_half[sp-1];
                    node_origin_x <= stk_orig_x   [sp-1];
                    node_origin_y <= stk_orig_y   [sp-1];
                    node_origin_z <= stk_orig_z   [sp-1];
                    // Re-read BRAM to recover r_child[]/r_block[] for the restored
                    // parent node. post_pop suppresses cx/cy/cz recomputation in
                    // S_BRAM_WAIT field=6 so the stack-restored DDA state is kept.
                    post_pop <= 1'b1;
                    state <= S_ENTER_NODE;
                end
            end

            // -----------------------------------------------------------------
            S_MISS: begin
                if (SHADOW_MODE) begin
                    frame_done <= 1'b1;
                    state      <= S_IDLE;
                end else if (SHADE_MODE) begin
                    shade_is_miss  <= 1'b1;
                    shade_start    <= 1'b1;
                    state          <= S_WAIT_SHADE;
                end else begin
                    pixel_color <= sky_color;
                    state       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            S_WAIT_SHADE: begin
                shade_start <= '0;
                if (shade_done) begin
                    pixel_color <= shade_pixel_color;
                    state       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            S_WRITE_PIXEL: begin
                axis_tvalid <= 1'b1;
                axis_tdata  <= {8'h00, pixel_color};
                axis_tlast  <= (px == 9'(IMG_W - 1));
                axis_tuser  <= (px == '0 && py == '0) ? 1'b1 : 1'b0;
                if (axis_tready)
                    state <= S_NEXT_PIXEL;
                // else: hold tvalid high until tready (AXI-Stream rules)
            end

            // -----------------------------------------------------------------
            S_NEXT_PIXEL: begin
                axis_tvalid <= 1'b0;
                sp          <= '0;
                post_pop    <= 1'b0;
                node_half   <= 6'(WORLD_SIZE >> 1);
                if (px == 9'(IMG_W - 1)) begin
                    px <= '0;
                    if (py == 8'(IMG_H - 1)) begin
                        py         <= '0;
                        frame_done <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        py      <= py + 1'b1;
                        rs_wait <= '0;
                        state   <= S_RAY_SETUP;
                    end
                end else begin
                    px      <= px + 1'b1;
                    rs_wait <= '0;
                    state   <= S_RAY_SETUP;
                end
            end

            endcase
        end
    end

endmodule
