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
    output logic [3:0]  dbg_rs_wait,  // rs_wait counter (0-15); stuck≠advancing→hang
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

    function automatic logic signed [31:0] qrecip(
        input logic signed [31:0] x
    );
        logic signed [31:0] xabs, r, r2;
        xabs = (x < 0) ? -x : x;
        // Initial estimate chosen by magnitude so N-R converges within 3 iterations.
        // Ray components are normalised so |x| ≤ 1 in practice.
        if      (|xabs[31:16]) r = 32'h0001_0000;  // x ≥ 1.0      → r₀=1.0
        else if (xabs[15])     r = 32'h0001_8000;  // x ∈ [0.5,1)  → r₀=1.5
        else if (xabs[14])     r = 32'h0003_0000;  // x ∈ [0.25,0.5) → r₀=3.0
        else if (xabs[13])     r = 32'h0006_0000;  // x ∈ [0.125,0.25) → r₀=6.0
        else if (xabs[12])     r = 32'h000C_0000;  // x ∈ [0.0625,0.125) → r₀=12.0
        else                   r = 32'h0018_0000;  // x < 0.0625    → r₀=24.0
        // 2 N-R iterations: r ← r·(2 − x·r)
        // 3 iterations caused a 140ns combinational chain (23 DSPs, 103 levels),
        // violating the 110ns multicycle budget. With the 6-way initial estimate,
        // 2 iterations give ≤0.4% error for |x|≥0.125, acceptable for DDA traversal.
        r2 = qmul(xabs, r); r2 = 32'h0002_0000 - r2; r = qmul(r, r2);
        r2 = qmul(xabs, r); r2 = 32'h0002_0000 - r2; r = qmul(r, r2);
        return (x < 0) ? -r : r;
    endfunction

    // Absolute value for a Q16.16 signed value.
    function automatic logic signed [31:0] qabs(input logic signed [31:0] x);
        return x[31] ? -x : x;
    endfunction

    // Initial Newton-Raphson estimate for 1/|x|.
    // Uses a 6-way magnitude mux so two N-R iterations converge to <0.07% error
    // for |x| >= 0.0625 -- covers all normalised ray components in practice.
    function automatic logic signed [31:0] recip_init(input logic signed [31:0] x);
        logic signed [31:0] xabs;
        xabs = x[31] ? -x : x;
        return (|xabs[31:16]) ? 32'sh0001_0000 :  // |x| >= 1.0    -> r0=1.0
                xabs[15]      ? 32'sh0001_8000 :  // |x| in [0.5,1)   -> r0=1.5
                xabs[14]      ? 32'sh0003_0000 :  // |x| in [0.25,0.5)-> r0=3.0
                xabs[13]      ? 32'sh0006_0000 :  // |x| in [0.125,0.25)-> r0=6.0
                xabs[12]      ? 32'sh000C_0000 :  // |x| in [0.0625,0.125)-> r0=12.0
                                32'sh0018_0000;   // |x| < 0.0625  -> r0=24.0
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
    // World box upper boundary in Q16.16 (WORLD_SIZE.0). Used by S_ROOT_SLAB.
    localparam logic signed [31:0] WORLD_Q = WORLD_SIZE << 16;
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
    logic signed [31:0] inv_x, inv_y, inv_z;

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

    logic signed [31:0] rs_tx0, rs_tx1, rs_ty0, rs_ty1, rs_tz0, rs_tz1, rs_tmp;
    logic signed [31:0] bw_ex, bw_ey, bw_ez, bw_abs_ix, bw_abs_iy, bw_abs_iz;
    logic signed [31:0] bw_ex_rel, bw_ey_rel, bw_ez_rel;   // position within node (Q16.16)
    logic signed [31:0] bw_dist_x, bw_dist_y, bw_dist_z;   // distance to next boundary
    logic signed [31:0] bw_nh;                               // node_half in Q16.16
    logic [6:0]         bw_icx, bw_icy, bw_icz;
    logic [1:0]         em_face;
    logic               em_fsign;
    logic signed [31:0] rsu, rsv, rsdx, rsdy, rsdz, rslen2, rsinv_len, rsndx, rsndy, rsndz;

    // S_RAY_SETUP pipeline stage registers (primary stages 0-13; shadow stages 0-4).
    // Named by the stage that WRITES them. Registers hold their value until overwritten,
    // so later stages can read earlier outputs without explicit delay registers.
    logic signed [31:0] rs_s1_a, rs_s1_b;          // stage 1: qmul(rsu, cam_right_x), qmul(rsv, cam_up_x)
    logic signed [31:0] rs_s1_c, rs_s1_d;          // stage 1: ... for Y
    logic signed [31:0] rs_s1_e, rs_s1_f;          // stage 1: ... for Z
    logic signed [31:0] rs_s3_dx2, rs_s3_dy2, rs_s3_dz2;  // stage 3: rsd*^2
    logic signed [31:0] rs_s4_y0;                   // stage 4: 1.5 - rslen2/2 (NR seed for 1/sqrt(len))
    logic signed [31:0] rs_s5_y0sq;                 // stage 5: y0^2
    logic signed [31:0] rs_s6_r2y0sq;               // stage 6: rslen2 x y0^2
    // Shared qrecip pipeline -- primary uses these at stages 9-13; shadow at stages 0-4.
    logic signed [31:0] rs_xabs_x, rs_xabs_y, rs_xabs_z;  // |rd_*|
    logic signed [31:0] rs_r0_x,   rs_r0_y,   rs_r0_z;    // initial N-R estimates
    logic signed [31:0] rs_t1_x,   rs_t1_y,   rs_t1_z;    // N-R iteration 1 multiply
    logic signed [31:0] rs_r1_x,   rs_r1_y,   rs_r1_z;    // N-R iteration 1 result
    logic signed [31:0] rs_t2_x,   rs_t2_y,   rs_t2_z;    // N-R iteration 2 multiply
    logic               rs_sign_x, rs_sign_y, rs_sign_z;   // sign of final rd_* component

    // Combinational outputs of every qmul in S_RAY_SETUP.
    // Keeping qmul in always_comb forces DSP CE='1' (always enabled), which
    // eliminates unconstrained DSP ACOUT paths.  The always_ff stages below
    // capture these signals into the pipeline registers at the correct rs_wait
    // stage; the DSPs themselves run every cycle but cause no timing hazard.
    logic signed [31:0] rs_c_rsu,    rs_c_rsv;
    logic signed [31:0] rs_c_s1_a,   rs_c_s1_b;
    logic signed [31:0] rs_c_s1_c,   rs_c_s1_d;
    logic signed [31:0] rs_c_s1_e,   rs_c_s1_f;
    logic signed [31:0] rs_c_dx2,    rs_c_dy2,    rs_c_dz2;
    logic signed [31:0] rs_c_y0sq;
    logic signed [31:0] rs_c_r2y0sq;
    logic signed [31:0] rs_c_inv_len;
    logic signed [31:0] rs_c_ndx,    rs_c_ndy,    rs_c_ndz;
    // Shared N-R: primary stages 10-13; shadow stages 1-4
    logic signed [31:0] rs_c_t1_x,   rs_c_t1_y,   rs_c_t1_z;
    logic signed [31:0] rs_c_r1_x,   rs_c_r1_y,   rs_c_r1_z;
    logic signed [31:0] rs_c_t2_x,   rs_c_t2_y,   rs_c_t2_z;
    logic signed [31:0] rs_c_inv_x,  rs_c_inv_y,  rs_c_inv_z;
    // S_ROOT_SLAB: ray-vs-world-box slab intersection times (CE='1' on all DSPs)
    logic signed [31:0] rs_c_tx0, rs_c_tx1, rs_c_ty0, rs_c_ty1, rs_c_tz0, rs_c_tz1;
    // Entry point P = ro + t_min*rd (Q16.16). Single combinational qmul per axis.
    // bw_c_* feed S_SOLID's hit point directly; bw_ex_r/ey_r/ez_r are the
    // registered copy that breaks the S_BRAM_WAIT t_next two-qmul chain.
    logic signed [31:0] bw_c_ex, bw_c_ey, bw_c_ez;
    logic signed [31:0] bw_ex_r, bw_ey_r, bw_ez_r;

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

    // Stage counter for S_RAY_SETUP pipeline: advances 0->13 (primary mode) or 0->4 (shadow mode).
    logic [3:0] rs_wait;

    // Set when S_POP_STACK redirects through S_ENTER_NODE to reload r_child[]/r_block[].
    // Suppresses the cx/cy/cz and t_next recomputation in S_BRAM_WAIT field=6.
    logic post_pop;

    // -------------------------------------------------------------------------
    // S_RAY_SETUP combinational stage computations (CE='1' on all DSPs)
    // -------------------------------------------------------------------------
    always_comb begin
        rs_c_rsu  = qmul($signed({1'b0, px, 16'd0}) - 32'sh00A0_0000, cam_scale);
        rs_c_rsv  = qmul($signed({1'b0, py, 16'd0}) - 32'sh0078_0000, cam_scale);
    end
    always_comb begin
        rs_c_s1_a = qmul(rsu, cam_right_x); rs_c_s1_b = qmul(rsv, cam_up_x);
        rs_c_s1_c = qmul(rsu, cam_right_y); rs_c_s1_d = qmul(rsv, cam_up_y);
        rs_c_s1_e = qmul(rsu, cam_right_z); rs_c_s1_f = qmul(rsv, cam_up_z);
    end
    always_comb begin
        rs_c_dx2 = qmul(rsdx, rsdx);
        rs_c_dy2 = qmul(rsdy, rsdy);
        rs_c_dz2 = qmul(rsdz, rsdz);
    end
    always_comb rs_c_y0sq   = qmul(rs_s4_y0, rs_s4_y0);
    always_comb rs_c_r2y0sq = qmul(rslen2, rs_s5_y0sq);
    always_comb rs_c_inv_len = qmul(rs_s4_y0, 32'sh0001_8000 - (rs_s6_r2y0sq >>> 1));
    always_comb begin
        rs_c_ndx = qmul(rsdx, rsinv_len);
        rs_c_ndy = qmul(rsdy, rsinv_len);
        rs_c_ndz = qmul(rsdz, rsinv_len);
    end
    // Shared N-R iterations (primary stages 10-13; shadow stages 1-4)
    always_comb begin
        rs_c_t1_x = qmul(rs_xabs_x, rs_r0_x);
        rs_c_t1_y = qmul(rs_xabs_y, rs_r0_y);
        rs_c_t1_z = qmul(rs_xabs_z, rs_r0_z);
    end
    always_comb begin
        rs_c_r1_x = qmul(rs_r0_x, 32'sh0002_0000 - rs_t1_x);
        rs_c_r1_y = qmul(rs_r0_y, 32'sh0002_0000 - rs_t1_y);
        rs_c_r1_z = qmul(rs_r0_z, 32'sh0002_0000 - rs_t1_z);
    end
    always_comb begin
        rs_c_t2_x = qmul(rs_xabs_x, rs_r1_x);
        rs_c_t2_y = qmul(rs_xabs_y, rs_r1_y);
        rs_c_t2_z = qmul(rs_xabs_z, rs_r1_z);
    end
    always_comb begin
        rs_c_inv_x = rs_sign_x ? -qmul(rs_r1_x, 32'sh0002_0000 - rs_t2_x)
                                :  qmul(rs_r1_x, 32'sh0002_0000 - rs_t2_x);
        rs_c_inv_y = rs_sign_y ? -qmul(rs_r1_y, 32'sh0002_0000 - rs_t2_y)
                                :  qmul(rs_r1_y, 32'sh0002_0000 - rs_t2_y);
        rs_c_inv_z = rs_sign_z ? -qmul(rs_r1_z, 32'sh0002_0000 - rs_t2_z)
                                :  qmul(rs_r1_z, 32'sh0002_0000 - rs_t2_z);
    end

    // -------------------------------------------------------------------------
    // S_ROOT_SLAB combinational slab-intersection (CE='1' on all DSPs)
    // ro_* and inv_* are stable from end of S_RAY_SETUP through S_ROOT_SLAB.
    // -------------------------------------------------------------------------
    always_comb begin
        rs_c_tx0 = qmul(-ro_x,          inv_x);
        rs_c_tx1 = qmul(WORLD_Q - ro_x, inv_x);
        rs_c_ty0 = qmul(-ro_y,          inv_y);
        rs_c_ty1 = qmul(WORLD_Q - ro_y, inv_y);
        rs_c_tz0 = qmul(-ro_z,          inv_z);
        rs_c_tz1 = qmul(WORLD_Q - ro_z, inv_z);
    end

    // -------------------------------------------------------------------------
    // Entry-point combinational (CE='1'): P = ro + t_min*rd.
    // t_min, ro_*, rd_* are stable across the whole 8-cycle BRAM read and at the
    // moment of a solid hit, so a single registered copy (bw_ex_r) is always valid.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_ex = ro_x + qmul(t_min, rd_x);
        bw_c_ey = ro_y + qmul(t_min, rd_y);
        bw_c_ez = ro_z + qmul(t_min, rd_z);
    end

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
            // Force pulse signals low every cycle before state case
            fb_wr_en    <= '0;
            frame_done  <= '0;
            any_hit     <= '0;
            shade_start <= '0;
            axis_tvalid <= '0;
            // Capture the combinational entry point every cycle.
            bw_ex_r <= bw_c_ex;
            bw_ey_r <= bw_c_ey;
            bw_ez_r <= bw_c_ez;

            unique case (state)

            // -----------------------------------------------------------------
            S_IDLE: begin
                busy <= '0;
                if (start) begin
                    busy    <= 1'b1;
                    px      <= '0;
                    py      <= '0;
                    sp      <= '0;
                    rs_wait <= '0;
                    state   <= S_RAY_SETUP;
                end
            end

            // -----------------------------------------------------------------
            // S_RAY_SETUP: compute normalised ray direction from pixel + camera.
            //
            // Primary mode: 15-stage registered pipeline (rs_wait 0->14).
            // Stages 0-13: computation (at most one qmul per stage, <=5 ns path).
            // Stage 14 (default): pure state transition — no computation, no DSPs.
            // Separating the state write gives it a minimal path (4-bit decode only),
            // avoiding marginal timing when qmul DSPs share the same case arm.
            //
            // Shadow mode: 6-stage pipeline (rs_wait 0->5). Stages 0-4 compute;
            // stage 5 (default) is the pure state transition.
            //
            // Both modes share rs_xabs/r0/t1/r1/t2/sign registers for qrecip.
            S_RAY_SETUP: begin
                if (SHADOW_MODE) begin
                    case (rs_wait)
                        4'd0: begin
                            ro_x      <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                            rd_x      <= cam_fwd_x; rd_y <= cam_fwd_y; rd_z <= cam_fwd_z;
                            step_x    <= cam_fwd_x[31] ? -3'sd1 : 3'sd1;
                            step_y    <= cam_fwd_y[31] ? -3'sd1 : 3'sd1;
                            step_z    <= cam_fwd_z[31] ? -3'sd1 : 3'sd1;
                            rs_sign_x <= cam_fwd_x[31]; rs_sign_y <= cam_fwd_y[31]; rs_sign_z <= cam_fwd_z[31];
                            rs_xabs_x <= qabs(cam_fwd_x); rs_xabs_y <= qabs(cam_fwd_y); rs_xabs_z <= qabs(cam_fwd_z);
                            rs_r0_x   <= recip_init(cam_fwd_x);
                            rs_r0_y   <= recip_init(cam_fwd_y);
                            rs_r0_z   <= recip_init(cam_fwd_z);
                            rs_wait   <= rs_wait + 1'b1;
                        end
                        4'd1: begin
                            rs_t1_x <= rs_c_t1_x;
                            rs_t1_y <= rs_c_t1_y;
                            rs_t1_z <= rs_c_t1_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd2: begin
                            rs_r1_x <= rs_c_r1_x;
                            rs_r1_y <= rs_c_r1_y;
                            rs_r1_z <= rs_c_r1_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd3: begin
                            rs_t2_x <= rs_c_t2_x;
                            rs_t2_y <= rs_c_t2_y;
                            rs_t2_z <= rs_c_t2_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd4: begin  // capture inv_*, reset sp; advance to transition stage
                            inv_x   <= rs_c_inv_x;
                            inv_y   <= rs_c_inv_y;
                            inv_z   <= rs_c_inv_z;
                            sp      <= '0;
                            rs_wait <= rs_wait + 1'b1;  // -> 5
                        end
                        default: begin  // 4'd5 -- pure state transition, no computation
                            rs_wait <= '0;
                            state   <= S_ROOT_SLAB;
                        end
                    endcase
                end else begin
                    // Primary mode: 14-stage pipeline
                    case (rs_wait)
                        4'd0: begin
                            ro_x    <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                            rsu     <= rs_c_rsu;
                            rsv     <= rs_c_rsv;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd1: begin
                            rs_s1_a <= rs_c_s1_a; rs_s1_b <= rs_c_s1_b;
                            rs_s1_c <= rs_c_s1_c; rs_s1_d <= rs_c_s1_d;
                            rs_s1_e <= rs_c_s1_e; rs_s1_f <= rs_c_s1_f;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd2: begin
                            rsdx    <= cam_fwd_x + rs_s1_a - rs_s1_b;
                            rsdy    <= cam_fwd_y + rs_s1_c - rs_s1_d;
                            rsdz    <= cam_fwd_z + rs_s1_e - rs_s1_f;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd3: begin
                            rs_s3_dx2 <= rs_c_dx2;
                            rs_s3_dy2 <= rs_c_dy2;
                            rs_s3_dz2 <= rs_c_dz2;
                            rs_wait   <= rs_wait + 1'b1;
                        end
                        4'd4: begin
                            rslen2   <= rs_s3_dx2 + rs_s3_dy2 + rs_s3_dz2;
                            rs_s4_y0 <= 32'sh0001_8000 - ((rs_s3_dx2 + rs_s3_dy2 + rs_s3_dz2) >>> 1);
                            rs_wait  <= rs_wait + 1'b1;
                        end
                        4'd5: begin
                            rs_s5_y0sq <= rs_c_y0sq;
                            rs_wait    <= rs_wait + 1'b1;
                        end
                        4'd6: begin
                            rs_s6_r2y0sq <= rs_c_r2y0sq;
                            rs_wait      <= rs_wait + 1'b1;
                        end
                        4'd7: begin
                            rsinv_len <= rs_c_inv_len;
                            rs_wait   <= rs_wait + 1'b1;
                        end
                        4'd8: begin
                            rsndx   <= rs_c_ndx;
                            rsndy   <= rs_c_ndy;
                            rsndz   <= rs_c_ndz;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd9: begin
                            rs_sign_x <= rsndx[31]; rs_sign_y <= rsndy[31]; rs_sign_z <= rsndz[31];
                            rs_xabs_x <= qabs(rsndx); rs_xabs_y <= qabs(rsndy); rs_xabs_z <= qabs(rsndz);
                            rs_r0_x   <= recip_init(rsndx);
                            rs_r0_y   <= recip_init(rsndy);
                            rs_r0_z   <= recip_init(rsndz);
                            step_x    <= rsndx[31] ? -3'sd1 : 3'sd1;
                            step_y    <= rsndy[31] ? -3'sd1 : 3'sd1;
                            step_z    <= rsndz[31] ? -3'sd1 : 3'sd1;
                            rs_wait   <= rs_wait + 1'b1;
                        end
                        4'd10: begin
                            rs_t1_x <= rs_c_t1_x;
                            rs_t1_y <= rs_c_t1_y;
                            rs_t1_z <= rs_c_t1_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd11: begin
                            rs_r1_x <= rs_c_r1_x;
                            rs_r1_y <= rs_c_r1_y;
                            rs_r1_z <= rs_c_r1_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd12: begin
                            rs_t2_x <= rs_c_t2_x;
                            rs_t2_y <= rs_c_t2_y;
                            rs_t2_z <= rs_c_t2_z;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd13: begin  // capture inv_* and rd_*, reset sp; advance to transition stage
                            inv_x   <= rs_c_inv_x;
                            inv_y   <= rs_c_inv_y;
                            inv_z   <= rs_c_inv_z;
                            rd_x    <= rsndx;  rd_y <= rsndy;  rd_z <= rsndz;
                            sp      <= '0;
                            rs_wait <= rs_wait + 1'b1;  // -> 14
                        end
                        default: begin  // 4'd14 -- pure state transition, no computation
                            rs_wait <= '0;
                            state   <= S_ROOT_SLAB;
                        end
                    endcase
                end
            end

            // -----------------------------------------------------------------
            S_ROOT_SLAB: begin
                // Slab boundary times come from the always_comb DSPs (no inline qmul)
                rs_tx0 = rs_c_tx0; rs_tx1 = rs_c_tx1;
                rs_ty0 = rs_c_ty0; rs_ty1 = rs_c_ty1;
                rs_tz0 = rs_c_tz0; rs_tz1 = rs_c_tz1;
                // sort so tx0 is always the smaller value
                if (rs_tx0 > rs_tx1) begin rs_tmp=rs_tx0; rs_tx0=rs_tx1; rs_tx1=rs_tmp; end
                if (rs_ty0 > rs_ty1) begin rs_tmp=rs_ty0; rs_ty0=rs_ty1; rs_ty1=rs_tmp; end
                if (rs_tz0 > rs_tz1) begin rs_tmp=rs_tz0; rs_tz0=rs_tz1; rs_tz1=rs_tmp; end
                // rs_tmp = unclamped t_enter = max(tx0, ty0, tz0); used for miss check
                rs_tmp = (rs_tx0>rs_ty0)?((rs_tx0>rs_tz0)?rs_tx0:rs_tz0):((rs_ty0>rs_tz0)?rs_ty0:rs_tz0);
                // Clamp t_min to 0: when ray origin is inside the world box t_enter < 0,
                // and the backward-projected boundary point would select the wrong child
                // octant. Starting from t=0 (the actual origin) gives correct cx/cy/cz.
                // t_next values are unaffected: t_next = t_min + dist/|rd| algebraically
                // equals the true midplane crossing time regardless of t_min.
                t_min <= ($signed(rs_tmp) < 0) ? 32'sh0 : rs_tmp; //non-blocking for use later
                t_max <= (rs_tx1<rs_ty1)?((rs_tx1<rs_tz1)?rs_tx1:rs_tz1):((rs_ty1<rs_tz1)?rs_ty1:rs_tz1);
                if (rs_tmp >    // use unclamped t_enter for miss check
                    (rs_tx1<rs_ty1 ? (rs_tx1<rs_tz1 ? rs_tx1:rs_tz1):(rs_ty1<rs_tz1 ? rs_ty1:rs_tz1)))
                    state <= S_MISS;
                else begin
                    node_idx      <= '0;
                    node_half     <= 6'(WORLD_SIZE >> 1);
                    node_origin_x <= '0; node_origin_y <= '0; node_origin_z <= '0;
                    state <= S_ENTER_NODE;
                end
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
                    bw_ex  = ro_x + qmul(t_min, rd_x);
                    bw_ey  = ro_y + qmul(t_min, rd_y);
                    bw_ez  = ro_z + qmul(t_min, rd_z);
                    bw_icx = ($signed(bw_ex) < 0) ? 7'd0 : bw_ex[22:16];
                    bw_icy = ($signed(bw_ey) < 0) ? 7'd0 : bw_ey[22:16];
                    bw_icz = ($signed(bw_ez) < 0) ? 7'd0 : bw_ez[22:16];
                    // Clamp to 0 on underflow: rounding can put bw_ic* just below
                    // the child's origin when t_min is a boundary-crossing time.
                    bw_icx = (bw_icx >= node_origin_x) ? bw_icx - node_origin_x : 7'd0;
                    bw_icy = (bw_icy >= node_origin_y) ? bw_icy - node_origin_y : 7'd0;
                    bw_icz = (bw_icz >= node_origin_z) ? bw_icz - node_origin_z : 7'd0;
                    cx  <= (bw_icx >= node_half) ? 6'd1 : 6'd0;
                    cy  <= (bw_icy >= node_half) ? 6'd1 : 6'd0;
                    cz  <= (bw_icz >= node_half) ? 6'd1 : 6'd0;
                    bw_abs_ix = (inv_x >= 0) ? inv_x : -inv_x;
                    bw_abs_iy = (inv_y >= 0) ? inv_y : -inv_y;
                    bw_abs_iz = (inv_z >= 0) ? inv_z : -inv_z;
                    bw_nh = $signed(32'(node_half)) << 16;   // node_half as Q16.16
                    dt_x     <= qmul(bw_nh, bw_abs_ix);
                    dt_y     <= qmul(bw_nh, bw_abs_iy);
                    dt_z     <= qmul(bw_nh, bw_abs_iz);
                    // Correct t_next: distance from entry point to next boundary (not from node edge)
                    bw_ex_rel = bw_ex - ($signed(32'(node_origin_x)) << 16);
                    bw_ey_rel = bw_ey - ($signed(32'(node_origin_y)) << 16);
                    bw_ez_rel = bw_ez - ($signed(32'(node_origin_z)) << 16);
                    if (!step_x[2])  // positive direction: MSB=0
                        bw_dist_x = (bw_icx >= node_half) ?
                            ((bw_nh <<< 1) - bw_ex_rel) :   // cx=1: 2*nh - pos
                            (bw_nh - bw_ex_rel);             // cx=0: nh - pos
                    else
                        bw_dist_x = (bw_icx >= node_half) ?
                            (bw_ex_rel - bw_nh) :            // cx=1: pos - nh
                            bw_ex_rel;                       // cx=0: pos - 0
                    if (!step_y[2])  // positive direction: MSB=0
                        bw_dist_y = (bw_icy >= node_half) ?
                            ((bw_nh <<< 1) - bw_ey_rel) :
                            (bw_nh - bw_ey_rel);
                    else
                        bw_dist_y = (bw_icy >= node_half) ?
                            (bw_ey_rel - bw_nh) :
                            bw_ey_rel;
                    if (!step_z[2])  // positive direction: MSB=0
                        bw_dist_z = (bw_icz >= node_half) ?
                            ((bw_nh <<< 1) - bw_ez_rel) :
                            (bw_nh - bw_ez_rel);
                    else
                        bw_dist_z = (bw_icz >= node_half) ?
                            (bw_ez_rel - bw_nh) :
                            bw_ez_rel;
                    t_next_x <= t_min + qmul(bw_dist_x, bw_abs_ix);
                    t_next_y <= t_min + qmul(bw_dist_y, bw_abs_iy);
                    t_next_z <= t_min + qmul(bw_dist_z, bw_abs_iz);
                    state <= S_CHECK_CHILD;
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
                    em_face  = 2'd0; em_fsign = ~step_x[2];     // outward normal = opposite of ray dir
                    state    <= (step_x[2] ^ cx[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else if (t_next_y <= t_next_z) begin
                    cy       <= cy + {{3{step_y[2]}}, step_y};
                    t_min    <= t_next_y; t_next_y <= t_next_y + dt_y;
                    em_face  = 2'd1; em_fsign = ~step_y[2];
                    state    <= (step_y[2] ^ cy[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else begin
                    cz       <= cz + {{3{step_z[2]}}, step_z};
                    t_min    <= t_next_z; t_next_z <= t_next_z + dt_z;
                    em_face  = 2'd2; em_fsign = ~step_z[2];
                    state    <= (step_z[2] ^ cz[0]) ? S_POP_STACK : S_CHECK_CHILD;
                end
                hit_face        <= em_face;
                hit_face_sign_r <= em_fsign;
            end

            // -----------------------------------------------------------------
            S_SOLID: begin
                t_hit        <= t_min;
                block_id_hit <= r_block[cidx];
                // hit point calc using t and ray direction
                hit_px_r     <= bw_c_ex;
                hit_py_r     <= bw_c_ey;
                hit_pz_r     <= bw_c_ez;
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
                    shade_hit_px        <= bw_c_ex;
                    shade_hit_py        <= bw_c_ey;
                    shade_hit_pz        <= bw_c_ez;
                    shade_start         <= 1'b1;
                    state               <= S_WAIT_SHADE;
                end else begin
                    // non shading for traversal test
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
                    dt_x          <= qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), inv_x[31] ? -inv_x : inv_x);
                    dt_y          <= qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), inv_y[31] ? -inv_y : inv_y);
                    dt_z          <= qmul($signed({10'd0, stk_node_half[sp-1], 16'd0}), inv_z[31] ? -inv_z : inv_z);
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
                // any_hit not asserted, just says its done
                if (SHADOW_MODE) begin
                    frame_done <= 1'b1;
                    state      <= S_IDLE;
                    // Go into shading pipeline as miss
                end else if (SHADE_MODE) begin
                    shade_is_miss  <= 1'b1;
                    shade_start    <= 1'b1;
                    state          <= S_WAIT_SHADE;
                end else begin
                    // Non shading mode for testing traversal
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
                end //Stalls here until shade_done
            end

            // -----------------------------------------------------------------
            S_WRITE_PIXEL: begin
                axis_tvalid <= 1'b1;
                axis_tdata  <= {8'h00, pixel_color};
                // tlast high for last pixel of each line
                //tuser high on first pixel
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
                // reach end of line, reset x and increment y
                if (px == 9'(IMG_W - 1)) begin
                    px <= '0;
                    // end of frame
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
