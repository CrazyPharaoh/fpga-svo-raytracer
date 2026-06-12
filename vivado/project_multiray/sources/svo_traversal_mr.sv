// svo_traversal_mr.sv
// Interleaved N-ray DDA octree traversal over one shared datapath. A pool of
// RAY_POOL_N rays advance round-robin through a single FSM/multiplier datapath,
// hiding per-ray compute and memory latency. RAY_POOL_N=1 is single-ray.
// All arithmetic in Q16.16 signed fixed-point.
//
// Parameters:
//   SHADE_MODE = 0  Phase 1: hit -> white, miss -> sky_color (no shading pipeline).
//   SHADE_MODE = 1  Phase 2: hit/miss hand off to the shading pipeline.
`timescale 1ns/1ps
module svo_traversal_mr #(
    parameter int RAY_POOL_N  = 1,   // rays in flight over the shared datapath
    parameter int IMG_W       = 320,
    parameter int IMG_H       = 240,
    parameter int STACK_DEPTH = 12,
    parameter int WORLD_SIZE  = 64,
    parameter bit SHADOW_MODE = 0,   // 1 = shadow-ray instance
    parameter bit SHADE_MODE  = 0,   // 1 = hand off to shading_pipeline
    parameter int SHADE_LANES = 2    // parallel shading pipelines (SHADE_MODE=1)
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // Camera registers (Q16.16)
    input  logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    input  logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    input  logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    input  logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    input  logic signed [31:0] cam_scale,

    // Sky colour (Phase 1 miss path)
    input  logic [23:0] sky_color,

    // Runtime traversal depth cap; MIXED-at-cap -> solid (LOD)
    input  logic [3:0]  max_depth,

    // SVO BRAM read port (whole node returned in one cycle)
    output logic [11:0]  svo_rd_node,   // node index
    input  logic [255:0] svo_rd_wide,   // whole node {w7..w0}
    output logic         svo_rd_en,

    // Framebuffer write port (legacy — undriven when AXI-Stream path is active)
    output logic [16:0] fb_wr_addr,
    output logic [23:0] fb_wr_data,
    output logic        fb_wr_en,

    // AXI-Stream pixel output
    output logic        axis_tvalid,
    output logic [31:0] axis_tdata,   // [31:24]=0x00, [23:16]=R, [15:8]=G, [7:0]=B
    output logic        axis_tlast,   // high on last pixel of each line (px == IMG_W-1)
    output logic [0:0]  axis_tuser,   // high on first pixel of frame (px==0, py==0)
    input  logic        axis_tready,

    // Shading pipeline handoff (SHADE_MODE=1 only) — one bundle per shading lane.
    output logic        shade_start         [0:SHADE_LANES-1],
    output logic        shade_is_miss       [0:SHADE_LANES-1],
    output logic [1:0]  shade_hit_face      [0:SHADE_LANES-1],
    output logic        shade_hit_face_sign [0:SHADE_LANES-1],
    output logic [7:0]  shade_block_id      [0:SHADE_LANES-1],
    output logic signed [31:0] shade_t_hit  [0:SHADE_LANES-1],
    output logic signed [31:0] shade_ray_dx [0:SHADE_LANES-1],
    output logic signed [31:0] shade_ray_dy [0:SHADE_LANES-1],
    output logic signed [31:0] shade_ray_dz [0:SHADE_LANES-1],
    output logic signed [31:0] shade_hit_px [0:SHADE_LANES-1],
    output logic signed [31:0] shade_hit_py [0:SHADE_LANES-1],
    output logic signed [31:0] shade_hit_pz [0:SHADE_LANES-1],
    input  logic        shade_done          [0:SHADE_LANES-1],
    input  logic [23:0] shade_pixel_color   [0:SHADE_LANES-1],

    // Status
    output logic        busy,
    output logic        frame_done,
    output logic        any_hit,

    // Debug: readable via AXI at run-time to diagnose hangs
    output logic [3:0]  dbg_state,    // current FSM state integer (S_WRITE_PIXEL=12)
    output logic [3:0]  dbg_rs_wait,  // rs_wait counter (0-15); stuck => hang
    output logic [8:0]  dbg_px,       // current pixel X
    output logic [7:0]  dbg_py,       // current pixel Y
    output logic        dbg_tvalid,   // axis_tvalid: IP is outputting a pixel
    output logic        dbg_tready,   // axis_tready: VDMA is accepting the pixel
    output logic [31:0] dbg_mr,       // multi-ray internals (see packing below)
    // ILA probes (mark_debug in top.sv): executing slot + two of its per-slot ray
    // values, to check slot N is running with its own data. 2-bit slot covers N up to 4.
    output logic [1:0]  dbg_cur_slot, // currently-executing slot
    output logic [31:0] dbg_d0,       // {node_idx[15:0], r_bitmask[15:0]} — node read
    output logic [31:0] dbg_d1        // {0, sp, cidx, cx, cy, cz} — traversal position
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

    // Ray slot advanced this cycle (driven by the round-robin scheduler).
    localparam int SLOT_W = (RAY_POOL_N > 1) ? $clog2(RAY_POOL_N) : 1;
    logic [SLOT_W-1:0] cur_slot;

    // -------------------------------------------------------------------------
    // Round-robin-over-ready scheduler. Each cycle it picks one ready slot to
    // advance through the shared datapath. A slot is ready when it is mid-ray,
    // not blocked on a multiply, and (if it wants to START a BRAM read) the
    // single read port is free or already owned by it.
    // -------------------------------------------------------------------------
    logic                  bram_busy;     // a slot currently owns the read port
    logic [SLOT_W-1:0]     bram_owner;

    // Shading arbiter (SHADE_MODE=1 only). Slots that hit/miss raise shade_pending
    // and park in S_WAIT_SHADE. The arbiter grants a pending slot to a free shading
    // lane, drives the shade_* outputs from that slot's stored hit info, asserts
    // shade_start, and on shade_done writes the owner's pixel + frees the lane.
    // Inert when SHADE_MODE=0 (Phase 1).
    logic                  shade_busy  [0:SHADE_LANES-1];  // each lane's shading pipeline in use
    logic [SLOT_W-1:0]     shade_owner [0:SHADE_LANES-1];  // slot each lane is shading
    logic                  shade_pending [0:RAY_POOL_N-1];  // slot wants shading
    logic                  shade_is_miss_r [0:RAY_POOL_N-1]; // per-slot: hit(0)/miss(1)

    logic [RAY_POOL_N-1:0] ready;
    always_comb begin
        for (int s = 0; s < RAY_POOL_N; s++) begin
            ready[s] = (state[s] != S_IDLE) && (state[s] != S_WAIT_SHADE) && !blocked[s];
            // Atomic BRAM read: while one slot owns the read port (bram_busy), no
            // other slot may run until the owner releases it.
            if (bram_busy && (s[SLOT_W-1:0] != bram_owner))
                ready[s] = 1'b0;
        end
    end

    logic                  grant_valid;
    logic [SLOT_W-1:0]     grant_slot;
    logic [SLOT_W-1:0]     last_grant;
    generate
        if (RAY_POOL_N == 1) begin : g_sched_n1
            // bypass the scheduler at N=1 (its slot ports are zero-width): grant
            // slot 0 whenever it is ready.
            assign grant_valid = ready[0];
            assign grant_slot  = '0;
        end else begin : g_sched
            ray_scheduler #(.RAY_POOL_N(RAY_POOL_N)) u_sched (
                .ready(ready), .last_grant(last_grant),
                .grant_valid(grant_valid), .grant(grant_slot)
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Registered scheduler grant. cur_slot is a register (not the combinational
    // grant) so every per-slot RAM read starts from a register, keeping the
    // state->ready->grant decode off the datapath's critical path.
    //
    // BRAM-read atomicity: the owner must hold the turn for the read's 1-2 cycles.
    // bram_busy is registered (lags the S_ENTER_NODE that sets it by a cycle), so
    // cover both edges:
    //   mid-read (bram_busy)                  -> stick with bram_owner
    //   read about to start (in S_ENTER_NODE) -> stick with the same slot
    //   otherwise                             -> take the scheduler's grant
    logic              cur_valid;   // cur_slot holds a slot worth executing this cycle
    wire starting_read = cur_valid && (state[cur_slot] == S_ENTER_NODE);
    wire [SLOT_W-1:0] next_slot  = bram_busy     ? bram_owner
                                 : starting_read ? cur_slot
                                 :                 grant_slot;
    wire              next_valid = bram_busy || starting_read || grant_valid;

    // World box upper boundary in Q16.16 (WORLD_SIZE.0). Used by S_ROOT_SLAB.
    localparam logic signed [31:0] WORLD_Q = WORLD_SIZE << 16;
    // Screen-centre in Q16.16: (IMG_W/2, IMG_H/2). (IMG/2)<<16 == IMG<<15.
    // Derived from the resolution params so a lower-res build stays centred.
    localparam logic signed [31:0] CENTER_X_Q = $signed(32'(IMG_W) << 15);
    localparam logic signed [31:0] CENTER_Y_Q = $signed(32'(IMG_H) << 15);
    logic [3:0] state_raw; assign state_raw = state[cur_slot];
    assign dbg_state   = state_raw;
    assign dbg_rs_wait = rs_wait[cur_slot];
    assign dbg_px      = px[cur_slot];
    assign dbg_py      = py[cur_slot];
    assign dbg_tvalid  = axis_tvalid;
    assign dbg_tready  = axis_tready;
    // ILA probes: executing slot + the node data it's reading.
    // d0 = {node_idx[15:0], bitmask[15:0]}; d1 = DDA step direction vs ray-dir sign.
    assign dbg_cur_slot = 2'(cur_slot);
    assign dbg_d0       = {node_idx[cur_slot], r_bitmask[cur_slot]};
    // d1: bits[15:13]=rd sign(x,y,z), [12:10]=step sign(x,y,z),
    //     [9:6]=sp, [5:3]=cidx, [2:0]=cell(x,y,z).
    assign dbg_d1       = {16'd0,
                           rd_x[cur_slot][31],  rd_y[cur_slot][31],  rd_z[cur_slot][31],
                           step_x[cur_slot][2], step_y[cur_slot][2], step_z[cur_slot][2],
                           sp[cur_slot], cidx[cur_slot],
                           cx[cur_slot][0], cy[cur_slot][0], cz[cur_slot][0]};

    // Debug word (read via AXI 0x80) to localise hangs:
    //   [15:0]  state[0..3]  (4 bits each; only first RAY_POOL_N valid)
    //   [16]    grant_valid   [17] bram_busy   [18] shade_busy
    //   [23:20] ready vector  [25:24] bram_owner  [27:26] shade_owner
    // Packed combinationally, then registered into dbg_mr so the long route out to
    // the AXI slave is reg->route->reg, keeping it off the critical path. The
    // 1-cycle delay on a debug readout is irrelevant.
    logic [31:0] dbg_mr_c;
    always_comb begin
        dbg_mr_c = '0;
        for (int s = 0; s < RAY_POOL_N; s++) dbg_mr_c[s*4 +: 4] = 4'(state[s]);
        dbg_mr_c[16] = grant_valid;
        dbg_mr_c[17] = bram_busy;
        dbg_mr_c[18] = shade_busy[0];   // lane 0 (debug)
        for (int s = 0; s < RAY_POOL_N; s++) dbg_mr_c[20 + s] = ready[s];
        dbg_mr_c[24 +: SLOT_W] = bram_owner;
        dbg_mr_c[26 +: SLOT_W] = shade_owner[0];
    end
    always_ff @(posedge clk) dbg_mr <= dbg_mr_c;

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

    // Combinational scratch temps written and read within the same cycle (shared).
    logic [1:0]         em_face;
    logic               em_fsign;
    logic signed [31:0] rsu [0:RAY_POOL_N-1], rsv [0:RAY_POOL_N-1], rsdx [0:RAY_POOL_N-1], rsdy [0:RAY_POOL_N-1], rsdz [0:RAY_POOL_N-1], rslen2 [0:RAY_POOL_N-1], rsinv_len [0:RAY_POOL_N-1], rsndx [0:RAY_POOL_N-1], rsndy [0:RAY_POOL_N-1], rsndz [0:RAY_POOL_N-1];

    // S_RAY_SETUP pipeline stage registers, named by the stage that writes them.
    // Registers hold their value until overwritten, so later stages read earlier
    // outputs without explicit delay registers.
    logic signed [31:0] rs_s1_a [0:RAY_POOL_N-1], rs_s1_b [0:RAY_POOL_N-1];          // stage 1: qmul(rsu, cam_right_x), qmul(rsv, cam_up_x)
    logic signed [31:0] rs_s1_c [0:RAY_POOL_N-1], rs_s1_d [0:RAY_POOL_N-1];          // stage 1: ... for Y
    logic signed [31:0] rs_s1_e [0:RAY_POOL_N-1], rs_s1_f [0:RAY_POOL_N-1];          // stage 1: ... for Z
    logic signed [31:0] rs_s3_dx2 [0:RAY_POOL_N-1], rs_s3_dy2 [0:RAY_POOL_N-1], rs_s3_dz2 [0:RAY_POOL_N-1];  // stage 3: rsd*^2
    logic signed [31:0] rs_s4_y0 [0:RAY_POOL_N-1];                   // stage 4: 1.5 - rslen2/2 (NR seed for 1/sqrt(len))
    logic signed [31:0] rs_s5_y0sq [0:RAY_POOL_N-1];                 // stage 5: y0^2
    logic signed [31:0] rs_s6_r2y0sq [0:RAY_POOL_N-1];               // stage 6: rslen2 x y0^2
    // Reciprocal N-R registers (used at stages 9-13).
    logic signed [31:0] rs_xabs_x [0:RAY_POOL_N-1], rs_xabs_y [0:RAY_POOL_N-1], rs_xabs_z [0:RAY_POOL_N-1];  // |rd_*|
    logic signed [31:0] rs_r0_x   [0:RAY_POOL_N-1], rs_r0_y   [0:RAY_POOL_N-1], rs_r0_z   [0:RAY_POOL_N-1];    // initial N-R estimates
    logic signed [31:0] rs_t1_x   [0:RAY_POOL_N-1], rs_t1_y   [0:RAY_POOL_N-1], rs_t1_z   [0:RAY_POOL_N-1];    // N-R iteration 1 multiply
    logic signed [31:0] rs_r1_x   [0:RAY_POOL_N-1], rs_r1_y   [0:RAY_POOL_N-1], rs_r1_z   [0:RAY_POOL_N-1];    // N-R iteration 1 result
    logic signed [31:0] rs_t2_x   [0:RAY_POOL_N-1], rs_t2_y   [0:RAY_POOL_N-1], rs_t2_z   [0:RAY_POOL_N-1];    // N-R iteration 2 multiply
    logic               rs_sign_x [0:RAY_POOL_N-1], rs_sign_y [0:RAY_POOL_N-1], rs_sign_z [0:RAY_POOL_N-1];   // sign of final rd_* component

    // Shared 3-lane multiplier bank. The FSM registers operands into q_a*/q_b* in
    // the issue stage; products are valid QCOL = 4 cycles later (shared_qmul3
    // latency 3 + the operand register). Every S_RAY_SETUP and S_ROOT_SLAB qmul is
    // issued onto this bank.
    localparam int QCOL = 4;
    logic signed [31:0] q_a0, q_b0, q_a1, q_b1, q_a2, q_b2;
    logic signed [31:0] q_p0, q_p1, q_p2;
    // Entry point P = ro + t_min*rd (Q16.16). The multiply t_min*rd is registered
    // into te_* (one cycle); the +ro add is combinational in the consuming cycle.
    // Computed per-slot in parallel (dedicated DSPs, no cur_slot decode in front) to
    // keep the 1-cycle latency S_SOLID relies on (it reads ro+te only 2 cycles after
    // t_min is set).
    logic signed [31:0] te_x [0:RAY_POOL_N-1], te_y [0:RAY_POOL_N-1], te_z [0:RAY_POOL_N-1];          // registered t_min*rd
    logic signed [31:0] bw_c_ex, bw_c_ey, bw_c_ez;  // = ro + te_* (combinational add); hit pos at S_SOLID
    // Registered entry point (geom_phase 0). The index/exrel logic reads these, so
    // the 32-bit ro+te add stays off the cell-index path. bw_c_e* is stable across
    // the read, so registering it a phase earlier is value-identical.
    logic signed [31:0] bw_c_ex_r [0:RAY_POOL_N-1], bw_c_ey_r [0:RAY_POOL_N-1], bw_c_ez_r [0:RAY_POOL_N-1];
    // S_BRAM_WAIT geometry from the registered entry point bw_c_e*_r.
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
    logic [7:0]  r_dom_block [0:RAY_POOL_N-1];   // node word 7: representative block for depth-cap LOD
    logic [15:0] r_bitmask [0:RAY_POOL_N-1];
    logic [2:0]  bram_field [0:RAY_POOL_N-1];
    // DDA-step geometry pipeline phase, decoupled from bram_field: the node read
    // (bram_field) and the entry-geometry (cx/dist/dt/t_next) run on independent
    // counters during S_BRAM_WAIT so the read can compact without disturbing geometry.
    logic [2:0]  geom_phase [0:RAY_POOL_N-1];

    // Hit info
    logic [7:0]  block_id_hit [0:RAY_POOL_N-1];
    logic        lod_cap [0:RAY_POOL_N-1];   // this hit was a depth-capped MIXED node
    logic signed [31:0] t_hit [0:RAY_POOL_N-1];
    logic [1:0]  hit_face [0:RAY_POOL_N-1];
    logic        hit_face_sign_r [0:RAY_POOL_N-1];
    logic signed [31:0] hit_px_r [0:RAY_POOL_N-1], hit_py_r [0:RAY_POOL_N-1], hit_pz_r [0:RAY_POOL_N-1];

    // Representative block-id for a depth-capped MIXED node: lowest-index non-empty
    // child block-id of the current slot's node (the "surrounding blocks"), fallback 1.
    logic [7:0] rep_block_w;
    always_comb begin
        rep_block_w = 8'd1;                       // fallback if every child is MIXED/air
        for (int i = 7; i >= 0; i--)
            if (r_block[cur_slot][i] != 8'd0) rep_block_w = r_block[cur_slot][i];
    end

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

    // Stage counter for the S_RAY_SETUP pipeline: advances 0->14 (primary mode).
    logic [3:0] rs_wait [0:RAY_POOL_N-1];
    // Issue sub-step flag for the few stages that issue two multiply groups.
    logic [2:0] q_phase [0:RAY_POOL_N-1];

    // ------------------------------------------------------------------------
    // Slot-tagged issue + block + collector for shared-bank multiplies. A slot is
    // blocked while waiting for a tagged multiply it issued, letting another slot
    // run during the QCOL-cycle wait (latency hiding).
    // ------------------------------------------------------------------------
    logic blocked [0:RAY_POOL_N-1];

    // Inline tag pipe: when a stage registers q_a* at cycle T, q_p* is valid at
    // T+4. q_iss_v (registered at T) is valid T+1; shift it 3 more times so
    // q_res_v/q_res_t line up with q_p* at T+4. (Keeps shared_qmul3 untouched.)
    localparam int DST_W = 4;
    localparam int TAGW  = SLOT_W + DST_W;
    logic            q_iss_v;
    logic [TAGW-1:0] q_iss_t;
    logic            q_tv [0:2];
    logic [TAGW-1:0] q_tt [0:2];
    wire             q_res_v = q_tv[2];
    wire [TAGW-1:0]  q_res_t = q_tt[2];
    // ray-setup multiply destinations
    localparam logic [DST_W-1:0]
        DST_RS0=0, DST_RS1A=1, DST_RS1B=2, DST_RS3=3, DST_RS5=4, DST_RS6=5,
        DST_RS7=6, DST_RS8=7, DST_RS10=8, DST_RS11=9, DST_RS12=10, DST_RS13=11,
        DST_SLAB0=12, DST_SLAB1=13, DST_GDT=14, DST_GPROD=15;

    // Set when S_POP_STACK redirects through S_ENTER_NODE to reload r_child[]/r_block[].
    // Suppresses the cx/cy/cz and t_next recomputation in S_BRAM_WAIT.
    logic post_pop [0:RAY_POOL_N-1];

    // -------------------------------------------------------------------------
    // Shared 3-lane multiplier bank. FSM stages issue operands onto these lanes
    // and the collector writes the products QCOL cycles later.
    // -------------------------------------------------------------------------
    shared_qmul3 #(.LAT(3)) u_qmul (
        .clk(clk),
        .a0(q_a0), .b0(q_b0), .a1(q_a1), .b1(q_b1), .a2(q_a2), .b2(q_b2),
        .p0(q_p0), .p1(q_p1), .p2(q_p2)
    );

    // -------------------------------------------------------------------------
    // Pixel launch/retire reorder buffer (owns AXIS output + busy/frame_done).
    // pixel_reorder launches pixels in raster order into free slots and emits
    // finished colours on AXIS in raster order; the core starts a ray when
    // launched and pulses pr_done_* when a slot's ray finishes.
    // -------------------------------------------------------------------------
    logic              pr_launch_valid;
    logic [SLOT_W-1:0] pr_launch_slot;
    logic [8:0]        pr_launch_px;
    logic [7:0]        pr_launch_py;
    logic              pr_done_valid;
    logic [SLOT_W-1:0] pr_done_slot;
    logic [23:0]       pr_done_color;

    pixel_reorder #(.IMG_W(IMG_W), .IMG_H(IMG_H), .RAY_POOL_N(RAY_POOL_N), .SLOT_W(SLOT_W)) u_reorder (
        .clk(clk), .rst(rst), .start(start),
        .launch_valid(pr_launch_valid), .launch_slot(pr_launch_slot),
        .launch_px(pr_launch_px), .launch_py(pr_launch_py),
        .done_valid(pr_done_valid), .done_slot(pr_done_slot), .done_color(pr_done_color),
        .axis_tvalid(axis_tvalid), .axis_tdata(axis_tdata),
        .axis_tlast(axis_tlast), .axis_tuser(axis_tuser), .axis_tready(axis_tready),
        .busy(busy), .frame_done(frame_done)
    );

    // any_hit unused in primary mode; tie low.
    assign any_hit = 1'b0;

    // Icarus X-avoid: deterministic init of the block/tag machinery.
    initial begin
        for (int s = 0; s < RAY_POOL_N; s++) begin
            blocked[s] = 1'b0;
            shade_pending[s] = 1'b0;
            shade_is_miss_r[s] = 1'b0;
        end
        q_iss_v = 1'b0;
        q_tv[0] = 1'b0; q_tv[1] = 1'b0; q_tv[2] = 1'b0;
        bram_busy = 1'b0; bram_owner = '0; last_grant = '0;
        for (int L = 0; L < SHADE_LANES; L++) begin shade_busy[L] = 1'b0; shade_owner[L] = '0; end
    end

    // -------------------------------------------------------------------------
    // Shading arbiter (combinational): pick one pending slot when the shader is
    // free. Gated by SHADE_MODE, so inert in Phase 1.
    // -------------------------------------------------------------------------
    // Grant up to SHADE_LANES pending slots per cycle — one per FREE lane, each a DISTINCT
    // pending slot (the `taken` mask prevents two lanes grabbing the same slot).
    logic              shade_grant      [0:SHADE_LANES-1];
    logic [SLOT_W-1:0] shade_grant_slot [0:SHADE_LANES-1];
    always_comb begin
        automatic logic [RAY_POOL_N-1:0] taken = '0;
        for (int L = 0; L < SHADE_LANES; L++) begin
            shade_grant[L]      = 1'b0;
            shade_grant_slot[L] = '0;
            if (SHADE_MODE && !shade_busy[L]) begin
                for (int s = 0; s < RAY_POOL_N; s++)
                    if (!shade_grant[L] && shade_pending[s] && !taken[s]) begin
                        shade_grant[L]      = 1'b1;
                        shade_grant_slot[L] = s[SLOT_W-1:0];
                        taken[s]            = 1'b1;
                    end
            end
        end
    end

    // Drive the shade_* outputs from the slot currently being shaded, held stable
    // for the whole shade (the pipeline reads its inputs across multiple cycles, not
    // just on start). Use shade_owner while busy, and the freshly-granted slot on the
    // grant cycle. shade_start is the 1-cycle grant pulse.
    always_comb begin
        for (int L = 0; L < SHADE_LANES; L++) begin
            automatic logic [SLOT_W-1:0] sa = shade_busy[L] ? shade_owner[L] : shade_grant_slot[L];
            shade_start[L]         = shade_grant[L];
            shade_is_miss[L]       = shade_is_miss_r[sa];
            shade_hit_face[L]      = hit_face[sa];
            shade_hit_face_sign[L] = hit_face_sign_r[sa];
            shade_block_id[L]      = block_id_hit[sa];
            shade_t_hit[L]         = t_hit[sa];
            shade_ray_dx[L]        = rd_x[sa];
            shade_ray_dy[L]        = rd_y[sa];
            shade_ray_dz[L]        = rd_z[sa];
            shade_hit_px[L]        = hit_px_r[sa];
            shade_hit_py[L]        = hit_py_r[sa];
            shade_hit_pz[L]        = hit_pz_r[sa];
        end
    end

    // -------------------------------------------------------------------------
    // Entry-point add: P = ro + (t_min*rd). te_* is the registered product, so this
    // is only an add. t_min/ro_*/rd_* are stable across the read and at a solid hit,
    // so te_* (registered the previous cycle) gives the correct entry point.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_ex = ro_x[cur_slot] + te_x[cur_slot];
        bw_c_ey = ro_y[cur_slot] + te_y[cur_slot];
        bw_c_ez = ro_z[cur_slot] + te_z[cur_slot];
    end

    // -------------------------------------------------------------------------
    // S_BRAM_WAIT combinational geometry, from the registered entry point bw_c_e*_r.
    // node_half / node_origin_* / step_* / inv_* are stable across the read.
    // -------------------------------------------------------------------------
    always_comb begin
        bw_c_nhq = $signed(32'(node_half[cur_slot])) << 16;
        // child cell index within this node, clamped on underflow/negative.
        bw_c_icx = ($signed(bw_c_ex_r[cur_slot]) < 0) ? 7'd0 : bw_c_ex_r[cur_slot][22:16];
        bw_c_icy = ($signed(bw_c_ey_r[cur_slot]) < 0) ? 7'd0 : bw_c_ey_r[cur_slot][22:16];
        bw_c_icz = ($signed(bw_c_ez_r[cur_slot]) < 0) ? 7'd0 : bw_c_ez_r[cur_slot][22:16];
        bw_c_icx = (bw_c_icx >= node_origin_x[cur_slot]) ? bw_c_icx - node_origin_x[cur_slot] : 7'd0;
        bw_c_icy = (bw_c_icy >= node_origin_y[cur_slot]) ? bw_c_icy - node_origin_y[cur_slot] : 7'd0;
        bw_c_icz = (bw_c_icz >= node_origin_z[cur_slot]) ? bw_c_icz - node_origin_z[cur_slot] : 7'd0;
        bw_c_cx  = (bw_c_icx >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_cy  = (bw_c_icy >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_cz  = (bw_c_icz >= node_half[cur_slot]) ? 6'd1 : 6'd0;
        bw_c_exrel = bw_c_ex_r[cur_slot] - ($signed(32'(node_origin_x[cur_slot])) << 16);
        bw_c_eyrel = bw_c_ey_r[cur_slot] - ($signed(32'(node_origin_y[cur_slot])) << 16);
        bw_c_ezrel = bw_c_ez_r[cur_slot] - ($signed(32'(node_origin_z[cur_slot])) << 16);
        // dist / dt / t_next are pipelined across bram_field 3->6 (see S_BRAM_WAIT).
    end

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            fb_wr_en    <= '0;
            svo_rd_en   <= '0;
            pr_done_valid <= 1'b0;
            for (int s = 0; s < RAY_POOL_N; s++) begin
                state[s] <= S_IDLE; px[s] <= '0; py[s] <= '0; sp[s] <= '0;
                lod_cap[s] <= 1'b0;
                rs_wait[s] <= '0; post_pop[s] <= '0; q_phase[s] <= '0;
                blocked[s] <= 1'b0;
                shade_pending[s] <= 1'b0;
                bram_field[s] <= 3'd2; geom_phase[s] <= 3'd0;
            end
            q_iss_v <= 1'b0;
            q_tv[0] <= 1'b0; q_tv[1] <= 1'b0; q_tv[2] <= 1'b0;
            bram_busy <= 1'b0; bram_owner <= '0; last_grant <= '0;
            cur_slot <= '0; cur_valid <= 1'b0;
            for (int L = 0; L < SHADE_LANES; L++) begin shade_busy[L] <= 1'b0; shade_owner[L] <= '0; end
        end else begin
            // Advance the registered scheduler grant every cycle (see next_slot decl).
            cur_slot  <= next_slot;
            cur_valid <= next_valid;
            // Default pulse signals low before the state case
            fb_wr_en    <= '0;
            pr_done_valid <= 1'b0;
            // Entry-point multiply t_min*rd, registered per-slot in parallel (see te_x decl).
            for (int s = 0; s < RAY_POOL_N; s++) begin
                te_x[s] <= qmul(t_min[s], rd_x[s]);
                te_y[s] <= qmul(t_min[s], rd_y[s]);
                te_z[s] <= qmul(t_min[s], rd_z[s]);
            end

            // Tag pipe: default no issue this cycle (an issuing stage overrides
            // q_iss_v<=1'b1 below — both non-blocking, the case body wins). Shift
            // the issue tag 3 stages so q_res_v/q_res_t align with q_p* at T+4.
            q_iss_v <= 1'b0;
            q_tv[0] <= q_iss_v;   q_tt[0] <= q_iss_t;
            q_tv[1] <= q_tv[0];   q_tt[1] <= q_tt[0];
            q_tv[2] <= q_tv[1];   q_tt[2] <= q_tt[1];

            // Collector: runs EVERY cycle (regardless of scheduled slot) and
            // writes the tagged multiply's products into the destination regs,
            // then unblocks the slot (except RS1A, the first of a 2-issue pair).
            if (q_res_v) begin : collector
                automatic logic [SLOT_W-1:0] cs = q_res_t[TAGW-1:DST_W];
                automatic logic [DST_W-1:0]  cd = q_res_t[DST_W-1:0];
                unique case (cd)
                    DST_RS0:  begin rsu[cs]<=q_p0; rsv[cs]<=q_p1; end
                    DST_RS1A: begin rs_s1_a[cs]<=q_p0; rs_s1_c[cs]<=q_p1; rs_s1_e[cs]<=q_p2; end
                    DST_RS1B: begin rs_s1_b[cs]<=q_p0; rs_s1_d[cs]<=q_p1; rs_s1_f[cs]<=q_p2; end
                    DST_RS3:  begin rs_s3_dx2[cs]<=q_p0; rs_s3_dy2[cs]<=q_p1; rs_s3_dz2[cs]<=q_p2; end
                    DST_RS5:  rs_s5_y0sq[cs]   <= q_p0;
                    DST_RS6:  rs_s6_r2y0sq[cs] <= q_p0;
                    DST_RS7:  rsinv_len[cs]    <= q_p0;
                    DST_RS8:  begin rsndx[cs]<=q_p0; rsndy[cs]<=q_p1; rsndz[cs]<=q_p2; end
                    DST_RS10: begin rs_t1_x[cs]<=q_p0; rs_t1_y[cs]<=q_p1; rs_t1_z[cs]<=q_p2; end
                    DST_RS11: begin rs_r1_x[cs]<=q_p0; rs_r1_y[cs]<=q_p1; rs_r1_z[cs]<=q_p2; end
                    DST_RS12: begin rs_t2_x[cs]<=q_p0; rs_t2_y[cs]<=q_p1; rs_t2_z[cs]<=q_p2; end
                    DST_RS13: begin
                        inv_x[cs] <= rs_sign_x[cs] ? -q_p0 : q_p0;
                        inv_y[cs] <= rs_sign_y[cs] ? -q_p1 : q_p1;
                        inv_z[cs] <= rs_sign_z[cs] ? -q_p2 : q_p2;
                        rd_x[cs] <= rsndx[cs]; rd_y[cs] <= rsndy[cs]; rd_z[cs] <= rsndz[cs];
                        sp[cs] <= '0;
                    end
                    DST_SLAB0: begin rs_tx0_r[cs]<=q_p0; rs_ty0_r[cs]<=q_p1; rs_tz0_r[cs]<=q_p2; end
                    DST_SLAB1: begin rs_tx1_r[cs]<=q_p0; rs_ty1_r[cs]<=q_p1; rs_tz1_r[cs]<=q_p2; end
                    DST_GDT:   begin bw_dtx_r[cs]<=q_p0;   bw_dty_r[cs]<=q_p1;   bw_dtz_r[cs]<=q_p2;   end
                    DST_GPROD: begin bw_prodx_r[cs]<=q_p0; bw_prody_r[cs]<=q_p1; bw_prodz_r[cs]<=q_p2; end
                    default: ;
                endcase
                // unblock the slot, except the first of a 2-issue pair which keeps
                // running to issue the second and blocks on it instead:
                //   DST_RS1A  -> blocks on DST_RS1B
                //   DST_SLAB0 -> blocks on DST_SLAB1
                //   DST_GDT   -> blocks on DST_GPROD (the geometry's blocking multiply)
                if (cd != DST_RS1A && cd != DST_SLAB0 && cd != DST_GDT) blocked[cs] <= 1'b0;
            end

            // Rotate round-robin priority past the executed slot.
            if (cur_valid) last_grant <= cur_slot;

            // -----------------------------------------------------------------
            // Launch-init: runs every cycle outside the grant gate, keyed on
            // pr_launch_slot. pixel_reorder launches the next raster pixel into a
            // free (S_IDLE) slot; this initialises its ray. The launch slot is
            // always free and cur_slot is always mid-ray, so the two write sites
            // never target the same slot in the same cycle.
            // -----------------------------------------------------------------
            if (pr_launch_valid) begin
                px[pr_launch_slot]       <= pr_launch_px;
                py[pr_launch_slot]       <= pr_launch_py;
                sp[pr_launch_slot]       <= '0;
                rs_wait[pr_launch_slot]  <= '0;
                post_pop[pr_launch_slot] <= '0;
                q_phase[pr_launch_slot]  <= '0;
                blocked[pr_launch_slot]  <= 1'b0;
                state[pr_launch_slot]    <= S_RAY_SETUP;
            end

            // -----------------------------------------------------------------
            // Shading arbiter register + collector (outside the grant gate).
            // shade_grant requires !shade_busy and shade_done requires it was busy,
            // so they fire on mutually-exclusive cycles. Inert when SHADE_MODE=0.
            // -----------------------------------------------------------------
            for (int L = 0; L < SHADE_LANES; L++) begin
                if (shade_grant[L]) begin
                    // take lane L for its granted slot (slots are distinct across lanes)
                    shade_busy[L]                      <= 1'b1;
                    shade_owner[L]                     <= shade_grant_slot[L];
                    shade_pending[shade_grant_slot[L]] <= 1'b0;
                end
                if (SHADE_MODE && shade_done[L]) begin
                    // lane L finished -> write its owner's pixel + free the lane
                    pixel_color[shade_owner[L]] <= shade_pixel_color[L];
                    state[shade_owner[L]]       <= S_WRITE_PIXEL;
                    shade_busy[L]               <= 1'b0;
                end
            end

            // Execute the registered active slot. Guard with !blocked: the grant is
            // registered a cycle before execution, so a slot that issued a blocking
            // multiply last cycle must not run — this catches that 1-cycle stale grant.
            if (cur_valid && !blocked[cur_slot]) begin
            unique case (state[cur_slot])

            // -----------------------------------------------------------------
            // Handled by the launch-init block above; never granted (ready[]
            // excludes S_IDLE). No-op kept for case completeness.
            S_IDLE: ;

            // -----------------------------------------------------------------
            // S_RAY_SETUP: compute normalised ray direction from pixel + camera.
            // 15-stage registered pipeline (rs_wait 0->14); stages 0-13 each do at
            // most one qmul, stage 14 is the pure state transition (no DSPs, minimal
            // path) so the state write never shares a cycle with a qmul.
            S_RAY_SETUP: begin
                begin
                    // Primary mode: 14-stage pipeline (SHADOW_MODE=0 only; shadow
                    // branch removed — this module is instantiated primary-only).
                    case (rs_wait[cur_slot])
                        // ---- Screen-space ray direction: raw_dir = fwd + u*right - v*up ----
                        // u,v are the pixel's offset from screen centre scaled by cam_scale
                        // (u = (px - IMG_W/2)*scale, v = (py - IMG_H/2)*scale; the centre
                        // CENTER_X_Q/CENTER_Y_Q is derived from the resolution params).
                        // Stage 0 forms u,v; stage 1 forms the six u*right / v*up products;
                        // stage 2 sums them into raw_dir; stage 3 squares raw_dir for len2.
                        // All multiplies use the shared bank.
                        4'd0: begin  // u = (px - IMG_W/2)*scale ; v = (py - IMG_H/2)*scale
                            ro_x[cur_slot] <= cam_pos_x; ro_y[cur_slot] <= cam_pos_y; ro_z[cur_slot] <= cam_pos_z;
                            q_a0 <= $signed({1'b0, px[cur_slot], 16'd0}) - CENTER_X_Q; q_b0 <= cam_scale;
                            q_a1 <= $signed({1'b0, py[cur_slot], 16'd0}) - CENTER_Y_Q; q_b1 <= cam_scale;
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS0};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd1: begin  // six products over 2 issue cycles (6 muls > 3 lanes)
                            // q_phase reused only as a 0/1 issue-substep flag here.
                            if (q_phase[cur_slot] == 0) begin       // issue A: a/c/e = u * cam_right_{x,y,z}
                                q_a0 <= rsu[cur_slot]; q_b0 <= cam_right_x;
                                q_a1 <= rsu[cur_slot]; q_b1 <= cam_right_y;
                                q_a2 <= rsu[cur_slot]; q_b2 <= cam_right_z;
                                q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS1A};
                                q_phase[cur_slot] <= 3'd1;          // next run: issue B (slot NOT blocked)
                            end else begin                           // issue B: b/d/f = v * cam_up_{x,y,z}
                                q_a0 <= rsv[cur_slot]; q_b0 <= cam_up_x;
                                q_a1 <= rsv[cur_slot]; q_b1 <= cam_up_y;
                                q_a2 <= rsv[cur_slot]; q_b2 <= cam_up_z;
                                q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS1B};
                                q_phase[cur_slot] <= '0;
                                blocked[cur_slot] <= 1'b1;           // block until RS1B collected
                                rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                            end
                        end
                        4'd2: begin  // raw_dir = fwd + u*right - v*up  (adds only)
                            rsdx[cur_slot]    <= cam_fwd_x + rs_s1_a[cur_slot] - rs_s1_b[cur_slot];
                            rsdy[cur_slot]    <= cam_fwd_y + rs_s1_c[cur_slot] - rs_s1_d[cur_slot];
                            rsdz[cur_slot]    <= cam_fwd_z + rs_s1_e[cur_slot] - rs_s1_f[cur_slot];
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd3: begin  // dx2/dy2/dz2 = raw_dir^2  (-> len2)
                            q_a0 <= rsdx[cur_slot]; q_b0 <= rsdx[cur_slot];
                            q_a1 <= rsdy[cur_slot]; q_b1 <= rsdy[cur_slot];
                            q_a2 <= rsdz[cur_slot]; q_b2 <= rsdz[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS3};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd4: begin  // len2 = dx2+dy2+dz2 (3-way add only; the NR seed is
                            // deferred to stage 5 to keep one op per cycle behind the RAM read).
                            rslen2[cur_slot]   <= rs_s3_dx2[cur_slot] + rs_s3_dy2[cur_slot] + rs_s3_dz2[cur_slot];
                            rs_wait[cur_slot]  <= rs_wait[cur_slot] + 1'b1;
                        end
                        // ---- Fast inverse square root: inv_len = 1 / |raw_dir| ----
                        // One Newton-Raphson rsqrt step on len2 = |raw_dir|^2, using the
                        // linear seed y0 = 1.5 - len2/2 (valid since raw_dir ~ unit):
                        //     y0sq    = y0^2
                        //     r2y0sq  = len2 * y0^2
                        //     inv_len = y0 * (1.5 - r2y0sq/2)   -> ~1/sqrt(len2)
                        // Stage 8 then normalizes: nd = raw_dir * inv_len. 1.5_Q16.16 = 0001_8000.
                        4'd5: begin  // NR seed y0 = 1.5 - len2/2, then rsqrt: y0sq = y0^2.
                            // rs_s4_y0 (needed again at stage 7) is produced here.
                            rs_s4_y0[cur_slot] <= 32'sh0001_8000 - (rslen2[cur_slot] >>> 1);
                            q_a0 <= 32'sh0001_8000 - (rslen2[cur_slot] >>> 1);
                            q_b0 <= 32'sh0001_8000 - (rslen2[cur_slot] >>> 1);
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS5};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd6: begin  // rsqrt: r2y0sq = len2 * y0^2
                            q_a0 <= rslen2[cur_slot]; q_b0 <= rs_s5_y0sq[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS6};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd7: begin  // rsqrt: inv_len = y0 * (1.5 - r2y0sq/2)
                            q_a0 <= rs_s4_y0[cur_slot]; q_b0 <= 32'sh0001_8000 - (rs_s6_r2y0sq[cur_slot] >>> 1);
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS7};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd8: begin  // normalize: nd = raw_dir * inv_len   (3 lanes)
                            q_a0 <= rsdx[cur_slot]; q_b0 <= rsinv_len[cur_slot];
                            q_a1 <= rsdy[cur_slot]; q_b1 <= rsinv_len[cur_slot];
                            q_a2 <= rsdz[cur_slot]; q_b2 <= rsinv_len[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS8};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
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
                        // 2.0_Q16.16 = 0002_0000.
                        4'd10: begin  // N-R pass 1: t1 = |x| * r0   (residual)
                            q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r0_x[cur_slot];
                            q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r0_y[cur_slot];
                            q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r0_z[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS10};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd11: begin  // N-R pass 1: r1 = r0 * (2 - t1)   (refined estimate)
                            q_a0 <= rs_r0_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t1_x[cur_slot];
                            q_a1 <= rs_r0_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t1_y[cur_slot];
                            q_a2 <= rs_r0_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t1_z[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS11};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd12: begin  // N-R pass 2: t2 = |x| * r1   (residual)
                            q_a0 <= rs_xabs_x[cur_slot]; q_b0 <= rs_r1_x[cur_slot];
                            q_a1 <= rs_xabs_y[cur_slot]; q_b1 <= rs_r1_y[cur_slot];
                            q_a2 <= rs_xabs_z[cur_slot]; q_b2 <= rs_r1_z[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS12};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                        end
                        4'd13: begin  // N-R pass 2: inv = sign(x) * r1 * (2 - t2)
                            // issue only; the collector does the inv/rd/sp writeback (DST_RS13).
                            q_a0 <= rs_r1_x[cur_slot]; q_b0 <= 32'sh0002_0000 - rs_t2_x[cur_slot];
                            q_a1 <= rs_r1_y[cur_slot]; q_b1 <= 32'sh0002_0000 - rs_t2_y[cur_slot];
                            q_a2 <= rs_r1_z[cur_slot]; q_b2 <= 32'sh0002_0000 - rs_t2_z[cur_slot];
                            q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_RS13};
                            blocked[cur_slot] <= 1'b1;
                            rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;  // -> 14
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
                // Ray-vs-world-box slab intersection. Slab times come from the shared
                // multiplier bank via the slot-tagged issue/block/collector. rs_wait
                // sequence (0 on entry):
                //   0 = issue SLAB0 = qmul(-ro, inv)        (not blocked)
                //   1 = issue SLAB1 = qmul(WORLD_Q-ro, inv) (block; advance to sort)
                //   2 = sort each axis pair (lo=min, hi=max)
                //   3 = t_enter = max(lo), t_exit = min(hi)
                //   4 = miss check + clamp t_min + set node + transition
                case (rs_wait[cur_slot])
                    4'd0: begin    // issue SLAB0 = qmul(-ro, inv)
                        q_a0 <= -ro_x[cur_slot]; q_b0 <= inv_x[cur_slot];
                        q_a1 <= -ro_y[cur_slot]; q_b1 <= inv_y[cur_slot];
                        q_a2 <= -ro_z[cur_slot]; q_b2 <= inv_z[cur_slot];
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_SLAB0};
                        rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                    end
                    4'd1: begin    // issue SLAB1 = qmul(WORLD_Q-ro, inv); block
                        q_a0 <= WORLD_Q - ro_x[cur_slot]; q_b0 <= inv_x[cur_slot];
                        q_a1 <= WORLD_Q - ro_y[cur_slot]; q_b1 <= inv_y[cur_slot];
                        q_a2 <= WORLD_Q - ro_z[cur_slot]; q_b2 <= inv_z[cur_slot];
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_SLAB1};
                        blocked[cur_slot] <= 1'b1;
                        rs_wait[cur_slot] <= 4'd2;
                    end
                    // Sort each axis pair -> per-axis (lo=min, hi=max)
                    4'd2: begin
                        rs_lo_x[cur_slot] <= (rs_tx0_r[cur_slot] > rs_tx1_r[cur_slot]) ? rs_tx1_r[cur_slot] : rs_tx0_r[cur_slot];
                        rs_hi_x[cur_slot] <= (rs_tx0_r[cur_slot] > rs_tx1_r[cur_slot]) ? rs_tx0_r[cur_slot] : rs_tx1_r[cur_slot];
                        rs_lo_y[cur_slot] <= (rs_ty0_r[cur_slot] > rs_ty1_r[cur_slot]) ? rs_ty1_r[cur_slot] : rs_ty0_r[cur_slot];
                        rs_hi_y[cur_slot] <= (rs_ty0_r[cur_slot] > rs_ty1_r[cur_slot]) ? rs_ty0_r[cur_slot] : rs_ty1_r[cur_slot];
                        rs_lo_z[cur_slot] <= (rs_tz0_r[cur_slot] > rs_tz1_r[cur_slot]) ? rs_tz1_r[cur_slot] : rs_tz0_r[cur_slot];
                        rs_hi_z[cur_slot] <= (rs_tz0_r[cur_slot] > rs_tz1_r[cur_slot]) ? rs_tz0_r[cur_slot] : rs_tz1_r[cur_slot];
                        rs_wait[cur_slot] <= 4'd3;
                    end
                    // t_enter = max(lo_x,lo_y,lo_z); t_exit = min(hi_x,hi_y,hi_z)
                    4'd3: begin
                        rs_enter_r[cur_slot] <= (rs_lo_x[cur_slot] > rs_lo_y[cur_slot]) ? ((rs_lo_x[cur_slot] > rs_lo_z[cur_slot]) ? rs_lo_x[cur_slot] : rs_lo_z[cur_slot])
                                                          : ((rs_lo_y[cur_slot] > rs_lo_z[cur_slot]) ? rs_lo_y[cur_slot] : rs_lo_z[cur_slot]);
                        rs_exit_r[cur_slot]  <= (rs_hi_x[cur_slot] < rs_hi_y[cur_slot]) ? ((rs_hi_x[cur_slot] < rs_hi_z[cur_slot]) ? rs_hi_x[cur_slot] : rs_hi_z[cur_slot])
                                                          : ((rs_hi_y[cur_slot] < rs_hi_z[cur_slot]) ? rs_hi_y[cur_slot] : rs_hi_z[cur_slot]);
                        rs_wait[cur_slot]    <= 4'd4;
                    end
                    // Miss check (unclamped t_enter > t_exit) + clamp t_min; set node + state.
                    // Clamp t_min to 0: inside the world box t_enter<0; starting from t=0
                    // gives correct cx/cy/cz (t_next unaffected).
                    default: begin   // 4'd4
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
                // Take ownership of the single BRAM read port for this node read.
                bram_busy   <= 1'b1;
                bram_owner  <= cur_slot;
                bram_field[cur_slot]  <= 3'd1;   // wide read: 1=latency wait, 0=latch, 2=done
                geom_phase[cur_slot]  <= 3'd0;   // start the (decoupled) geometry pipeline
                svo_rd_en   <= 1'b1;
                svo_rd_node <= node_idx[cur_slot][11:0];
                state[cur_slot]       <= S_BRAM_WAIT;
            end

            // -----------------------------------------------------------------
            // Two independent pipelines run here: the wide node read (bram_field)
            // and the DDA-step geometry (geom_phase). The state exits when both are
            // done.
            S_BRAM_WAIT: begin
                // ===== READ pipeline (bram_field): wide whole-node fetch =====
                // svo_bram_wide returns the whole 8-word node on svo_rd_wide with 1-cycle
                // latency: 1 = absorb the latency, 0 = latch all 8 words at once, 2 = done.
                // svo_rd_wide[w*32 +: 32] == node word w (w0=bitmask, w1-4=child pairs,
                // w5-6=block bytes, w7=LOD representative block).
                unique case (bram_field[cur_slot])
                    3'd1: bram_field[cur_slot] <= 3'd0;   // wait: data ready next cycle
                    3'd0: begin                            // latch the whole node in one cycle
                        r_bitmask[cur_slot] <= svo_rd_wide[15:0];
                        r_child[cur_slot][0] <= svo_rd_wide[ 32 +: 16]; r_child[cur_slot][1] <= svo_rd_wide[ 48 +: 16];
                        r_child[cur_slot][2] <= svo_rd_wide[ 64 +: 16]; r_child[cur_slot][3] <= svo_rd_wide[ 80 +: 16];
                        r_child[cur_slot][4] <= svo_rd_wide[ 96 +: 16]; r_child[cur_slot][5] <= svo_rd_wide[112 +: 16];
                        r_child[cur_slot][6] <= svo_rd_wide[128 +: 16]; r_child[cur_slot][7] <= svo_rd_wide[144 +: 16];
                        r_block[cur_slot][0] <= svo_rd_wide[160 +: 8];  r_block[cur_slot][1] <= svo_rd_wide[168 +: 8];
                        r_block[cur_slot][2] <= svo_rd_wide[176 +: 8];  r_block[cur_slot][3] <= svo_rd_wide[184 +: 8];
                        r_block[cur_slot][4] <= svo_rd_wide[192 +: 8];  r_block[cur_slot][5] <= svo_rd_wide[200 +: 8];
                        r_block[cur_slot][6] <= svo_rd_wide[208 +: 8];  r_block[cur_slot][7] <= svo_rd_wide[216 +: 8];
                        r_dom_block[cur_slot] <= svo_rd_wide[224 +: 8];  // word 7: LOD representative block
                        svo_rd_en <= 1'b0;
                        bram_busy <= 1'b0;              // release the read port as soon as the node is
                        bram_field[cur_slot] <= 3'd2;   // latched, so other slots can read while this slot
                        // finishes its port-free geometry — the overlap that wins throughput. Safe: no
                        // other slot can start a read while this one owns the port, so svo_rd_node/_en
                        // hold and the wide data stays stable; the geometry never touches the port.
                    end
                    default: ;   // 3'd2: done — port already released; just finishing geometry
                endcase

                // ===== GEOMETRY pipeline (geom_phase): DDA-step setup, independent of the read =====
                // Phase map:
                //   0 register entry pt | 1 capture cell+exrel | 2 dist + issue GDT |
                //   3 issue GPROD (block) | 4 commit (after GPROD collector unblocks)
                // te_* (hence bw_c_e*) and node_* are valid on phase 0, so dt/prod issue early
                // enough to hide the shared bank latency (QCOL=4) before the commit.
                unique case (geom_phase[cur_slot])
                    3'd0: begin   // register the entry point (ro+te) to keep the 32-bit add off the
                        // cell-index path. bw_c_e* is stable across the read, so the index/exrel
                        // computed from bw_c_e*_r at phase 1 is value-identical.
                        bw_c_ex_r[cur_slot] <= bw_c_ex;
                        bw_c_ey_r[cur_slot] <= bw_c_ey;
                        bw_c_ez_r[cur_slot] <= bw_c_ez;
                        geom_phase[cur_slot] <= 3'd1;
                    end
                    3'd1: begin   // capture child cell + entry-rel + node_half
                        bw_cx_r[cur_slot]    <= bw_c_cx;    bw_cy_r[cur_slot]    <= bw_c_cy;    bw_cz_r[cur_slot]    <= bw_c_cz;
                        bw_exrel_r[cur_slot] <= bw_c_exrel; bw_eyrel_r[cur_slot] <= bw_c_eyrel; bw_ezrel_r[cur_slot] <= bw_c_ezrel;
                        bw_nhq_r[cur_slot]   <= bw_c_nhq;
                        geom_phase[cur_slot] <= 3'd2;
                    end
                    3'd2: begin   // dist to next midplane (no qmul) + issue dt = node_half*|inv|.
                        // Use rd_*[31] (ray-dir sign) for the direction, not step_*[2]: the two are
                        // equal by construction (step = rd[31]?-1:+1) but rd is the sign that stays
                        // correct on silicon at N>1.
                        bw_distx_r[cur_slot] <= (!rd_x[cur_slot][31]) ? (bw_cx_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_exrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_exrel_r[cur_slot]))
                                                   : (bw_cx_r[cur_slot][0] ? (bw_exrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_exrel_r[cur_slot]);
                        bw_disty_r[cur_slot] <= (!rd_y[cur_slot][31]) ? (bw_cy_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_eyrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_eyrel_r[cur_slot]))
                                                   : (bw_cy_r[cur_slot][0] ? (bw_eyrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_eyrel_r[cur_slot]);
                        bw_distz_r[cur_slot] <= (!rd_z[cur_slot][31]) ? (bw_cz_r[cur_slot][0] ? ((bw_nhq_r[cur_slot]<<<1)-bw_ezrel_r[cur_slot]) : (bw_nhq_r[cur_slot]-bw_ezrel_r[cur_slot]))
                                                   : (bw_cz_r[cur_slot][0] ? (bw_ezrel_r[cur_slot]-bw_nhq_r[cur_slot]) : bw_ezrel_r[cur_slot]);
                        q_a0 <= bw_nhq_r[cur_slot]; q_b0 <= qabs(inv_x[cur_slot]);
                        q_a1 <= bw_nhq_r[cur_slot]; q_b1 <= qabs(inv_y[cur_slot]);
                        q_a2 <= bw_nhq_r[cur_slot]; q_b2 <= qabs(inv_z[cur_slot]);
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_GDT};
                        geom_phase[cur_slot] <= 3'd3;
                    end
                    3'd3: begin   // issue prod = dist*|inv|, then block on it. The slot is
                        // descheduled for the QCOL multiply latency (other rays run); the GPROD
                        // collector writes bw_prod_* and unblocks it at phase 4 (the commit).
                        q_a0 <= bw_distx_r[cur_slot]; q_b0 <= qabs(inv_x[cur_slot]);
                        q_a1 <= bw_disty_r[cur_slot]; q_b1 <= qabs(inv_y[cur_slot]);
                        q_a2 <= bw_distz_r[cur_slot]; q_b2 <= qabs(inv_z[cur_slot]);
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_GPROD};
                        blocked[cur_slot] <= 1'b1;
                        geom_phase[cur_slot] <= 3'd4;
                    end
                    default: ;   // phase 4 = commit; reached once GPROD unblocks
                endcase

                // ===== EXIT / COMMIT: read done (bram_field==2) AND geometry done (geom_phase==4) =====
                if (bram_field[cur_slot] == 3'd2 && geom_phase[cur_slot] == 3'd4) begin
                    // The read port was already released at the latch — do NOT touch
                    // bram_busy/svo_rd_en here: another slot may now own the port.
                    bitmask[cur_slot]   <= r_bitmask[cur_slot];
                    // dt from the pipelined qmul; correct in both fresh-descend and
                    // post-pop cases (bw_nhq_r captured the restored node_half).
                    dt_x[cur_slot] <= bw_dtx_r[cur_slot]; dt_y[cur_slot] <= bw_dty_r[cur_slot]; dt_z[cur_slot] <= bw_dtz_r[cur_slot];
                    if (post_pop[cur_slot]) begin
                        // r_child[]/r_block[] now hold the parent node's data.
                        // cx/cy/cz and t_next were already restored by S_POP_STACK;
                        // the geometry pipeline output is ignored here (only dt is used).
                        post_pop[cur_slot] <= 1'b0;
                        state[cur_slot]    <= S_EMPTY;
                    end else begin
                        cx[cur_slot]       <= bw_cx_r[cur_slot]; cy[cur_slot] <= bw_cy_r[cur_slot]; cz[cur_slot] <= bw_cz_r[cur_slot];
                        t_next_x[cur_slot] <= t_min[cur_slot] + bw_prodx_r[cur_slot];   // geometry stage: t_min + dist*|inv|
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
                    2'b01:   if (sp[cur_slot] >= max_depth) begin
                                 lod_cap[cur_slot] <= 1'b1;       // force solid at this level
                                 state[cur_slot]   <= S_SOLID;
                             end else
                                 state[cur_slot]   <= S_MIXED;
                    default: state[cur_slot] <= S_EMPTY;
                endcase
            end

            // -----------------------------------------------------------------
            S_EMPTY: begin
                // A DDA step inside a 2x2x2 node moves to the adjacent cell, flipping the
                // cell bit (0<->1). ~c[0] (not c+/-1) keeps cx/cy/cz strictly 0/1, so the
                // bit-0 out-of-bounds check (rd[31]^c[0]) stays valid. Pop-vs-continue uses
                // the ray-dir sign rd_*[31] directly (= step but reliable on silicon at N>1).
                if (t_next_x[cur_slot] <= t_next_y[cur_slot] && t_next_x[cur_slot] <= t_next_z[cur_slot]) begin
                    cx[cur_slot]       <= {5'd0, ~cx[cur_slot][0]};
                    t_min[cur_slot]    <= t_next_x[cur_slot]; t_next_x[cur_slot] <= t_next_x[cur_slot] + dt_x[cur_slot];
                    em_face  = 2'd0; em_fsign = ~rd_x[cur_slot][31];     // outward normal = opposite of ray dir
                    state[cur_slot]    <= (rd_x[cur_slot][31] ^ cx[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else if (t_next_y[cur_slot] <= t_next_z[cur_slot]) begin
                    cy[cur_slot]       <= {5'd0, ~cy[cur_slot][0]};
                    t_min[cur_slot]    <= t_next_y[cur_slot]; t_next_y[cur_slot] <= t_next_y[cur_slot] + dt_y[cur_slot];
                    em_face  = 2'd1; em_fsign = ~rd_y[cur_slot][31];
                    state[cur_slot]    <= (rd_y[cur_slot][31] ^ cy[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end else begin
                    cz[cur_slot]       <= {5'd0, ~cz[cur_slot][0]};
                    t_min[cur_slot]    <= t_next_z[cur_slot]; t_next_z[cur_slot] <= t_next_z[cur_slot] + dt_z[cur_slot];
                    em_face  = 2'd2; em_fsign = ~rd_z[cur_slot][31];
                    state[cur_slot]    <= (rd_z[cur_slot][31] ^ cz[cur_slot][0]) ? S_POP_STACK : S_CHECK_CHILD;
                end
                hit_face[cur_slot]        <= em_face;
                hit_face_sign_r[cur_slot] <= em_fsign;
            end

            // -----------------------------------------------------------------
            S_SOLID: begin
                t_hit[cur_slot]        <= t_min[cur_slot];
                // Depth-cap LOD: colour the forced-solid node with its build-time
                // representative (word 7, a real leaf colour from deeper in the tree),
                // falling back to rep_block_w only if word 7 is somehow 0.
                block_id_hit[cur_slot] <= lod_cap[cur_slot]
                    ? (r_dom_block[cur_slot] != 8'd0 ? r_dom_block[cur_slot] : rep_block_w)
                    : r_block[cur_slot][cidx[cur_slot]];
                lod_cap[cur_slot]      <= 1'b0;
                // Hit point = entry point (ro + te) at the current t_min.
                hit_px_r[cur_slot]     <= bw_c_ex;
                hit_py_r[cur_slot]     <= bw_c_ey;
                hit_pz_r[cur_slot]     <= bw_c_ez;
                if (SHADE_MODE) begin
                    // hand off to shading via the arbiter: store the hit, raise pending,
                    // park in S_WAIT_SHADE.
                    shade_is_miss_r[cur_slot] <= 1'b0;
                    shade_pending[cur_slot]   <= 1'b1;
                    state[cur_slot]           <= S_WAIT_SHADE;
                end else begin
                    // Phase 1: white hit
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
                    // dt is recomputed in S_BRAM_WAIT from the restored node_half
                    // (post_pop path), so no qmul is needed here.
                    cx[cur_slot]            <= stk_cx       [cur_slot][sp[cur_slot]-1];
                    cy[cur_slot]            <= stk_cy       [cur_slot][sp[cur_slot]-1];
                    cz[cur_slot]            <= stk_cz       [cur_slot][sp[cur_slot]-1];
                    node_half[cur_slot]     <= stk_node_half[cur_slot][sp[cur_slot]-1];
                    node_origin_x[cur_slot] <= stk_orig_x   [cur_slot][sp[cur_slot]-1];
                    node_origin_y[cur_slot] <= stk_orig_y   [cur_slot][sp[cur_slot]-1];
                    node_origin_z[cur_slot] <= stk_orig_z   [cur_slot][sp[cur_slot]-1];
                    // Re-read BRAM to recover r_child[]/r_block[] for the restored
                    // parent node. post_pop suppresses cx/cy/cz recomputation in
                    // S_BRAM_WAIT so the stack-restored DDA state is kept.
                    post_pop[cur_slot] <= 1'b1;
                    state[cur_slot] <= S_ENTER_NODE;
                end
            end

            // -----------------------------------------------------------------
            S_MISS: begin
                if (SHADE_MODE) begin
                    // hand off as a miss via the arbiter: raise pending, park in S_WAIT_SHADE.
                    shade_is_miss_r[cur_slot] <= 1'b1;
                    shade_pending[cur_slot]   <= 1'b1;
                    state[cur_slot]           <= S_WAIT_SHADE;
                end else begin
                    // Phase 1: sky colour
                    pixel_color[cur_slot] <= sky_color;
                    state[cur_slot]       <= S_WRITE_PIXEL;
                end
            end

            // -----------------------------------------------------------------
            // The shade collector (outside the grant gate) moves the owning slot
            // to S_WRITE_PIXEL on shade_done; a parked slot is excluded from ready
            // (never granted), so this arm is just a no-op for case completeness.
            S_WAIT_SHADE: ;

            // -----------------------------------------------------------------
            S_WRITE_PIXEL: begin
                // Signal this slot's ray finished; pixel_reorder retires the colour
                // on AXIS (in raster order) and relaunches the slot. One-cycle pulse.
                pr_done_valid <= 1'b1;
                pr_done_slot  <= cur_slot;
                pr_done_color <= pixel_color[cur_slot];
                state[cur_slot] <= S_IDLE;     // slot free; pixel_reorder retires + relaunches
            end

            // -----------------------------------------------------------------
            // Unused: pixel advance + framing are pixel_reorder's job. Enum value
            // kept to preserve the FSM state encoding.
            S_NEXT_PIXEL: ;

            endcase
            end  // if (cur_valid)
        end
    end

endmodule
