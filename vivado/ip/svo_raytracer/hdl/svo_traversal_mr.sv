// svo_traversal_mr.sv
// Multi-ray latency-hiding SVO DDA traversal core (M1). Derived from svo_traversal.sv.
// At RAY_POOL_N=1 this is bit-identical to single-ray svo_traversal (primary mode).
// RAY_POOL_N>1 will interleave a pool of rays over one shared datapath (added in
// later M1 tasks). THIS revision is a pure rename (+unused RAY_POOL_N param) so the
// Phase-1 harness swap can be gated bit-identical before any slot-indexing. The
// shadow-mode branches are retained as dead code (SHADOW_MODE=0 in every instance);
// they are removed when per-slot state is introduced.
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
module svo_traversal_mr #(
    parameter int RAY_POOL_N  = 1,   // M1: 1 = single-ray (bit-identical); >1 = interleaved pool (unused this revision)
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


    // (The old all-in-one qrecip() Newton-Raphson reciprocal has been removed: the
    // two N-R iterations are now pipelined through the shared bank across S_RAY_SETUP
    // stages 10-13 (shadow 1-4), seeded by recip_init() below.)

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

    (* fsm_encoding = "sequential" *) state_t state [0:RAY_POOL_N-1];

    // Current ray slot being advanced this cycle. M1 step: tied to 0 (single
    // ray / bit-identical). The round-robin scheduler that drives this for
    // RAY_POOL_N>1 is added in a later step.
    localparam int SLOT_W = (RAY_POOL_N > 1) ? $clog2(RAY_POOL_N) : 1;
    logic [SLOT_W-1:0] cur_slot;
    assign cur_slot = '0;
    // World box upper boundary in Q16.16 (WORLD_SIZE.0). Used by S_ROOT_SLAB.
    localparam logic signed [31:0] WORLD_Q = WORLD_SIZE << 16;
    // Screen-centre in Q16.16: (IMG_W/2, IMG_H/2). (IMG/2)<<16 == IMG<<15.
    // Derived from the resolution params so a lower-res build (e.g. -GIMG_W=64
    // for the fast sim crop) stays centred. At 320x240 these equal the old
    // hardcoded 32'sh00A0_0000 / 32'sh0078_0000 exactly.
    localparam logic signed [31:0] CENTER_X_Q = $signed(32'(IMG_W) << 15);
    localparam logic signed [31:0] CENTER_Y_Q = $signed(32'(IMG_H) << 15);
    logic [3:0] state_raw; assign state_raw = state[cur_slot];
    assign dbg_state   = state_raw;
    assign dbg_rs_wait = rs_wait[cur_slot];
    assign dbg_px      = px[cur_slot];
    assign dbg_py      = py[cur_slot];
    assign dbg_tvalid  = axis_tvalid;
    assign dbg_tready  = axis_tready;

    // -------------------------------------------------------------------------
    // Pixel counters (primary-ray mode only)
    // -------------------------------------------------------------------------
    logic [8:0] px [0:RAY_POOL_N-1];
    logic [7:0] py [0:RAY_POOL_N-1];

    // -------------------------------------------------------------------------
    // Ray registers (Q16.16)
    // -------------------------------------------------------------------------
    logic signed [31:0] ro_x [0:RAY_POOL_N-1], ro_y [0:RAY_POOL_N-1], ro_z [0:RAY_POOL_N-1];
    logic signed [31:0] rd_x [0:RAY_POOL_N-1], rd_y [0:RAY_POOL_N-1], rd_z [0:RAY_POOL_N-1];
    logic signed [31:0] inv_x [0:RAY_POOL_N-1], inv_y [0:RAY_POOL_N-1], inv_z [0:RAY_POOL_N-1];

    // -------------------------------------------------------------------------
    // DDA registers
    // -------------------------------------------------------------------------
    logic signed [31:0] t_min [0:RAY_POOL_N-1], t_max [0:RAY_POOL_N-1];
    logic signed [31:0] t_next_x [0:RAY_POOL_N-1], t_next_y [0:RAY_POOL_N-1], t_next_z [0:RAY_POOL_N-1];
    logic signed [31:0] dt_x [0:RAY_POOL_N-1], dt_y [0:RAY_POOL_N-1], dt_z [0:RAY_POOL_N-1];
    logic signed [2:0]  step_x [0:RAY_POOL_N-1], step_y [0:RAY_POOL_N-1], step_z [0:RAY_POOL_N-1];
    logic [5:0] cx [0:RAY_POOL_N-1], cy [0:RAY_POOL_N-1], cz [0:RAY_POOL_N-1];
    logic [5:0] node_half [0:RAY_POOL_N-1];
    logic [5:0] node_origin_x [0:RAY_POOL_N-1], node_origin_y [0:RAY_POOL_N-1], node_origin_z [0:RAY_POOL_N-1];

    // S_ROOT_SLAB is pipelined across rs_wait 0->3; these are its stage registers.
    logic signed [31:0] rs_tx0_r [0:RAY_POOL_N-1], rs_tx1_r [0:RAY_POOL_N-1], rs_ty0_r [0:RAY_POOL_N-1], rs_ty1_r [0:RAY_POOL_N-1], rs_tz0_r [0:RAY_POOL_N-1], rs_tz1_r [0:RAY_POOL_N-1]; // stage 0: registered slab times
    logic signed [31:0] rs_lo_x [0:RAY_POOL_N-1], rs_hi_x [0:RAY_POOL_N-1], rs_lo_y [0:RAY_POOL_N-1], rs_hi_y [0:RAY_POOL_N-1], rs_lo_z [0:RAY_POOL_N-1], rs_hi_z [0:RAY_POOL_N-1];        // stage 1: sorted per-axis min/max
    logic signed [31:0] rs_enter_r [0:RAY_POOL_N-1], rs_exit_r [0:RAY_POOL_N-1];                                       // stage 2: t_enter / t_exit

    // Combinational scratch temps (written and read within the same cycle for
    // the current slot) -- left single (SHARED).
    logic [1:0]         em_face;
    logic               em_fsign;
    logic signed [31:0] rsu [0:RAY_POOL_N-1], rsv [0:RAY_POOL_N-1], rsdx [0:RAY_POOL_N-1], rsdy [0:RAY_POOL_N-1], rsdz [0:RAY_POOL_N-1], rslen2 [0:RAY_POOL_N-1], rsinv_len [0:RAY_POOL_N-1], rsndx [0:RAY_POOL_N-1], rsndy [0:RAY_POOL_N-1], rsndz [0:RAY_POOL_N-1];

    // S_RAY_SETUP pipeline stage registers (primary stages 0-13; shadow stages 0-4).
    // Named by the stage that WRITES them. Registers hold their value until overwritten,
    // so later stages can read earlier outputs without explicit delay registers.
    logic signed [31:0] rs_s1_a [0:RAY_POOL_N-1], rs_s1_b [0:RAY_POOL_N-1];          // stage 1: qmul(rsu, cam_right_x), qmul(rsv, cam_up_x)
    logic signed [31:0] rs_s1_c [0:RAY_POOL_N-1], rs_s1_d [0:RAY_POOL_N-1];          // stage 1: ... for Y
    logic signed [31:0] rs_s1_e [0:RAY_POOL_N-1], rs_s1_f [0:RAY_POOL_N-1];          // stage 1: ... for Z
    logic signed [31:0] rs_s3_dx2 [0:RAY_POOL_N-1], rs_s3_dy2 [0:RAY_POOL_N-1], rs_s3_dz2 [0:RAY_POOL_N-1];  // stage 3: rsd*^2
    logic signed [31:0] rs_s4_y0 [0:RAY_POOL_N-1];                   // stage 4: 1.5 - rslen2/2 (NR seed for 1/sqrt(len))
    logic signed [31:0] rs_s5_y0sq [0:RAY_POOL_N-1];                 // stage 5: y0^2
    logic signed [31:0] rs_s6_r2y0sq [0:RAY_POOL_N-1];               // stage 6: rslen2 x y0^2
    // Shared reciprocal-N-R registers -- primary uses these at stages 9-13; shadow at 0-4.
    logic signed [31:0] rs_xabs_x [0:RAY_POOL_N-1], rs_xabs_y [0:RAY_POOL_N-1], rs_xabs_z [0:RAY_POOL_N-1];  // |rd_*|
    logic signed [31:0] rs_r0_x   [0:RAY_POOL_N-1], rs_r0_y   [0:RAY_POOL_N-1], rs_r0_z   [0:RAY_POOL_N-1];    // initial N-R estimates
    logic signed [31:0] rs_t1_x   [0:RAY_POOL_N-1], rs_t1_y   [0:RAY_POOL_N-1], rs_t1_z   [0:RAY_POOL_N-1];    // N-R iteration 1 multiply
    logic signed [31:0] rs_r1_x   [0:RAY_POOL_N-1], rs_r1_y   [0:RAY_POOL_N-1], rs_r1_z   [0:RAY_POOL_N-1];    // N-R iteration 1 result
    logic signed [31:0] rs_t2_x   [0:RAY_POOL_N-1], rs_t2_y   [0:RAY_POOL_N-1], rs_t2_z   [0:RAY_POOL_N-1];    // N-R iteration 2 multiply
    logic               rs_sign_x [0:RAY_POOL_N-1], rs_sign_y [0:RAY_POOL_N-1], rs_sign_z [0:RAY_POOL_N-1];   // sign of final rd_* component

    // Combinational outputs of every qmul in S_RAY_SETUP.
    // Keeping qmul in always_comb forces DSP CE='1' (always enabled), which
    // eliminates unconstrained DSP ACOUT paths.  The always_ff stages below
    // capture these signals into the pipeline registers at the correct rs_wait
    // stage; the DSPs themselves run every cycle but cause no timing hazard.
    // All S_RAY_SETUP qmuls (ray-dir front rsu/rsv/s1/dx2, rsqrt/normalize y0sq/r2y0sq/
    // inv_len/nd, and the N-R reciprocal t1/r1/t2/inv) are issued onto the shared
    // multiplier bank directly from the FSM, so no dedicated rs_c_* qmul nets remain.
    // S_ROOT_SLAB: ray-vs-world-box slab intersection times (CE='1' on all DSPs)
    // Shared 3-lane multiplier bank (DSP reduction). The FSM registers operands
    // into q_a*/q_b* in the issue stage; products are valid QCOL = 4 cycles later
    // (shared_qmul3 latency 3 + the operand register). Traversal qmuls migrate to
    // this bank cluster by cluster; the first user is S_ROOT_SLAB (slab times).
    localparam int QCOL = 4;
    logic signed [31:0] q_a0, q_b0, q_a1, q_b1, q_a2, q_b2;
    logic signed [31:0] q_p0, q_p1, q_p2;
    // Entry point P = ro + t_min*rd (Q16.16). The multiply t_min*rd is registered into
    // te_* so it lands in its own clock cycle; the +ro add is then combinational and
    // happens in the consuming cycle (geometry capture / solid hit). This splits the old
    // single-cycle multiply+wide-add path (which failed timing) into two short stages.
    logic signed [31:0] te_x [0:RAY_POOL_N-1], te_y [0:RAY_POOL_N-1], te_z [0:RAY_POOL_N-1];          // registered t_min*rd (one DSP cycle)
    logic signed [31:0] bw_c_ex, bw_c_ey, bw_c_ez;  // = ro + te_* (combinational add)
    // S_BRAM_WAIT field=6 combinational geometry (all from the entry point bw_c_e*).
    logic [6:0]         bw_c_icx, bw_c_icy, bw_c_icz;
    logic [5:0]         bw_c_cx,  bw_c_cy,  bw_c_cz;
    logic signed [31:0] bw_c_nhq;
    logic signed [31:0] bw_c_exrel, bw_c_eyrel, bw_c_ezrel;
    // S_BRAM_WAIT geometry is pipelined across bram_field 3->6; stage registers:
    logic [5:0]         bw_cx_r [0:RAY_POOL_N-1], bw_cy_r [0:RAY_POOL_N-1], bw_cz_r [0:RAY_POOL_N-1];            // stage 0: child cell within node
    logic signed [31:0] bw_exrel_r [0:RAY_POOL_N-1], bw_eyrel_r [0:RAY_POOL_N-1], bw_ezrel_r [0:RAY_POOL_N-1];  // stage 0: entry pt relative to node origin
    logic signed [31:0] bw_nhq_r [0:RAY_POOL_N-1];                            // stage 0: node_half in Q16.16
    logic signed [31:0] bw_distx_r [0:RAY_POOL_N-1], bw_disty_r [0:RAY_POOL_N-1], bw_distz_r [0:RAY_POOL_N-1];  // stage 1: dist to next midplane
    logic signed [31:0] bw_dtx_r   [0:RAY_POOL_N-1], bw_dty_r   [0:RAY_POOL_N-1], bw_dtz_r   [0:RAY_POOL_N-1];    // stage 1: dt = node_half*|inv|
    logic signed [31:0] bw_prodx_r [0:RAY_POOL_N-1], bw_prody_r [0:RAY_POOL_N-1], bw_prodz_r [0:RAY_POOL_N-1];  // stage 2: dist*|inv|

    // -------------------------------------------------------------------------
    // SVO node registers
    // -------------------------------------------------------------------------
    logic [15:0] node_idx [0:RAY_POOL_N-1];
    logic [15:0] bitmask [0:RAY_POOL_N-1];
    logic [2:0]  cidx [0:RAY_POOL_N-1];
    logic [15:0] r_child [0:RAY_POOL_N-1][0:7];
    logic [7:0]  r_block [0:RAY_POOL_N-1][0:7];
    logic [15:0] r_bitmask [0:RAY_POOL_N-1];
    logic [2:0]  bram_field [0:RAY_POOL_N-1];

    // Hit info
    logic [7:0]  block_id_hit [0:RAY_POOL_N-1];
    logic signed [31:0] t_hit [0:RAY_POOL_N-1];
    logic [1:0]  hit_face [0:RAY_POOL_N-1];
    logic        hit_face_sign_r [0:RAY_POOL_N-1];
    logic signed [31:0] hit_px_r [0:RAY_POOL_N-1], hit_py_r [0:RAY_POOL_N-1], hit_pz_r [0:RAY_POOL_N-1];

    // -------------------------------------------------------------------------
    // Stack
    // -------------------------------------------------------------------------
    logic [3:0]  sp [0:RAY_POOL_N-1];
    logic [15:0] stk_node_idx    [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [15:0] stk_bitmask     [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_min      [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_max      [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_x   [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_y   [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic signed [31:0] stk_t_next_z   [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_cx          [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_cy          [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_cz          [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_node_half   [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_x      [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_y      [0:RAY_POOL_N-1][0:STACK_DEPTH-1];
    logic [5:0]  stk_orig_z      [0:RAY_POOL_N-1][0:STACK_DEPTH-1];

    logic [23:0] pixel_color [0:RAY_POOL_N-1];

    // Stage counter for S_RAY_SETUP pipeline: advances 0->13 (primary mode) or 0->4 (shadow mode).
    logic [3:0] rs_wait [0:RAY_POOL_N-1];
    // Sub-counter for multiply stages routed through the shared bank: on entry to such
    // a stage (q_phase==0) the operands are issued, q_phase is set to QCOL, then it counts
    // down; at q_phase==1 (QCOL cycles after issue) the product is collected and rs_wait
    // advances. Non-multiply stages leave q_phase at 0 and advance in a single cycle.
    logic [2:0] q_phase [0:RAY_POOL_N-1];

    // Set when S_POP_STACK redirects through S_ENTER_NODE to reload r_child[]/r_block[].
    // Suppresses the cx/cy/cz and t_next recomputation in S_BRAM_WAIT field=6.
    logic post_pop [0:RAY_POOL_N-1];

    // -------------------------------------------------------------------------
    // S_RAY_SETUP: every multiply is now issued onto the shared multiplier bank
    // directly from the FSM (q_a*/q_b* -> q_p*), so there are no dedicated qmul
    // always_comb blocks left here. The pipeline runs entirely on the 3-lane bank:
    //   stages 0-3  ray-dir front (u/v, u*right + v*up, raw_dir^2)
    //   stages 5-8  fast inverse sqrt + normalize (y0sq, r2y0sq, inv_len, nd)
    //   stages 10-13 (shadow 1-4) Newton-Raphson reciprocal (t1, r1, t2, inv)
    // Adds, sign bits, subtracts and clamps stay combinational in front of the FFs.
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Shared multiplier bank. The slab times (and, as later clusters migrate,
    // the rest of the traversal's qmuls) are issued onto these 3 lanes by the
    // FSM and collected QCOL cycles later. The slab is the first user (S_ROOT_SLAB).
    // -------------------------------------------------------------------------
    shared_qmul3 #(.LAT(3)) u_qmul (
        .clk(clk),
        .a0(q_a0), .b0(q_b0), .a1(q_a1), .b1(q_b1), .a2(q_a2), .b2(q_b2),
        .p0(q_p0), .p1(q_p1), .p2(q_p2)
    );

    // -------------------------------------------------------------------------
    // Entry-point add (CE='1'): P = ro + (t_min*rd).  te_* is the registered product,
    // so this is only an add — the multiply already happened the previous cycle. t_min,
    // ro_*, rd_* are stable across the whole 8-cycle BRAM read and at a solid hit, so
    // te_* (registered one cycle earlier) yields the correct entry point at field-7 and
    // at S_SOLID.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_ex = ro_x[cur_slot] + te_x[cur_slot];
        bw_c_ey = ro_y[cur_slot] + te_y[cur_slot];
        bw_c_ez = ro_z[cur_slot] + te_z[cur_slot];
    end

    // -------------------------------------------------------------------------
    // S_BRAM_WAIT field=6 combinational geometry (CE='1' on all DSPs).
    // Reads the entry point bw_c_e* (= ro + registered te_*); the multiply is not in
    // this path. node_half / node_origin_* / step_* / inv_* are stable across the read.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_nhq = $signed(32'(node_half[cur_slot])) << 16;
        // child cell index within this node, clamped on underflow/negative
        bw_c_icx = ($signed(bw_c_ex) < 0) ? 7'd0 : bw_c_ex[22:16];
        bw_c_icy = ($signed(bw_c_ey) < 0) ? 7'd0 : bw_c_ey[22:16];
        bw_c_icz = ($signed(bw_c_ez) < 0) ? 7'd0 : bw_c_ez[22:16];
        bw_c_icx = (bw_c_icx >= node_origin_x[cur_slot]) ? bw_c_icx - node_origin_x[cur_slot] : 7'd0;
        bw_c_icy = (bw_c_icy >= node_origin_y[cur_slot]) ? bw_c_icy - node_origin_y[cur_slot] : 7'd0;
        bw_c_icz = (bw_c_icz >= node_origin_z[cur_slot]) ? bw_c_icz - node_origin_z[cur_slot] : 7'd0;
        bw_c_cx  = (bw_c_icx >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_cy  = (bw_c_icy >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_cz  = (bw_c_icz >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_exrel = bw_c_ex - ($signed(32'(node_origin_x[cur_slot])) << 16);
        bw_c_eyrel = bw_c_ey - ($signed(32'(node_origin_y[cur_slot])) << 16);
        bw_c_ezrel = bw_c_ez - ($signed(32'(node_origin_z[cur_slot])) << 16);
        // dist / dt / t_next are pipelined across bram_field 3->6 (see S_BRAM_WAIT).
    end

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
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
            for (int s = 0; s < RAY_POOL_N; s++) begin
                state[s] <= S_IDLE; px[s] <= '0; py[s] <= '0; sp[s] <= '0;
                rs_wait[s] <= '0; post_pop[s] <= '0; q_phase[s] <= '0;
            end
        end else begin
            // Force pulse signals low every cycle before state case
            fb_wr_en    <= '0;
            frame_done  <= '0;
            any_hit     <= '0;
            shade_start <= '0;
            axis_tvalid <= '0;
            // Register the entry-point multiply t_min*rd every cycle (the +ro add is
            // done combinationally by consumers next cycle). Splits the multiply and the
            // add into separate clock cycles so neither path exceeds the 10 ns budget.
            te_x[cur_slot] <= qmul(t_min[cur_slot], rd_x[cur_slot]);
            te_y[cur_slot] <= qmul(t_min[cur_slot], rd_y[cur_slot]);
            te_z[cur_slot] <= qmul(t_min[cur_slot], rd_z[cur_slot]);

            unique case (state[cur_slot])

            // -----------------------------------------------------------------
            S_IDLE: begin
                busy <= '0;
                if (start) begin
                    busy    <= 1'b1;
                    px[cur_slot]      <= '0;
                    py[cur_slot]      <= '0;
                    sp[cur_slot]      <= '0;
                    rs_wait[cur_slot] <= '0;
                    state[cur_slot]   <= S_RAY_SETUP;
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
            // Both modes share rs_xabs/r0/t1/r1/t2/sign registers for the reciprocal N-R.
            S_RAY_SETUP: begin
                if (SHADOW_MODE) begin
                    case (rs_wait[cur_slot])
                        4'd0: begin
                            ro_x[cur_slot]      <= cam_pos_x; ro_y[cur_slot] <= cam_pos_y; ro_z[cur_slot] <= cam_pos_z;
                            rd_x[cur_slot]      <= cam_fwd_x; rd_y[cur_slot] <= cam_fwd_y; rd_z[cur_slot] <= cam_fwd_z;
                            step_x[cur_slot]    <= cam_fwd_x[31] ? -3'sd1 : 3'sd1;
                            step_y[cur_slot]    <= cam_fwd_y[31] ? -3'sd1 : 3'sd1;
                            step_z[cur_slot]    <= cam_fwd_z[31] ? -3'sd1 : 3'sd1;
                            rs_sign_x[cur_slot] <= cam_fwd_x[31]; rs_sign_y[cur_slot] <= cam_fwd_y[31]; rs_sign_z[cur_slot] <= cam_fwd_z[31];
                            rs_xabs_x[cur_slot] <= qabs(cam_fwd_x); rs_xabs_y[cur_slot] <= qabs(cam_fwd_y); rs_xabs_z[cur_slot] <= qabs(cam_fwd_z);
                            rs_r0_x[cur_slot]   <= recip_init(cam_fwd_x);
                            rs_r0_y[cur_slot]   <= recip_init(cam_fwd_y);
                            rs_r0_z[cur_slot]   <= recip_init(cam_fwd_z);
                            rs_wait[cur_slot]   <= rs_wait[cur_slot] + 1'b1;
                        end
                        // Newton-Raphson reciprocal inv = 1/dir (same algorithm as the
                        // primary-mode stages 10-13 below; see the block comment there).
                        // Shadow rays skip normalization, so the N-R runs directly on the
                        // (already-unit) forward vector loaded in stage 0.
                        4'd1: begin  // N-R pass 1: t1 = |x| * r0   (residual)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r0_x[cur_slot];
                                q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r0_y[cur_slot];
                                q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r0_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_t1_x[cur_slot] <= q_p0; rs_t1_y[cur_slot] <= q_p1; rs_t1_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd2: begin  // N-R pass 1: r1 = r0 * (2 - t1)   (refined estimate)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_r0_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t1_x[cur_slot];
                                q_a1 <= rs_r0_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t1_y[cur_slot];
                                q_a2 <= rs_r0_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t1_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_r1_x[cur_slot] <= q_p0; rs_r1_y[cur_slot] <= q_p1; rs_r1_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd3: begin  // N-R pass 2: t2 = |x| * r1   (residual)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r1_x[cur_slot];
                                q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r1_y[cur_slot];
                                q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r1_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_t2_x[cur_slot] <= q_p0; rs_t2_y[cur_slot] <= q_p1; rs_t2_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd4: begin  // N-R pass 2: inv = sign(x) * r1 * (2 - t2); reset sp
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_r1_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t2_x[cur_slot];
                                q_a1 <= rs_r1_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t2_y[cur_slot];
                                q_a2 <= rs_r1_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t2_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                inv_x[cur_slot]   <= rs_sign_x[cur_slot] ? -q_p0 : q_p0;
                                inv_y[cur_slot]   <= rs_sign_y[cur_slot] ? -q_p1 : q_p1;
                                inv_z[cur_slot]   <= rs_sign_z[cur_slot] ? -q_p2 : q_p2;
                                sp[cur_slot]      <= '0;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;  // -> 5
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        default: begin  // 4'd5 -- pure state transition, no computation
                            rs_wait[cur_slot] <= '0;
                            state[cur_slot]   <= S_ROOT_SLAB;
                        end
                    endcase
                end else begin
                    // Primary mode: 14-stage pipeline
                    case (rs_wait[cur_slot])
                        // ---- Screen-space ray direction: raw_dir = fwd + u*right - v*up ----
                        // u,v are the pixel's offset from screen centre scaled by cam_scale
                        // (u = (px - IMG_W/2)*scale, v = (py - IMG_H/2)*scale; the centre
                        // CENTER_X_Q/CENTER_Y_Q is derived from the resolution params).
                        // Stage 0 forms u,v; stage 1 forms the six u*right / v*up products;
                        // stage 2 sums them into raw_dir; stage 3 squares raw_dir for len2.
                        // All multiplies use the shared bank.
                        4'd0: begin  // u = (px - IMG_W/2)*scale ; v = (py - IMG_H/2)*scale
                            if (q_phase[cur_slot] == 0) begin
                                ro_x[cur_slot] <= cam_pos_x; ro_y[cur_slot] <= cam_pos_y; ro_z[cur_slot] <= cam_pos_z;
                                q_a0 <= $signed({1'b0, px[cur_slot], 16'd0}) - CENTER_X_Q; q_b0 <= cam_scale;
                                q_a1 <= $signed({1'b0, py[cur_slot], 16'd0}) - CENTER_Y_Q; q_b1 <= cam_scale;
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rsu[cur_slot] <= q_p0; rsv[cur_slot] <= q_p1;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd1: begin  // six products over 2 issue cycles (6 muls > 3 lanes)
                            if (q_phase[cur_slot] == 0) begin           // issue A: a/c/e = u * cam_right_{x,y,z}
                                q_a0 <= rsu[cur_slot]; q_b0 <= cam_right_x;
                                q_a1 <= rsu[cur_slot]; q_b1 <= cam_right_y;
                                q_a2 <= rsu[cur_slot]; q_b2 <= cam_right_z;
                                q_phase[cur_slot] <= 3'd5;
                            end else if (q_phase[cur_slot] == 5) begin  // issue B: b/d/f = v * cam_up_{x,y,z}
                                q_a0 <= rsv[cur_slot]; q_b0 <= cam_up_x;
                                q_a1 <= rsv[cur_slot]; q_b1 <= cam_up_y;
                                q_a2 <= rsv[cur_slot]; q_b2 <= cam_up_z;
                                q_phase[cur_slot] <= 3'd4;
                            end else if (q_phase[cur_slot] == 2) begin  // collect A (4 cycles after issue A)
                                rs_s1_a[cur_slot] <= q_p0; rs_s1_c[cur_slot] <= q_p1; rs_s1_e[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= 3'd1;
                            end else if (q_phase[cur_slot] == 1) begin  // collect B (4 cycles after issue B)
                                rs_s1_b[cur_slot] <= q_p0; rs_s1_d[cur_slot] <= q_p1; rs_s1_f[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;  // 4->3, 3->2
                        end
                        4'd2: begin  // raw_dir = fwd + u*right - v*up  (adds only)
                            rsdx[cur_slot]    <= cam_fwd_x + rs_s1_a[cur_slot] - rs_s1_b[cur_slot];
                            rsdy[cur_slot]    <= cam_fwd_y + rs_s1_c[cur_slot] - rs_s1_d[cur_slot];
                            rsdz[cur_slot]    <= cam_fwd_z + rs_s1_e[cur_slot] - rs_s1_f[cur_slot];
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd3: begin  // dx2/dy2/dz2 = raw_dir^2  (-> len2)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rsdx[cur_slot]; q_b0 <= rsdx[cur_slot];
                                q_a1 <= rsdy[cur_slot]; q_b1 <= rsdy[cur_slot];
                                q_a2 <= rsdz[cur_slot]; q_b2 <= rsdz[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_s3_dx2[cur_slot] <= q_p0; rs_s3_dy2[cur_slot] <= q_p1; rs_s3_dz2[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd4: begin
                            rslen2[cur_slot]   <= rs_s3_dx2[cur_slot] + rs_s3_dy2[cur_slot] + rs_s3_dz2[cur_slot];
                            rs_s4_y0[cur_slot] <= 32'sh0001_8000 - ((rs_s3_dx2[cur_slot] + rs_s3_dy2[cur_slot] + rs_s3_dz2[cur_slot]) >>> 1);
                            rs_wait[cur_slot]  <= rs_wait[cur_slot] + 1'b1;
                        end
                        // ---- Fast inverse square root: inv_len = 1 / |raw_dir| ----
                        // One Newton-Raphson rsqrt step on len2 = |raw_dir|^2, using the
                        // linear seed y0 = 1.5 - len2/2 (valid since raw_dir ~ unit):
                        //     y0sq    = y0^2
                        //     r2y0sq  = len2 * y0^2
                        //     inv_len = y0 * (1.5 - r2y0sq/2)   -> ~1/sqrt(len2)
                        // Stage 8 then normalizes: nd = raw_dir * inv_len. Each multiply is
                        // issued on the shared bank (q_phase==0) and collected QCOL cycles
                        // later (q_phase==1). 1.5_Q16.16 = 0001_8000.
                        4'd5: begin  // rsqrt: y0sq = y0^2
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_s4_y0[cur_slot]; q_b0 <= rs_s4_y0[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_s5_y0sq[cur_slot] <= q_p0;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd6: begin  // rsqrt: r2y0sq = len2 * y0^2
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rslen2[cur_slot]; q_b0 <= rs_s5_y0sq[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_s6_r2y0sq[cur_slot] <= q_p0;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd7: begin  // rsqrt: inv_len = y0 * (1.5 - r2y0sq/2)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_s4_y0[cur_slot]; q_b0 <= 32'sh0001_8000 - (rs_s6_r2y0sq[cur_slot] >>> 1);
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rsinv_len[cur_slot] <= q_p0;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd8: begin  // normalize: nd = raw_dir * inv_len   (3 lanes)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rsdx[cur_slot]; q_b0 <= rsinv_len[cur_slot];
                                q_a1 <= rsdy[cur_slot]; q_b1 <= rsinv_len[cur_slot];
                                q_a2 <= rsdz[cur_slot]; q_b2 <= rsinv_len[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rsndx[cur_slot] <= q_p0; rsndy[cur_slot] <= q_p1; rsndz[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd9: begin
                            rs_sign_x[cur_slot] <= rsndx[cur_slot][31]; rs_sign_y[cur_slot] <= rsndy[cur_slot][31]; rs_sign_z[cur_slot] <= rsndz[cur_slot][31];
                            rs_xabs_x[cur_slot] <= qabs(rsndx[cur_slot]); rs_xabs_y[cur_slot] <= qabs(rsndy[cur_slot]); rs_xabs_z[cur_slot] <= qabs(rsndz[cur_slot]);
                            rs_r0_x[cur_slot]   <= recip_init(rsndx[cur_slot]);
                            rs_r0_y[cur_slot]   <= recip_init(rsndy[cur_slot]);
                            rs_r0_z[cur_slot]   <= recip_init(rsndz[cur_slot]);
                            step_x[cur_slot]    <= rsndx[cur_slot][31] ? -3'sd1 : 3'sd1;
                            step_y[cur_slot]    <= rsndy[cur_slot][31] ? -3'sd1 : 3'sd1;
                            step_z[cur_slot]    <= rsndz[cur_slot][31] ? -3'sd1 : 3'sd1;
                            rs_wait[cur_slot]   <= rs_wait[cur_slot] + 1'b1;
                        end
                        // ---- Newton-Raphson reciprocal: inv = 1 / normalized_dir ----
                        // Stages 10-13 refine an initial estimate r0 (~1/|x|, from
                        // recip_init) into the true reciprocal via two N-R passes:
                        //     t  = |x| * r        (residual; -> 1.0 at convergence)
                        //     r' = r * (2 - t)    (next estimate; ~doubles correct bits)
                        // r0 --t1--> r1 --t2--> final; then the sign of x is applied.
                        // Each multiply is time-multiplexed on the shared bank: q_phase==0
                        // issues the 3 lanes (x/y/z); QCOL cycles later (q_phase==1) the
                        // product is collected and rs_wait advances. 2.0_Q16.16 = 0002_0000.
                        4'd10: begin  // N-R pass 1: t1 = |x| * r0   (residual)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r0_x[cur_slot];
                                q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r0_y[cur_slot];
                                q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r0_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_t1_x[cur_slot] <= q_p0; rs_t1_y[cur_slot] <= q_p1; rs_t1_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd11: begin  // N-R pass 1: r1 = r0 * (2 - t1)   (refined estimate)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_r0_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t1_x[cur_slot];
                                q_a1 <= rs_r0_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t1_y[cur_slot];
                                q_a2 <= rs_r0_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t1_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_r1_x[cur_slot] <= q_p0; rs_r1_y[cur_slot] <= q_p1; rs_r1_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd12: begin  // N-R pass 2: t2 = |x| * r1   (residual)
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r1_x[cur_slot];
                                q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r1_y[cur_slot];
                                q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r1_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                rs_t2_x[cur_slot] <= q_p0; rs_t2_y[cur_slot] <= q_p1; rs_t2_z[cur_slot] <= q_p2;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        4'd13: begin  // N-R pass 2: inv = sign(x) * r1 * (2 - t2); latch rd_*, reset sp
                            if (q_phase[cur_slot] == 0) begin
                                q_a0 <= rs_r1_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t2_x[cur_slot];
                                q_a1 <= rs_r1_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t2_y[cur_slot];
                                q_a2 <= rs_r1_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t2_z[cur_slot];
                                q_phase[cur_slot] <= QCOL[2:0];
                            end else if (q_phase[cur_slot] == 1) begin
                                inv_x[cur_slot]   <= rs_sign_x[cur_slot] ? -q_p0 : q_p0;
                                inv_y[cur_slot]   <= rs_sign_y[cur_slot] ? -q_p1 : q_p1;
                                inv_z[cur_slot]   <= rs_sign_z[cur_slot] ? -q_p2 : q_p2;
                                rd_x[cur_slot]    <= rsndx[cur_slot];  rd_y[cur_slot] <= rsndy[cur_slot];  rd_z[cur_slot] <= rsndz[cur_slot];
                                sp[cur_slot]      <= '0;
                                q_phase[cur_slot] <= '0; rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;  // -> 14
                            end else q_phase[cur_slot] <= q_phase[cur_slot] - 1'b1;
                        end
                        default: begin  // 4'd14 -- pure state transition, no computation
                            rs_wait[cur_slot] <= '0;
                            state[cur_slot]   <= S_ROOT_SLAB;
                        end
                    endcase
                end
            end

            // -----------------------------------------------------------------
            S_ROOT_SLAB: begin
                // Slab times come from the shared multiplier bank, then sort/min/max/miss.
                // rs_wait sequence (0 on entry; both S_RAY_SETUP exits set rs_wait<='0):
                //   0,1 = issue the 6 slab qmuls (3 lanes x 2 cycles)
                //   2,3 = bank pipeline fill (QCOL=4)
                //   4   = collect tx0/ty0/tz0 (issued at 0, ready at 0+QCOL)
                //   5   = collect tx1/ty1/tz1 (issued at 1, ready at 1+QCOL)
                //   6   = sort each pair (lo=min, hi=max)
                //   7   = t_enter=max(lo), t_exit=min(hi)
                //   8   = miss check + clamp t_min + set node + transition
                // Algebra identical to before; the slab qmuls just route via the bank.
                case (rs_wait[cur_slot])
                    // Issue tx0/ty0/tz0 = qmul(-ro, inv) on lanes x/y/z
                    4'd0: begin
                        q_a0 <= -ro_x[cur_slot];          q_b0 <= inv_x[cur_slot];
                        q_a1 <= -ro_y[cur_slot];          q_b1 <= inv_y[cur_slot];
                        q_a2 <= -ro_z[cur_slot];          q_b2 <= inv_z[cur_slot];
                        rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                    end
                    // Issue tx1/ty1/tz1 = qmul(WORLD_Q-ro, inv)
                    4'd1: begin
                        q_a0 <= WORLD_Q - ro_x[cur_slot]; q_b0 <= inv_x[cur_slot];
                        q_a1 <= WORLD_Q - ro_y[cur_slot]; q_b1 <= inv_y[cur_slot];
                        q_a2 <= WORLD_Q - ro_z[cur_slot]; q_b2 <= inv_z[cur_slot];
                        rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                    end
                    4'd2: rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;   // bank fill
                    4'd3: rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;   // bank fill
                    // Collect issue-0 result (rs_wait 0 -> 0+QCOL)
                    4'd4: begin
                        rs_tx0_r[cur_slot] <= q_p0; rs_ty0_r[cur_slot] <= q_p1; rs_tz0_r[cur_slot] <= q_p2;
                        rs_wait[cur_slot]  <= rs_wait[cur_slot] + 1'b1;
                    end
                    // Collect issue-1 result (rs_wait 1 -> 1+QCOL)
                    4'd5: begin
                        rs_tx1_r[cur_slot] <= q_p0; rs_ty1_r[cur_slot] <= q_p1; rs_tz1_r[cur_slot] <= q_p2;
                        rs_wait[cur_slot]  <= rs_wait[cur_slot] + 1'b1;
                    end
                    // Sort each axis pair -> per-axis (lo=min, hi=max)
                    4'd6: begin
                        rs_lo_x[cur_slot] <= (rs_tx0_r[cur_slot] > rs_tx1_r[cur_slot]) ? rs_tx1_r[cur_slot] : rs_tx0_r[cur_slot];
                        rs_hi_x[cur_slot] <= (rs_tx0_r[cur_slot] > rs_tx1_r[cur_slot]) ? rs_tx0_r[cur_slot] : rs_tx1_r[cur_slot];
                        rs_lo_y[cur_slot] <= (rs_ty0_r[cur_slot] > rs_ty1_r[cur_slot]) ? rs_ty1_r[cur_slot] : rs_ty0_r[cur_slot];
                        rs_hi_y[cur_slot] <= (rs_ty0_r[cur_slot] > rs_ty1_r[cur_slot]) ? rs_ty0_r[cur_slot] : rs_ty1_r[cur_slot];
                        rs_lo_z[cur_slot] <= (rs_tz0_r[cur_slot] > rs_tz1_r[cur_slot]) ? rs_tz1_r[cur_slot] : rs_tz0_r[cur_slot];
                        rs_hi_z[cur_slot] <= (rs_tz0_r[cur_slot] > rs_tz1_r[cur_slot]) ? rs_tz0_r[cur_slot] : rs_tz1_r[cur_slot];
                        rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                    end
                    // t_enter = max(lo_x,lo_y,lo_z); t_exit = min(hi_x,hi_y,hi_z)
                    4'd7: begin
                        rs_enter_r[cur_slot] <= (rs_lo_x[cur_slot] > rs_lo_y[cur_slot]) ? ((rs_lo_x[cur_slot] > rs_lo_z[cur_slot]) ? rs_lo_x[cur_slot] : rs_lo_z[cur_slot])
                                                          : ((rs_lo_y[cur_slot] > rs_lo_z[cur_slot]) ? rs_lo_y[cur_slot] : rs_lo_z[cur_slot]);
                        rs_exit_r[cur_slot]  <= (rs_hi_x[cur_slot] < rs_hi_y[cur_slot]) ? ((rs_hi_x[cur_slot] < rs_hi_z[cur_slot]) ? rs_hi_x[cur_slot] : rs_hi_z[cur_slot])
                                                          : ((rs_hi_y[cur_slot] < rs_hi_z[cur_slot]) ? rs_hi_y[cur_slot] : rs_hi_z[cur_slot]);
                        rs_wait[cur_slot]    <= rs_wait[cur_slot] + 1'b1;
                    end
                    // Miss check (unclamped t_enter > t_exit) + clamp t_min; set node + state.
                    // Clamp t_min to 0: inside the world box t_enter<0; starting from t=0
                    // gives correct cx/cy/cz (t_next unaffected).
                    default: begin   // 4'd8
                        t_min[cur_slot] <= ($signed(rs_enter_r[cur_slot]) < 0) ? 32'sh0 : rs_enter_r[cur_slot];
                        t_max[cur_slot] <= rs_exit_r[cur_slot];
                        if (rs_enter_r[cur_slot] > rs_exit_r[cur_slot]) begin
                            state[cur_slot] <= S_MISS;
                        end else begin
                            node_idx[cur_slot]      <= '0;
                            node_half[cur_slot]     <= 6'(WORLD_SIZE >> 1);
                            node_origin_x[cur_slot] <= '0; node_origin_y[cur_slot] <= '0; node_origin_z[cur_slot] <= '0;
                            state[cur_slot] <= S_ENTER_NODE;
                        end
                        rs_wait[cur_slot] <= '0;
                    end
                endcase
            end

            // -----------------------------------------------------------------
            S_ENTER_NODE: begin
                bram_field[cur_slot]  <= 3'd7;   // sentinel: first S_BRAM_WAIT cycle absorbs BRAM latency
                svo_rd_en   <= 1'b1;
                svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd0};
                state[cur_slot]       <= S_BRAM_WAIT;
            end

            // -----------------------------------------------------------------
            // svo_bram has a registered output (1-cycle read latency after addr
            // is registered by the FSM), so data is valid 2 edges after the FSM
            // sets svo_rd_addr.  bram_field=7 is a pure wait that absorbs this
            // extra cycle; fields 0-6 then read words 0-6 with correct alignment.
            S_BRAM_WAIT: begin
                unique case (bram_field[cur_slot])
                    3'd7: begin   // wait: word-0 addr issued in S_ENTER_NODE, data ready next cycle
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd1};
                        bram_field[cur_slot]  <= 3'd0;
                        // geometry stage 0: capture child cell + entry-rel + node_half.
                        // te_* (hence bw_c_e*) and node_* are valid on this first BRAM-wait cycle, so
                        // dt/prod can be issued early enough (field 0/1) to hide the shared
                        // bank latency (QCOL=4) entirely inside the 8-cycle read window.
                        bw_cx_r[cur_slot]    <= bw_c_cx;    bw_cy_r[cur_slot]    <= bw_c_cy;    bw_cz_r[cur_slot]    <= bw_c_cz;
                        bw_exrel_r[cur_slot] <= bw_c_exrel; bw_eyrel_r[cur_slot] <= bw_c_eyrel; bw_ezrel_r[cur_slot] <= bw_c_ezrel;
                        bw_nhq_r[cur_slot]   <= bw_c_nhq;
                    end
                    3'd0: begin   // read word 0 = bitmask
                        r_bitmask[cur_slot] <= svo_rd_data[15:0];
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd2};
                        bram_field[cur_slot]  <= 3'd1;
                        // geometry stage 1: dist to next midplane (conditional, no qmul)
                        bw_distx_r[cur_slot] <= (!step_x[cur_slot][2]) ? (bw_cx_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_exrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_exrel_r[cur_slot]))
                                                   : (bw_cx_r[cur_slot][0] ? (bw_exrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_exrel_r[cur_slot]);
                        bw_disty_r[cur_slot] <= (!step_y[cur_slot][2]) ? (bw_cy_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_eyrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_eyrel_r[cur_slot]))
                                                   : (bw_cy_r[cur_slot][0] ? (bw_eyrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_eyrel_r[cur_slot]);
                        bw_distz_r[cur_slot] <= (!step_z[cur_slot][2]) ? (bw_cz_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_ezrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_ezrel_r[cur_slot]))
                                                   : (bw_cz_r[cur_slot][0] ? (bw_ezrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_ezrel_r[cur_slot]);
                        // issue dt = node_half*|inv| onto the shared bank (collect @ field 4)
                        q_a0 <= bw_nhq_r[cur_slot]; q_b0 <= qabs(inv_x[cur_slot]);
                        q_a1 <= bw_nhq_r[cur_slot]; q_b1 <= qabs(inv_y[cur_slot]);
                        q_a2 <= bw_nhq_r[cur_slot]; q_b2 <= qabs(inv_z[cur_slot]);
                    end
                    3'd1: begin   // read word 1 = child ptrs 0-1
                        r_child[cur_slot][0]<=svo_rd_data[15:0]; r_child[cur_slot][1]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd3};
                        bram_field[cur_slot]  <= 3'd2;
                        // issue prod = dist*|inv| onto the shared bank (collect @ field 5)
                        q_a0 <= bw_distx_r[cur_slot]; q_b0 <= qabs(inv_x[cur_slot]);
                        q_a1 <= bw_disty_r[cur_slot]; q_b1 <= qabs(inv_y[cur_slot]);
                        q_a2 <= bw_distz_r[cur_slot]; q_b2 <= qabs(inv_z[cur_slot]);
                    end
                    3'd2: begin   // read word 2 = child ptrs 2-3
                        r_child[cur_slot][2]<=svo_rd_data[15:0]; r_child[cur_slot][3]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd4};
                        bram_field[cur_slot]  <= 3'd3;
                    end
                    3'd3: begin   // read word 3 = child ptrs 4-5
                        r_child[cur_slot][4]<=svo_rd_data[15:0]; r_child[cur_slot][5]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd5};
                        bram_field[cur_slot]  <= 3'd4;
                    end
                    3'd4: begin   // read word 4 = child ptrs 6-7
                        r_child[cur_slot][6]<=svo_rd_data[15:0]; r_child[cur_slot][7]<=svo_rd_data[31:16];
                        svo_rd_addr <= {node_idx[cur_slot][11:0], 3'd6};
                        bram_field[cur_slot]  <= 3'd5;
                        // collect dt from the shared bank (issued @ field 0, QCOL=4)
                        bw_dtx_r[cur_slot] <= q_p0; bw_dty_r[cur_slot] <= q_p1; bw_dtz_r[cur_slot] <= q_p2;
                    end
                    3'd5: begin   // read word 5 = block IDs 0-3; word-6 addr already issued
                        r_block[cur_slot][0]<=svo_rd_data[7:0];   r_block[cur_slot][1]<=svo_rd_data[15:8];
                        r_block[cur_slot][2]<=svo_rd_data[23:16]; r_block[cur_slot][3]<=svo_rd_data[31:24];
                        svo_rd_en  <= '0;
                        bram_field[cur_slot] <= 3'd6;
                        // collect prod from the shared bank (issued @ field 1, QCOL=4)
                        bw_prodx_r[cur_slot] <= q_p0; bw_prody_r[cur_slot] <= q_p1; bw_prodz_r[cur_slot] <= q_p2;
                    end
                    3'd6: begin   // read word 6 = block IDs 4-7; done
                        r_block[cur_slot][4]<=svo_rd_data[7:0];   r_block[cur_slot][5]<=svo_rd_data[15:8];
                        r_block[cur_slot][6]<=svo_rd_data[23:16]; r_block[cur_slot][7]<=svo_rd_data[31:24];
                    end
                    default: ;
                endcase
                if (bram_field[cur_slot] == 3'd6) begin
                    svo_rd_en <= '0;
                    bitmask[cur_slot]   <= r_bitmask[cur_slot];
                    // dt comes from the pipelined qmul (stage 1); correct in BOTH the
                    // fresh-descend and post-pop cases (bw_nhq_r captured the restored
                    // node_half).
                    dt_x[cur_slot] <= bw_dtx_r[cur_slot]; dt_y[cur_slot] <= bw_dty_r[cur_slot]; dt_z[cur_slot] <= bw_dtz_r[cur_slot];
                    if (post_pop[cur_slot]) begin
                        // r_child[]/r_block[] now hold the parent node's data.
                        // cx/cy/cz and t_next were already restored by S_POP_STACK;
                        // the geometry pipeline output is ignored here (only dt is used).
                        post_pop[cur_slot] <= 1'b0;
                        state[cur_slot]    <= S_EMPTY;
                    end else begin
                        cx[cur_slot]       <= bw_cx_r[cur_slot]; cy[cur_slot] <= bw_cy_r[cur_slot]; cz[cur_slot] <= bw_cz_r[cur_slot];
                        t_next_x[cur_slot] <= t_min[cur_slot] + bw_prodx_r[cur_slot];   // geometry stage 3: t_min + dist*|inv|
                        t_next_y[cur_slot] <= t_min[cur_slot] + bw_prody_r[cur_slot];
                        t_next_z[cur_slot] <= t_min[cur_slot] + bw_prodz_r[cur_slot];
                        state[cur_slot]    <= S_CHECK_CHILD;
                    end
                end
            end

            // -----------------------------------------------------------------
            S_CHECK_CHILD: begin
                cidx[cur_slot] <= {cz[cur_slot][0], cy[cur_slot][0], cx[cur_slot][0]};
                unique case (2'((r_bitmask[cur_slot] >> ({cz[cur_slot][0],cy[cur_slot][0],cx[cur_slot][0]} * 2)) & 16'h0003))
                    2'b00:   state[cur_slot] <= S_EMPTY;
                    2'b11:   state[cur_slot] <= S_SOLID;
                    2'b01:   state[cur_slot] <= S_MIXED;
                    default: state[cur_slot] <= S_EMPTY;
                endcase
            end

            // -----------------------------------------------------------------
            S_EMPTY: begin
                if (t_next_x[cur_slot] <= t_next_y[cur_slot] && t_next_x[cur_slot] <= t_next_z[cur_slot]) begin
                    cx[cur_slot]       <= cx[cur_slot] + {{3{step_x[cur_slot][2]}}, step_x[cur_slot]};  // sign-extend 3-bit step
                    t_min[cur_slot]    <= t_next_x[cur_slot]; t_next_x[cur_slot] <= t_next_x[cur_slot] + dt_x[cur_slot];
                    em_face  = 2'd0; em_fsign = ~step_x[cur_slot][2];     // outward normal = opposite of ray dir
                    state[cur_slot]    <= (step_x[cur_slot][2] ^ cx[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else if (t_next_y[cur_slot] <= t_next_z[cur_slot]) begin
                    cy[cur_slot]       <= cy[cur_slot] + {{3{step_y[cur_slot][2]}}, step_y[cur_slot]};
                    t_min[cur_slot]    <= t_next_y[cur_slot]; t_next_y[cur_slot] <= t_next_y[cur_slot] + dt_y[cur_slot];
                    em_face  = 2'd1; em_fsign = ~step_y[cur_slot][2];
                    state[cur_slot]    <= (step_y[cur_slot][2] ^ cy[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else begin
                    cz[cur_slot]       <= cz[cur_slot] + {{3{step_z[cur_slot][2]}}, step_z[cur_slot]};
                    t_min[cur_slot]    <= t_next_z[cur_slot]; t_next_z[cur_slot] <= t_next_z[cur_slot] + dt_z[cur_slot];
                    em_face  = 2'd2; em_fsign = ~step_z[cur_slot][2];
                    state[cur_slot]    <= (step_z[cur_slot][2] ^ cz[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end
                hit_face[cur_slot]        <= em_face;
                hit_face_sign_r[cur_slot] <= em_fsign;
            end

            // -----------------------------------------------------------------
            S_SOLID: begin
                t_hit[cur_slot]        <= t_min[cur_slot];
                block_id_hit[cur_slot] <= r_block[cur_slot][cidx[cur_slot]];
                // Hit point = entry point at the current t_min. Use the *registered*
                // copy bw_e*_r, not the combinational bw_c_e*: t_min is stable across
                // S_CHECK_CHILD -> S_SOLID, so bw_e*_r (registered last cycle) holds the
                // identical value, and this becomes a short FF->FF copy instead of the
                // long entry-point multiply+add path (which was the −0.96 ns worst path).
                hit_px_r[cur_slot]     <= bw_c_ex;
                hit_py_r[cur_slot]     <= bw_c_ey;
                hit_pz_r[cur_slot]     <= bw_c_ez;
                if (SHADOW_MODE) begin
                    // Shadow mode: immediately signal hit and stop
                    any_hit    <= 1'b1;
                    frame_done <= 1'b1;
                    state[cur_slot]      <= S_IDLE;
                end else if (SHADE_MODE) begin
                    // hand off to shading pipeline
                    shade_is_miss       <= 1'b0;
                    shade_hit_face      <= hit_face[cur_slot];
                    shade_hit_face_sign <= hit_face_sign_r[cur_slot];
                    shade_block_id      <= r_block[cur_slot][cidx[cur_slot]];
                    shade_t_hit         <= t_min[cur_slot];
                    shade_ray_dx        <= rd_x[cur_slot];
                    shade_ray_dy        <= rd_y[cur_slot];
                    shade_ray_dz        <= rd_z[cur_slot];
                    shade_hit_px        <= bw_c_ex;   // ro + te_*; te_* registered last cycle
                    shade_hit_py        <= bw_c_ey;
                    shade_hit_pz        <= bw_c_ez;
                    shade_start         <= 1'b1;
                    state[cur_slot]               <= S_WAIT_SHADE;
                end else begin
                    // non shading for traversal test
                    pixel_color[cur_slot] <= 24'hFF_FF_FF;
                    state[cur_slot]       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            S_MIXED: begin
                stk_node_idx [cur_slot][sp[cur_slot]] <= node_idx[cur_slot];
                stk_bitmask  [cur_slot][sp[cur_slot]] <= r_bitmask[cur_slot];
                stk_t_min    [cur_slot][sp[cur_slot]] <= t_min[cur_slot];     stk_t_max    [cur_slot][sp[cur_slot]] <= t_max[cur_slot];
                stk_t_next_x [cur_slot][sp[cur_slot]] <= t_next_x[cur_slot];  stk_t_next_y [cur_slot][sp[cur_slot]] <= t_next_y[cur_slot];
                stk_t_next_z [cur_slot][sp[cur_slot]] <= t_next_z[cur_slot];
                stk_cx       [cur_slot][sp[cur_slot]] <= cx[cur_slot];  stk_cy [cur_slot][sp[cur_slot]] <= cy[cur_slot];  stk_cz [cur_slot][sp[cur_slot]] <= cz[cur_slot];
                stk_node_half[cur_slot][sp[cur_slot]] <= node_half[cur_slot];
                stk_orig_x   [cur_slot][sp[cur_slot]] <= node_origin_x[cur_slot];
                stk_orig_y   [cur_slot][sp[cur_slot]] <= node_origin_y[cur_slot];
                stk_orig_z   [cur_slot][sp[cur_slot]] <= node_origin_z[cur_slot];
                sp[cur_slot]            <= sp[cur_slot] + 1'b1;
                node_idx[cur_slot]      <= r_child[cur_slot][cidx[cur_slot]];
                node_origin_x[cur_slot] <= node_origin_x[cur_slot] + (cx[cur_slot][0] ? node_half[cur_slot] : 6'd0);
                node_origin_y[cur_slot] <= node_origin_y[cur_slot] + (cy[cur_slot][0] ? node_half[cur_slot] : 6'd0);
                node_origin_z[cur_slot] <= node_origin_z[cur_slot] + (cz[cur_slot][0] ? node_half[cur_slot] : 6'd0);
                node_half[cur_slot]     <= node_half[cur_slot] >> 1;
                state[cur_slot] <= S_ENTER_NODE;
            end

            // -----------------------------------------------------------------
            S_POP_STACK: begin
                if (sp[cur_slot] == '0)
                    state[cur_slot] <= S_MISS;
                else begin
                    sp[cur_slot]            <= sp[cur_slot] - 1'b1;
                    node_idx[cur_slot]      <= stk_node_idx [cur_slot][sp[cur_slot]-1];
                    r_bitmask[cur_slot]     <= stk_bitmask  [cur_slot][sp[cur_slot]-1];
                    t_min[cur_slot]         <= stk_t_min    [cur_slot][sp[cur_slot]-1]; t_max[cur_slot] <= stk_t_max [cur_slot][sp[cur_slot]-1];
                    t_next_x[cur_slot]      <= stk_t_next_x [cur_slot][sp[cur_slot]-1];
                    t_next_y[cur_slot]      <= stk_t_next_y [cur_slot][sp[cur_slot]-1];
                    t_next_z[cur_slot]      <= stk_t_next_z [cur_slot][sp[cur_slot]-1];
                    // dt is recomputed in S_BRAM_WAIT field=6 from the restored
                    // node_half (post_pop path), so no qmul is needed here.
                    cx[cur_slot]            <= stk_cx       [cur_slot][sp[cur_slot]-1];
                    cy[cur_slot]            <= stk_cy       [cur_slot][sp[cur_slot]-1];
                    cz[cur_slot]            <= stk_cz       [cur_slot][sp[cur_slot]-1];
                    node_half[cur_slot]     <= stk_node_half[cur_slot][sp[cur_slot]-1];
                    node_origin_x[cur_slot] <= stk_orig_x   [cur_slot][sp[cur_slot]-1];
                    node_origin_y[cur_slot] <= stk_orig_y   [cur_slot][sp[cur_slot]-1];
                    node_origin_z[cur_slot] <= stk_orig_z   [cur_slot][sp[cur_slot]-1];
                    // Re-read BRAM to recover r_child[]/r_block[] for the restored
                    // parent node. post_pop suppresses cx/cy/cz recomputation in
                    // S_BRAM_WAIT field=6 so the stack-restored DDA state is kept.
                    post_pop[cur_slot] <= 1'b1;
                    state[cur_slot] <= S_ENTER_NODE;
                end
            end

            // -----------------------------------------------------------------
            S_MISS: begin
                // any_hit not asserted, just says its done
                if (SHADOW_MODE) begin
                    frame_done <= 1'b1;
                    state[cur_slot]      <= S_IDLE;
                    // Go into shading pipeline as miss
                end else if (SHADE_MODE) begin
                    shade_is_miss  <= 1'b1;
                    shade_start    <= 1'b1;
                    state[cur_slot]          <= S_WAIT_SHADE;
                end else begin
                    // Non shading mode for testing traversal
                    pixel_color[cur_slot] <= sky_color;
                    state[cur_slot]       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            S_WAIT_SHADE: begin
                shade_start <= '0;
                if (shade_done) begin
                    pixel_color[cur_slot] <= shade_pixel_color;
                    state[cur_slot]       <= S_WRITE_PIXEL;
                end //Stalls here until shade_done
            end

            // -----------------------------------------------------------------
            S_WRITE_PIXEL: begin
                axis_tvalid <= 1'b1;
                axis_tdata  <= {8'h00, pixel_color[cur_slot]};
                // tlast high for last pixel of each line
                //tuser high on first pixel
                axis_tlast  <= (px[cur_slot] == 9'(IMG_W - 1));
                axis_tuser  <= (px[cur_slot] == '0 && py[cur_slot] == '0) ? 1'b1 : 1'b0;
                if (axis_tready)
                    state[cur_slot] <= S_NEXT_PIXEL;
                // else: hold tvalid high until tready (AXI-Stream rules)
            end

            // -----------------------------------------------------------------
            S_NEXT_PIXEL: begin
                axis_tvalid <= 1'b0;
                sp[cur_slot]          <= '0;
                post_pop[cur_slot]    <= 1'b0;
                // reach end of line, reset x and increment y
                if (px[cur_slot] == 9'(IMG_W - 1)) begin
                    px[cur_slot] <= '0;
                    // end of frame
                    if (py[cur_slot] == 8'(IMG_H - 1)) begin
                        py[cur_slot]         <= '0;
                        frame_done <= 1'b1;
                        state[cur_slot]      <= S_IDLE;
                    end else begin
                        py[cur_slot]      <= py[cur_slot] + 1'b1;
                        rs_wait[cur_slot] <= '0;
                        state[cur_slot]   <= S_RAY_SETUP;
                    end
                end else begin
                    px[cur_slot]      <= px[cur_slot] + 1'b1;
                    rs_wait[cur_slot] <= '0;
                    state[cur_slot]   <= S_RAY_SETUP;
                end
            end

            endcase
        end
    end

endmodule
