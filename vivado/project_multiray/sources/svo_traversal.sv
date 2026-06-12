// svo_traversal.sv
// Single-ray hierarchical DDA traversal of a sparse voxel octree.
// One ray in flight; all arithmetic in Q16.16 signed fixed-point.
// SHADOW_MODE selects the role: primary (full-frame render) or shadow (occlusion).
//
// Parameters:
//   SHADOW_MODE = 0  Primary ray: renders full IMG_W x IMG_H frame.
//                    SHADE_MODE=0 -> hits white; SHADE_MODE=1 -> hand off to shading.
//   SHADOW_MODE = 1  Shadow ray: stops at first hit, pulses frame_done.
//                    Uses cam_pos/cam_fwd as ray origin/direction (camera regs ignored).
`timescale 1ns/1ps
module svo_traversal #(
    parameter int IMG_W       = 320,
    parameter int IMG_H       = 240,
    parameter int STACK_DEPTH = 12,
    parameter int WORLD_SIZE  = 64,
    parameter bit SHADOW_MODE = 0,   // 1 = shadow-ray instance
    parameter bit SHADE_MODE  = 0    // 1 = hand off to shading_pipeline on hit
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // Camera / ray-origin registers (Q16.16).
    // In SHADOW_MODE: cam_pos = ray origin, cam_fwd = ray direction (normalised).
    input  logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    input  logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    input  logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    input  logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    input  logic signed [31:0] cam_scale,   // ignored in SHADOW_MODE

    // Sky colour (Phase 1 miss path)
    input  logic [23:0] sky_color,

    // Depth cap (LOD): a MIXED child at sp>=max_depth is treated as a solid
    // occluder. Drive 4'd15 (or any value > tree depth) to disable.
    input  logic [3:0]  max_depth,

    // SVO BRAM read port
    output logic [14:0] svo_rd_addr,
    input  logic [31:0] svo_rd_data,
    output logic        svo_rd_en,

    // Framebuffer write port (legacy; undriven on the AXI-Stream path)
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
    output logic        frame_done,   // doubles as the hit pulse in SHADOW_MODE
    output logic        any_hit,      // SHADOW_MODE: 1 when first solid hit found

    // Debug: read via AXI at run-time
    output logic [3:0]  dbg_state,    // current FSM state value
    output logic [3:0]  dbg_rs_wait,  // S_RAY_SETUP stage counter
    output logic [8:0]  dbg_px,       // current pixel X
    output logic [7:0]  dbg_py,       // current pixel Y
    output logic        dbg_tvalid,   // axis_tvalid
    output logic        dbg_tready    // axis_tready
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


    // Absolute value of a Q16.16 signed value.
    function automatic logic signed [31:0] qabs(input logic signed [31:0] x);
        return x[31] ? -x : x;
    endfunction

    // Initial Newton-Raphson estimate for 1/|x|, picked by a 6-way magnitude mux
    // so two N-R passes converge for any normalised ray component (|x| >= 0.0625).
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
    // Screen centre in Q16.16: (IMG_W/2, IMG_H/2). (IMG/2)<<16 == IMG<<15.
    // Derived from the resolution params so a lower-res build stays centred.
    localparam logic signed [31:0] CENTER_X_Q = $signed(32'(IMG_W) << 15);
    localparam logic signed [31:0] CENTER_Y_Q = $signed(32'(IMG_H) << 15);
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

    // S_ROOT_SLAB is pipelined across rs_wait 0->3; these are its stage registers.
    logic signed [31:0] rs_tx0_r, rs_tx1_r, rs_ty0_r, rs_ty1_r, rs_tz0_r, rs_tz1_r; // stage 0: registered slab times
    logic signed [31:0] rs_lo_x, rs_hi_x, rs_lo_y, rs_hi_y, rs_lo_z, rs_hi_z;        // stage 1: sorted per-axis min/max
    logic signed [31:0] rs_enter_r, rs_exit_r;                                       // stage 2: t_enter / t_exit

    logic [1:0]         em_face;
    logic               em_fsign;
    logic signed [31:0] rsu, rsv, rsdx, rsdy, rsdz, rslen2, rsinv_len, rsndx, rsndy, rsndz;

    // S_RAY_SETUP pipeline stage registers (primary stages 0-13; shadow stages 0-4).
    // Named by the stage that writes them; a register holds until overwritten, so a
    // later stage can read an earlier output with no explicit delay register.
    logic signed [31:0] rs_s1_a, rs_s1_b;          // stage 1: qmul(rsu, cam_right_x), qmul(rsv, cam_up_x)
    logic signed [31:0] rs_s1_c, rs_s1_d;          // stage 1: ... for Y
    logic signed [31:0] rs_s1_e, rs_s1_f;          // stage 1: ... for Z
    logic signed [31:0] rs_s3_dx2, rs_s3_dy2, rs_s3_dz2;  // stage 3: rsd*^2
    logic signed [31:0] rs_s4_y0;                   // stage 4: 1.5 - rslen2/2 (NR seed for 1/sqrt(len))
    logic signed [31:0] rs_s5_y0sq;                 // stage 5: y0^2
    logic signed [31:0] rs_s6_r2y0sq;               // stage 6: rslen2 x y0^2
    // Shared reciprocal-N-R registers -- primary uses these at stages 9-13; shadow at 0-4.
    logic signed [31:0] rs_xabs_x, rs_xabs_y, rs_xabs_z;  // |rd_*|
    logic signed [31:0] rs_r0_x,   rs_r0_y,   rs_r0_z;    // initial N-R estimates
    logic signed [31:0] rs_t1_x,   rs_t1_y,   rs_t1_z;    // N-R iteration 1 multiply
    logic signed [31:0] rs_r1_x,   rs_r1_y,   rs_r1_z;    // N-R iteration 1 result
    logic signed [31:0] rs_t2_x,   rs_t2_y,   rs_t2_z;    // N-R iteration 2 multiply
    logic               rs_sign_x, rs_sign_y, rs_sign_z;   // sign of final rd_* component

    // Shared 3-lane multiplier bank (DSP reduction). The FSM registers operands into
    // q_a*/q_b* in an issue cycle; products are valid QCOL = 4 cycles later
    // (shared_qmul3 latency 3 + the operand register).
    localparam int QCOL = 4;
    logic signed [31:0] q_a0, q_b0, q_a1, q_b1, q_a2, q_b2;
    logic signed [31:0] q_p0, q_p1, q_p2;
    // Entry point P = ro + t_min*rd (Q16.16). The multiply t_min*rd is registered into
    // te_* (its own cycle); the +ro add is combinational in the consuming cycle, so the
    // multiply and wide add sit in separate clock cycles.
    logic signed [31:0] te_x, te_y, te_z;          // registered t_min*rd
    logic signed [31:0] bw_c_ex, bw_c_ey, bw_c_ez;  // = ro + te_* (combinational add)
    // S_BRAM_WAIT field=6 combinational geometry (all from the entry point bw_c_e*).
    logic [6:0]         bw_c_icx, bw_c_icy, bw_c_icz;
    logic [5:0]         bw_c_cx,  bw_c_cy,  bw_c_cz;
    logic signed [31:0] bw_c_nhq;
    logic signed [31:0] bw_c_exrel, bw_c_eyrel, bw_c_ezrel;
    // S_BRAM_WAIT geometry is pipelined across bram_field 3->6; stage registers:
    logic [5:0]         bw_cx_r, bw_cy_r, bw_cz_r;            // stage 0: child cell within node
    logic signed [31:0] bw_exrel_r, bw_eyrel_r, bw_ezrel_r;  // stage 0: entry pt relative to node origin
    logic signed [31:0] bw_nhq_r;                            // stage 0: node_half in Q16.16
    logic signed [31:0] bw_distx_r, bw_disty_r, bw_distz_r;  // stage 1: dist to next midplane
    logic signed [31:0] bw_dtx_r,   bw_dty_r,   bw_dtz_r;    // stage 1: dt = node_half*|inv|
    logic signed [31:0] bw_prodx_r, bw_prody_r, bw_prodz_r;  // stage 2: dist*|inv|

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

    // S_RAY_SETUP stage counter: 0->13 (primary) or 0->4 (shadow).
    logic [3:0] rs_wait;
    // Sub-counter for multiply stages on the shared bank: at q_phase==0 the operands
    // are issued and q_phase set to QCOL; it counts down; at q_phase==1 (QCOL cycles
    // later) the product is collected and rs_wait advances. Non-multiply stages leave
    // q_phase at 0 and take a single cycle.
    logic [2:0] q_phase;

    // Set when S_POP_STACK redirects through S_ENTER_NODE to reload r_child[]/r_block[].
    // Suppresses the cx/cy/cz and t_next recomputation in S_BRAM_WAIT field=6.
    logic post_pop;

    // -------------------------------------------------------------------------
    // Shared multiplier bank. All traversal qmuls are issued onto these 3 lanes
    // by the FSM and collected QCOL cycles later.
    // -------------------------------------------------------------------------
    shared_qmul3 #(.LAT(3)) u_qmul (
        .clk(clk),
        .a0(q_a0), .b0(q_b0), .a1(q_a1), .b1(q_b1), .a2(q_a2), .b2(q_b2),
        .p0(q_p0), .p1(q_p1), .p2(q_p2)
    );

    // -------------------------------------------------------------------------
    // Entry-point add: P = ro + (t_min*rd). te_* is the registered product, so this is
    // only an add. t_min/ro/rd are stable across the whole BRAM read and at a hit, so
    // te_* (registered one cycle earlier) gives the correct entry point at field-7 and
    // at S_SOLID.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_ex = ro_x + te_x;
        bw_c_ey = ro_y + te_y;
        bw_c_ez = ro_z + te_z;
    end

    // -------------------------------------------------------------------------
    // S_BRAM_WAIT field=6 combinational geometry. Works from the entry point bw_c_e*;
    // node_half / node_origin_* / step_* / inv_* are stable across the read.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_nhq = $signed(32'(node_half)) << 16;
        // child cell index within this node, clamped on underflow/negative
        bw_c_icx = ($signed(bw_c_ex) < 0) ? 7'd0 : bw_c_ex[22:16];
        bw_c_icy = ($signed(bw_c_ey) < 0) ? 7'd0 : bw_c_ey[22:16];
        bw_c_icz = ($signed(bw_c_ez) < 0) ? 7'd0 : bw_c_ez[22:16];
        bw_c_icx = (bw_c_icx >= node_origin_x) ? bw_c_icx - node_origin_x : 7'd0;
        bw_c_icy = (bw_c_icy >= node_origin_y) ? bw_c_icy - node_origin_y : 7'd0;
        bw_c_icz = (bw_c_icz >= node_origin_z) ? bw_c_icz - node_origin_z : 7'd0;
        bw_c_cx  = (bw_c_icx >= node_half) ? 6'd1 : 6'd0;
        bw_c_cy  = (bw_c_icy >= node_half) ? 6'd1 : 6'd0;
        bw_c_cz  = (bw_c_icz >= node_half) ? 6'd1 : 6'd0;
        bw_c_exrel = bw_c_ex - ($signed(32'(node_origin_x)) << 16);
        bw_c_eyrel = bw_c_ey - ($signed(32'(node_origin_y)) << 16);
        bw_c_ezrel = bw_c_ez - ($signed(32'(node_origin_z)) << 16);
        // dist / dt / t_next are pipelined across bram_field 3->6 (see S_BRAM_WAIT).
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
            px <= '0; py <= '0; sp <= '0; rs_wait <= '0; post_pop <= '0; q_phase <= '0;
        end else begin
            // Force pulse signals low every cycle before state case
            fb_wr_en    <= '0;
            frame_done  <= '0;
            any_hit     <= '0;
            shade_start <= '0;
            axis_tvalid <= '0;
            // Register the entry-point multiply t_min*rd every cycle; consumers do the
            // +ro add combinationally next cycle.
            te_x <= qmul(t_min, rd_x);
            te_y <= qmul(t_min, rd_y);
            te_z <= qmul(t_min, rd_z);

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
            // S_RAY_SETUP: compute the normalised ray direction from pixel + camera.
            // Primary: 15 stages (rs_wait 0->14); shadow: 6 stages (0->5). The final
            // stage is a pure state transition with no compute (keeps its path short).
            // Both modes share the rs_xabs/r0/t1/r1/t2/sign registers for the N-R reciprocal.
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
                        // Newton-Raphson reciprocal inv = 1/dir (same as primary stages
                        // 10-13). Shadow rays skip normalization: the N-R runs directly on
                        // the already-unit forward vector loaded in stage 0.
                        4'd1: begin  // N-R pass 1: t1 = |x| * r0   (residual)
                            if (q_phase == 0) begin
                                q_a0 <= rs_xabs_x; q_b0 <= rs_r0_x;
                                q_a1 <= rs_xabs_y; q_b1 <= rs_r0_y;
                                q_a2 <= rs_xabs_z; q_b2 <= rs_r0_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_t1_x <= q_p0; rs_t1_y <= q_p1; rs_t1_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd2: begin  // N-R pass 1: r1 = r0 * (2 - t1)   (refined estimate)
                            if (q_phase == 0) begin
                                q_a0 <= rs_r0_x; q_b0 <= 32'sh0002_0000 - rs_t1_x;
                                q_a1 <= rs_r0_y; q_b1 <= 32'sh0002_0000 - rs_t1_y;
                                q_a2 <= rs_r0_z; q_b2 <= 32'sh0002_0000 - rs_t1_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_r1_x <= q_p0; rs_r1_y <= q_p1; rs_r1_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd3: begin  // N-R pass 2: t2 = |x| * r1   (residual)
                            if (q_phase == 0) begin
                                q_a0 <= rs_xabs_x; q_b0 <= rs_r1_x;
                                q_a1 <= rs_xabs_y; q_b1 <= rs_r1_y;
                                q_a2 <= rs_xabs_z; q_b2 <= rs_r1_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_t2_x <= q_p0; rs_t2_y <= q_p1; rs_t2_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd4: begin  // N-R pass 2: inv = sign(x) * r1 * (2 - t2); reset sp
                            if (q_phase == 0) begin
                                q_a0 <= rs_r1_x; q_b0 <= 32'sh0002_0000 - rs_t2_x;
                                q_a1 <= rs_r1_y; q_b1 <= 32'sh0002_0000 - rs_t2_y;
                                q_a2 <= rs_r1_z; q_b2 <= 32'sh0002_0000 - rs_t2_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                inv_x   <= rs_sign_x ? -q_p0 : q_p0;
                                inv_y   <= rs_sign_y ? -q_p1 : q_p1;
                                inv_z   <= rs_sign_z ? -q_p2 : q_p2;
                                sp      <= '0;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;  // -> 5
                            end else q_phase <= q_phase - 1'b1;
                        end
                        default: begin  // 4'd5 -- pure state transition, no computation
                            rs_wait <= '0;
                            state   <= S_ROOT_SLAB;
                        end
                    endcase
                end else begin
                    case (rs_wait)
                        // ---- Screen-space ray direction: raw_dir = fwd + u*right - v*up ----
                        // u,v are the pixel offset from screen centre scaled by cam_scale.
                        // Stage 0 forms u,v; stage 1 the six u*right / v*up products;
                        // stage 2 sums them into raw_dir; stage 3 squares raw_dir for len2.
                        4'd0: begin  // u = (px - IMG_W/2)*scale ; v = (py - IMG_H/2)*scale
                            if (q_phase == 0) begin
                                ro_x <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                                q_a0 <= $signed({1'b0, px, 16'd0}) - CENTER_X_Q; q_b0 <= cam_scale;
                                q_a1 <= $signed({1'b0, py, 16'd0}) - CENTER_Y_Q; q_b1 <= cam_scale;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rsu <= q_p0; rsv <= q_p1;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd1: begin  // six products over 2 issue cycles (6 muls > 3 lanes)
                            if (q_phase == 0) begin           // issue A: a/c/e = u * cam_right_{x,y,z}
                                q_a0 <= rsu; q_b0 <= cam_right_x;
                                q_a1 <= rsu; q_b1 <= cam_right_y;
                                q_a2 <= rsu; q_b2 <= cam_right_z;
                                q_phase <= 3'd5;
                            end else if (q_phase == 5) begin  // issue B: b/d/f = v * cam_up_{x,y,z}
                                q_a0 <= rsv; q_b0 <= cam_up_x;
                                q_a1 <= rsv; q_b1 <= cam_up_y;
                                q_a2 <= rsv; q_b2 <= cam_up_z;
                                q_phase <= 3'd4;
                            end else if (q_phase == 2) begin  // collect A (4 cycles after issue A)
                                rs_s1_a <= q_p0; rs_s1_c <= q_p1; rs_s1_e <= q_p2;
                                q_phase <= 3'd1;
                            end else if (q_phase == 1) begin  // collect B (4 cycles after issue B)
                                rs_s1_b <= q_p0; rs_s1_d <= q_p1; rs_s1_f <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;  // 4->3, 3->2
                        end
                        4'd2: begin  // raw_dir = fwd + u*right - v*up  (adds only)
                            rsdx    <= cam_fwd_x + rs_s1_a - rs_s1_b;
                            rsdy    <= cam_fwd_y + rs_s1_c - rs_s1_d;
                            rsdz    <= cam_fwd_z + rs_s1_e - rs_s1_f;
                            rs_wait <= rs_wait + 1'b1;
                        end
                        4'd3: begin  // dx2/dy2/dz2 = raw_dir^2  (-> len2)
                            if (q_phase == 0) begin
                                q_a0 <= rsdx; q_b0 <= rsdx;
                                q_a1 <= rsdy; q_b1 <= rsdy;
                                q_a2 <= rsdz; q_b2 <= rsdz;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_s3_dx2 <= q_p0; rs_s3_dy2 <= q_p1; rs_s3_dz2 <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd4: begin
                            rslen2   <= rs_s3_dx2 + rs_s3_dy2 + rs_s3_dz2;
                            rs_s4_y0 <= 32'sh0001_8000 - ((rs_s3_dx2 + rs_s3_dy2 + rs_s3_dz2) >>> 1);
                            rs_wait  <= rs_wait + 1'b1;
                        end
                        // ---- Fast inverse square root: inv_len = 1 / |raw_dir| ----
                        // One Newton-Raphson rsqrt step on len2 = |raw_dir|^2, with the
                        // linear seed y0 = 1.5 - len2/2 (valid since raw_dir ~ unit):
                        //     y0sq    = y0^2
                        //     r2y0sq  = len2 * y0^2
                        //     inv_len = y0 * (1.5 - r2y0sq/2)   -> ~1/sqrt(len2)
                        // Stage 8 then normalizes: nd = raw_dir * inv_len. 1.5 = 0001_8000.
                        4'd5: begin  // rsqrt: y0sq = y0^2
                            if (q_phase == 0) begin
                                q_a0 <= rs_s4_y0; q_b0 <= rs_s4_y0;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_s5_y0sq <= q_p0;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd6: begin  // rsqrt: r2y0sq = len2 * y0^2
                            if (q_phase == 0) begin
                                q_a0 <= rslen2; q_b0 <= rs_s5_y0sq;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_s6_r2y0sq <= q_p0;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd7: begin  // rsqrt: inv_len = y0 * (1.5 - r2y0sq/2)
                            if (q_phase == 0) begin
                                q_a0 <= rs_s4_y0; q_b0 <= 32'sh0001_8000 - (rs_s6_r2y0sq >>> 1);
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rsinv_len <= q_p0;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd8: begin  // normalize: nd = raw_dir * inv_len   (3 lanes)
                            if (q_phase == 0) begin
                                q_a0 <= rsdx; q_b0 <= rsinv_len;
                                q_a1 <= rsdy; q_b1 <= rsinv_len;
                                q_a2 <= rsdz; q_b2 <= rsinv_len;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rsndx <= q_p0; rsndy <= q_p1; rsndz <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
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
                        // ---- Newton-Raphson reciprocal: inv = 1 / normalized_dir ----
                        // Stages 10-13 refine the initial estimate r0 (~1/|x|, from
                        // recip_init) into the reciprocal via two N-R passes:
                        //     t  = |x| * r        (residual; -> 1.0 at convergence)
                        //     r' = r * (2 - t)    (next estimate; ~doubles correct bits)
                        // r0 --t1--> r1 --t2--> final; then the sign of x is applied.
                        // 2.0 = 0002_0000.
                        4'd10: begin  // N-R pass 1: t1 = |x| * r0   (residual)
                            if (q_phase == 0) begin
                                q_a0 <= rs_xabs_x; q_b0 <= rs_r0_x;
                                q_a1 <= rs_xabs_y; q_b1 <= rs_r0_y;
                                q_a2 <= rs_xabs_z; q_b2 <= rs_r0_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_t1_x <= q_p0; rs_t1_y <= q_p1; rs_t1_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd11: begin  // N-R pass 1: r1 = r0 * (2 - t1)   (refined estimate)
                            if (q_phase == 0) begin
                                q_a0 <= rs_r0_x; q_b0 <= 32'sh0002_0000 - rs_t1_x;
                                q_a1 <= rs_r0_y; q_b1 <= 32'sh0002_0000 - rs_t1_y;
                                q_a2 <= rs_r0_z; q_b2 <= 32'sh0002_0000 - rs_t1_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_r1_x <= q_p0; rs_r1_y <= q_p1; rs_r1_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd12: begin  // N-R pass 2: t2 = |x| * r1   (residual)
                            if (q_phase == 0) begin
                                q_a0 <= rs_xabs_x; q_b0 <= rs_r1_x;
                                q_a1 <= rs_xabs_y; q_b1 <= rs_r1_y;
                                q_a2 <= rs_xabs_z; q_b2 <= rs_r1_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                rs_t2_x <= q_p0; rs_t2_y <= q_p1; rs_t2_z <= q_p2;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;
                            end else q_phase <= q_phase - 1'b1;
                        end
                        4'd13: begin  // N-R pass 2: inv = sign(x) * r1 * (2 - t2); latch rd_*, reset sp
                            if (q_phase == 0) begin
                                q_a0 <= rs_r1_x; q_b0 <= 32'sh0002_0000 - rs_t2_x;
                                q_a1 <= rs_r1_y; q_b1 <= 32'sh0002_0000 - rs_t2_y;
                                q_a2 <= rs_r1_z; q_b2 <= 32'sh0002_0000 - rs_t2_z;
                                q_phase <= QCOL[2:0];
                            end else if (q_phase == 1) begin
                                inv_x   <= rs_sign_x ? -q_p0 : q_p0;
                                inv_y   <= rs_sign_y ? -q_p1 : q_p1;
                                inv_z   <= rs_sign_z ? -q_p2 : q_p2;
                                rd_x    <= rsndx;  rd_y <= rsndy;  rd_z <= rsndz;
                                sp      <= '0;
                                q_phase <= '0; rs_wait <= rs_wait + 1'b1;  // -> 14
                            end else q_phase <= q_phase - 1'b1;
                        end
                        default: begin  // 4'd14 -- pure state transition, no computation
                            rs_wait <= '0;
                            state   <= S_ROOT_SLAB;
                        end
                    endcase
                end
            end

            // -----------------------------------------------------------------
            // Ray-vs-world-box slab intersection, pipelined over rs_wait 0->8:
            //   0,1 = issue the 6 slab qmuls (3 lanes x 2 cycles)
            //   2,3 = bank pipeline fill (QCOL=4)
            //   4   = collect tx0/ty0/tz0 (issued at 0, ready at 0+QCOL)
            //   5   = collect tx1/ty1/tz1 (issued at 1, ready at 1+QCOL)
            //   6   = sort each pair (lo=min, hi=max)
            //   7   = t_enter=max(lo), t_exit=min(hi)
            //   8   = miss check + clamp t_min + set node + transition
            S_ROOT_SLAB: begin
                case (rs_wait)
                    // Issue tx0/ty0/tz0 = qmul(-ro, inv) on lanes x/y/z
                    4'd0: begin
                        q_a0 <= -ro_x;          q_b0 <= inv_x;
                        q_a1 <= -ro_y;          q_b1 <= inv_y;
                        q_a2 <= -ro_z;          q_b2 <= inv_z;
                        rs_wait <= rs_wait + 1'b1;
                    end
                    // Issue tx1/ty1/tz1 = qmul(WORLD_Q-ro, inv)
                    4'd1: begin
                        q_a0 <= WORLD_Q - ro_x; q_b0 <= inv_x;
                        q_a1 <= WORLD_Q - ro_y; q_b1 <= inv_y;
                        q_a2 <= WORLD_Q - ro_z; q_b2 <= inv_z;
                        rs_wait <= rs_wait + 1'b1;
                    end
                    4'd2: rs_wait <= rs_wait + 1'b1;   // bank fill
                    4'd3: rs_wait <= rs_wait + 1'b1;   // bank fill
                    // Collect issue-0 result (rs_wait 0 -> 0+QCOL)
                    4'd4: begin
                        rs_tx0_r <= q_p0; rs_ty0_r <= q_p1; rs_tz0_r <= q_p2;
                        rs_wait  <= rs_wait + 1'b1;
                    end
                    // Collect issue-1 result (rs_wait 1 -> 1+QCOL)
                    4'd5: begin
                        rs_tx1_r <= q_p0; rs_ty1_r <= q_p1; rs_tz1_r <= q_p2;
                        rs_wait  <= rs_wait + 1'b1;
                    end
                    // Sort each axis pair -> per-axis (lo=min, hi=max)
                    4'd6: begin
                        rs_lo_x <= (rs_tx0_r > rs_tx1_r) ? rs_tx1_r : rs_tx0_r;
                        rs_hi_x <= (rs_tx0_r > rs_tx1_r) ? rs_tx0_r : rs_tx1_r;
                        rs_lo_y <= (rs_ty0_r > rs_ty1_r) ? rs_ty1_r : rs_ty0_r;
                        rs_hi_y <= (rs_ty0_r > rs_ty1_r) ? rs_ty0_r : rs_ty1_r;
                        rs_lo_z <= (rs_tz0_r > rs_tz1_r) ? rs_tz1_r : rs_tz0_r;
                        rs_hi_z <= (rs_tz0_r > rs_tz1_r) ? rs_tz0_r : rs_tz1_r;
                        rs_wait <= rs_wait + 1'b1;
                    end
                    // t_enter = max(lo_x,lo_y,lo_z); t_exit = min(hi_x,hi_y,hi_z)
                    4'd7: begin
                        rs_enter_r <= (rs_lo_x > rs_lo_y) ? ((rs_lo_x > rs_lo_z) ? rs_lo_x : rs_lo_z)
                                                          : ((rs_lo_y > rs_lo_z) ? rs_lo_y : rs_lo_z);
                        rs_exit_r  <= (rs_hi_x < rs_hi_y) ? ((rs_hi_x < rs_hi_z) ? rs_hi_x : rs_hi_z)
                                                          : ((rs_hi_y < rs_hi_z) ? rs_hi_y : rs_hi_z);
                        rs_wait    <= rs_wait + 1'b1;
                    end
                    // Miss check (unclamped t_enter > t_exit) + clamp t_min; set node + state.
                    // Clamp t_min to 0: inside the world box t_enter<0; starting from t=0
                    // gives correct cx/cy/cz (t_next unaffected).
                    default: begin   // 4'd8
                        t_min <= ($signed(rs_enter_r) < 0) ? 32'sh0 : rs_enter_r;
                        t_max <= rs_exit_r;
                        if (rs_enter_r > rs_exit_r) begin
                            state <= S_MISS;
                        end else begin
                            node_idx      <= '0;
                            node_half     <= 6'(WORLD_SIZE >> 1);
                            node_origin_x <= '0; node_origin_y <= '0; node_origin_z <= '0;
                            state <= S_ENTER_NODE;
                        end
                        rs_wait <= '0;
                    end
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
                        // geometry stage 0: capture child cell + entry-rel + node_half.
                        // bw_c_e* and node_* are valid on this first cycle, so dt/prod can be
                        // issued at field 0/1 and the bank latency (QCOL=4) hides inside the
                        // 8-cycle read window.
                        bw_cx_r    <= bw_c_cx;    bw_cy_r    <= bw_c_cy;    bw_cz_r    <= bw_c_cz;
                        bw_exrel_r <= bw_c_exrel; bw_eyrel_r <= bw_c_eyrel; bw_ezrel_r <= bw_c_ezrel;
                        bw_nhq_r   <= bw_c_nhq;
                    end
                    3'd0: begin   // read word 0 = bitmask
                        r_bitmask <= svo_rd_data[15:0];
                        svo_rd_addr <= {node_idx[11:0], 3'd2};
                        bram_field  <= 3'd1;
                        // geometry stage 1: dist to next midplane (conditional, no qmul)
                        bw_distx_r <= (!step_x[2]) ? (bw_cx_r[0] ? ((bw_nhq_r<<<1)-bw_exrel_r) : (bw_nhq_r-bw_exrel_r))
                                                   : (bw_cx_r[0] ? (bw_exrel_r-bw_nhq_r) : bw_exrel_r);
                        bw_disty_r <= (!step_y[2]) ? (bw_cy_r[0] ? ((bw_nhq_r<<<1)-bw_eyrel_r) : (bw_nhq_r-bw_eyrel_r))
                                                   : (bw_cy_r[0] ? (bw_eyrel_r-bw_nhq_r) : bw_eyrel_r);
                        bw_distz_r <= (!step_z[2]) ? (bw_cz_r[0] ? ((bw_nhq_r<<<1)-bw_ezrel_r) : (bw_nhq_r-bw_ezrel_r))
                                                   : (bw_cz_r[0] ? (bw_ezrel_r-bw_nhq_r) : bw_ezrel_r);
                        // issue dt = node_half*|inv| onto the shared bank (collect @ field 4)
                        q_a0 <= bw_nhq_r; q_b0 <= qabs(inv_x);
                        q_a1 <= bw_nhq_r; q_b1 <= qabs(inv_y);
                        q_a2 <= bw_nhq_r; q_b2 <= qabs(inv_z);
                    end
                    3'd1: begin   // read word 1 = child ptrs 0-1
                        r_child[0]<=svo_rd_data[15:0]; r_child[1]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[11:0], 3'd3};
                        bram_field  <= 3'd2;
                        // issue prod = dist*|inv| onto the shared bank (collect @ field 5)
                        q_a0 <= bw_distx_r; q_b0 <= qabs(inv_x);
                        q_a1 <= bw_disty_r; q_b1 <= qabs(inv_y);
                        q_a2 <= bw_distz_r; q_b2 <= qabs(inv_z);
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
                        // collect dt from the shared bank (issued @ field 0, QCOL=4)
                        bw_dtx_r <= q_p0; bw_dty_r <= q_p1; bw_dtz_r <= q_p2;
                    end
                    3'd5: begin   // read word 5 = block IDs 0-3; word-6 addr already issued
                        r_block[0]<=svo_rd_data[7:0];   r_block[1]<=svo_rd_data[15:8];
                        r_block[2]<=svo_rd_data[23:16]; r_block[3]<=svo_rd_data[31:24];
                        svo_rd_en  <= '0;
                        bram_field <= 3'd6;
                        // collect prod from the shared bank (issued @ field 1, QCOL=4)
                        bw_prodx_r <= q_p0; bw_prody_r <= q_p1; bw_prodz_r <= q_p2;
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
                    // dt from the pipelined qmul; correct in both fresh-descend and
                    // post-pop cases (bw_nhq_r captured the restored node_half).
                    dt_x <= bw_dtx_r; dt_y <= bw_dty_r; dt_z <= bw_dtz_r;
                    if (post_pop) begin
                        // r_child[]/r_block[] now hold the parent node's data. cx/cy/cz and
                        // t_next were restored by S_POP_STACK; only dt is taken from here.
                        post_pop <= 1'b0;
                        state    <= S_EMPTY;
                    end else begin
                        cx       <= bw_cx_r; cy <= bw_cy_r; cz <= bw_cz_r;
                        t_next_x <= t_min + bw_prodx_r;   // geometry stage 3: t_min + dist*|inv|
                        t_next_y <= t_min + bw_prody_r;
                        t_next_z <= t_min + bw_prodz_r;
                        state    <= S_CHECK_CHILD;
                    end
                end
            end

            // -----------------------------------------------------------------
            S_CHECK_CHILD: begin
                cidx <= {cz[0], cy[0], cx[0]};
                unique case (2'((r_bitmask >> ({cz[0],cy[0],cx[0]} * 2)) & 16'h0003))
                    2'b00:   state <= S_EMPTY;
                    2'b11:   state <= S_SOLID;
                    // Depth cap: a MIXED child at/under the cap is a coarse occluder
                    // (shadow mode -> S_SOLID = hit). max_depth=15 disables the cap.
                    2'b01:   state <= (sp >= max_depth) ? S_SOLID : S_MIXED;
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
                // Hit point = entry point at the current t_min.
                hit_px_r     <= bw_c_ex;
                hit_py_r     <= bw_c_ey;
                hit_pz_r     <= bw_c_ez;
                if (SHADOW_MODE) begin
                    // shadow: signal hit and stop
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
                    shade_hit_px        <= bw_c_ex;   // ro + te_*
                    shade_hit_py        <= bw_c_ey;
                    shade_hit_pz        <= bw_c_ez;
                    shade_start         <= 1'b1;
                    state               <= S_WAIT_SHADE;
                end else begin
                    // Phase 1: white hit
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
                    // dt is recomputed in S_BRAM_WAIT field=6 from the restored node_half.
                    cx            <= stk_cx       [sp-1];
                    cy            <= stk_cy       [sp-1];
                    cz            <= stk_cz       [sp-1];
                    node_half     <= stk_node_half[sp-1];
                    node_origin_x <= stk_orig_x   [sp-1];
                    node_origin_y <= stk_orig_y   [sp-1];
                    node_origin_z <= stk_orig_z   [sp-1];
                    // Re-read BRAM to recover r_child[]/r_block[] for the restored parent.
                    // post_pop keeps the stack-restored DDA state in S_BRAM_WAIT field=6.
                    post_pop <= 1'b1;
                    state <= S_ENTER_NODE;
                end
            end

            // -----------------------------------------------------------------
            // Ray exited the world box without a hit.
            S_MISS: begin
                if (SHADOW_MODE) begin
                    // no occluder: report done with any_hit low
                    frame_done <= 1'b1;
                    state      <= S_IDLE;
                end else if (SHADE_MODE) begin
                    shade_is_miss  <= 1'b1;
                    shade_start    <= 1'b1;
                    state          <= S_WAIT_SHADE;
                end else begin
                    // Phase 1: sky colour
                    pixel_color <= sky_color;
                    state       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            // Stall until the shading pipeline returns the pixel colour.
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
                axis_tlast  <= (px == 9'(IMG_W - 1));        // last pixel of the line
                axis_tuser  <= (px == '0 && py == '0) ? 1'b1 : 1'b0;  // SOF on first pixel
                if (axis_tready)
                    state <= S_NEXT_PIXEL;
                // else: hold tvalid until tready (AXI-Stream rule)
            end

            // -----------------------------------------------------------------
            S_NEXT_PIXEL: begin
                axis_tvalid <= 1'b0;
                sp          <= '0;
                post_pop    <= 1'b0;
                if (px == 9'(IMG_W - 1)) begin   // end of line
                    px <= '0;
                    if (py == 8'(IMG_H - 1)) begin   // end of frame
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
