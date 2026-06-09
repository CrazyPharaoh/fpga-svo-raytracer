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
//edit test
`timescale 1ns/1ps
module svo_traversal_mr #(
    parameter int RAY_POOL_N  = 1,   // M1: 1 = single-ray (bit-identical); >1 = interleaved pool (unused this revision)
    parameter int IMG_W       = 320,
    parameter int IMG_H       = 240,
    parameter int STACK_DEPTH = 12,
    parameter int WORLD_SIZE  = 64,
    parameter bit SHADOW_MODE = 0,   // 1 = shadow-ray instance
    parameter bit SHADE_MODE  = 0,   // 1 = hand off to shading_pipeline
    parameter int SHADE_LANES = 2    // # of parallel shading pipelines (SHADE_MODE=1).
                                     // =1 is bit-identical to the old single-lane shader.
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

    // Runtime traversal depth cap; MIXED-at-cap -> solid (LOD)
    input  logic [3:0]  max_depth,

    // SVO BRAM read port
    output logic [11:0]  svo_rd_node,   // node index (M2 wide read)
    input  logic [255:0] svo_rd_wide,   // whole node {w7..w0} returned in one cycle
    output logic         svo_rd_en,

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
    output logic        frame_done,   // also used as "any_hit" pulse in SHADOW_MODE
    output logic        any_hit,      // SHADOW_MODE: 1 when first solid hit found

    // Debug: readable via AXI at run-time to diagnose hangs
    output logic [3:0]  dbg_state,    // current FSM state integer (S_WRITE_PIXEL=12)
    output logic [3:0]  dbg_rs_wait,  // rs_wait counter (0-15); stuck≠advancing→hang
    output logic [8:0]  dbg_px,       // current pixel X
    output logic [7:0]  dbg_py,       // current pixel Y
    output logic        dbg_tvalid,   // axis_tvalid: IP is outputting a pixel
    output logic        dbg_tready,   // axis_tready: VDMA is accepting the pixel
    output logic [31:0] dbg_mr,       // multi-ray internals (see packing below)
    // --- ILA probes (marked mark_debug in top.sv) -------------------------------
    // Expose the executing slot + two of ITS per-slot ray values, so an ILA capture
    // can show whether slot N is running with slot M's data (cross-slot corruption,
    // the suspected N>1 hardware bug). 2-bit slot covers RAY_POOL_N up to 4.
    output logic [1:0]  dbg_cur_slot, // currently-executing slot
    output logic [31:0] dbg_d0,       // {node_idx[15:0], r_bitmask[15:0]} — node read by HW
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

    // -------------------------------------------------------------------------
    // Round-robin-over-ready scheduler. Each cycle it picks one ready slot to
    // advance through the shared datapath. A slot is ready when it is mid-ray,
    // not blocked on a multiply, and (if it wants to START a BRAM read) the
    // single read port is free or already owned by it.
    // At RAY_POOL_N=1 this reduces to "advance slot 0 whenever it is mid-ray
    // and unblocked" — bit-identical to the old !blocked[cur_slot] gate.
    // -------------------------------------------------------------------------
    logic                  bram_busy;     // a slot currently owns the read port
    logic [SLOT_W-1:0]     bram_owner;

    // Shading arbiter (SHADE_MODE=1 only). The single shading pipeline serves one
    // ray at a time; slots that hit/miss raise shade_pending and park in
    // S_WAIT_SHADE. The arbiter grants one pending slot when the shader is free,
    // drives the shade_* outputs from that slot's stored hit info, asserts
    // shade_start, and on shade_done writes the owner's pixel + frees the shader.
    // Pattern mirrors bram_busy/bram_owner. Inert when SHADE_MODE=0 (Phase 1).
    logic                  shade_busy  [0:SHADE_LANES-1];  // each lane's shading pipeline in use
    logic [SLOT_W-1:0]     shade_owner [0:SHADE_LANES-1];  // slot each lane is shading
    logic                  shade_pending [0:RAY_POOL_N-1];  // slot wants shading
    logic                  shade_is_miss_r [0:RAY_POOL_N-1]; // per-slot: hit(0)/miss(1)

    logic [RAY_POOL_N-1:0] ready;
    always_comb begin
        for (int s = 0; s < RAY_POOL_N; s++) begin
            ready[s] = (state[s] != S_IDLE) && (state[s] != S_WAIT_SHADE) && !blocked[s];
            // Atomic BRAM read. The wide read presents one node address for its 1-cycle
            // latency, so the owning slot keeps the read port (bram_busy) until it latches
            // the whole node. While a read is in progress no OTHER slot may run; the owner
            // keeps the turn until it releases the port. (Task 2a releases at exit, holding
            // the port through the geometry — cycle-identical; Task 2b will release right
            // after the latch so other slots' reads overlap this slot's geometry.)
            if (bram_busy && (s[SLOT_W-1:0] != bram_owner))
                ready[s] = 1'b0;
        end
    end

    logic                  grant_valid;
    logic [SLOT_W-1:0]     grant_slot;
    logic [SLOT_W-1:0]     last_grant;
    generate
        if (RAY_POOL_N == 1) begin : g_sched_n1
            // ray_scheduler's ports are [$clog2(1)-1:0] = [-1:0] (zero/neg width)
            // at N=1, so bypass it. grant slot 0 whenever it is ready.
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
    // REGISTERED scheduler grant. cur_slot is now a REGISTER (not the combinational
    // grant), so every per-slot RAM read starts from a register at t=0 instead of the
    // ~6 ns state->ready->grant->fanout(fo=2848) decode that was gating the whole
    // datapath (the timing wall). The scheduler's own state->ready->grant->register
    // path becomes a self-contained reg-to-reg path that fits in 10 ns.
    //
    // BRAM-read atomicity: the wide node read needs the owner to hold the turn for its
    // 1-2 read cycles. bram_busy is registered (lags the S_ENTER_NODE that sets it by a
    // cycle), so cover both edges:
    //   mid-read (bram_busy)                 -> stick with bram_owner
    //   read about to start (in S_ENTER_NODE) -> stick with the same slot
    //   otherwise                            -> take the scheduler's grant
    logic              cur_valid;   // cur_slot holds a slot worth executing this cycle
    wire starting_read = cur_valid && (state[cur_slot] == S_ENTER_NODE);
    wire [SLOT_W-1:0] next_slot  = bram_busy     ? bram_owner
                                 : starting_read ? cur_slot
                                 :                 grant_slot;
    wire              next_valid = bram_busy || starting_read || grant_valid;

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
    // ILA probes: executing slot + the NODE DATA it's reading (to catch terrain nodes
    // being read as empty at N>1).  d0 = {node_idx[15:0], bitmask[15:0]} — compare the
    // read bitmask against the known SVO; d1 = stack/child position.
    assign dbg_cur_slot = 2'(cur_slot);
    assign dbg_d0       = {node_idx[cur_slot], r_bitmask[cur_slot]};
    // d1 now probes the DDA step direction vs the true ray-dir sign, to confirm the
    // step-sign corruption: bits[15:13]=rd sign(x,y,z), [12:10]=step sign(x,y,z),
    // [9:6]=sp, [5:3]=cidx, [2:0]=cell(x,y,z). If step sign != rd sign -> step is wrong.
    assign dbg_d1       = {16'd0,
                           rd_x[cur_slot][31],  rd_y[cur_slot][31],  rd_z[cur_slot][31],
                           step_x[cur_slot][2], step_y[cur_slot][2], step_z[cur_slot][2],
                           sp[cur_slot], cidx[cur_slot],
                           cx[cur_slot][0], cy[cur_slot][0], cz[cur_slot][0]};

    // Debug word (read via AXI 0x80) to localise hangs:
    //   [15:0]  state[0..3]  (4 bits each; only first RAY_POOL_N valid)
    //   [16]    grant_valid   [17] bram_busy   [18] shade_busy
    //   [23:20] ready vector  [25:24] bram_owner  [27:26] shade_owner
    // Packed combinationally, then REGISTERED into dbg_mr so the long route from
    // deep-in-the-core slot state out to the AXI slave is a register->route->
    // register path (a full clock), not part of a combinational path. A 1-cycle
    // delay on a debug readout is irrelevant; this keeps dbg_mr off the critical
    // path (it cost ~the timing margin as a combinational output).
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
    // Entry-point multiply te_* = t_min*rd. Computed PER-SLOT in parallel (one dedicated DSP
    // set per slot, 3*N total) rather than once for cur_slot through the shared bank, because:
    //  (a) te_* must stay 1-cycle latency — S_EMPTY sets t_min, S_CHECK_CHILD, then S_SOLID
    //      reads ro+te_x[cur_slot] only 2 cycles later, so an extra pipeline stage would feed
    //      S_SOLID the pre-step entry point (the streaked/stretched-hit corruption); and
    //  (b) the multi-ray slot mux made the shared form (cur_slot decode ~6 ns -> dist-RAM read
    //      -> 32x32 DSP -> RAM write) a ~14 ns path, the N=4 timing-closure blocker.
    // Per-slot, each te_x[s] <= qmul(t_min[s], rd_x[s]) is FF -> DSP -> FF with NO cur_slot
    // decode in front. Bit-identical: consumers only ever read te_*[cur_slot], which was already
    // refreshed every cycle the slot was active; updating all slots changes no observed value.
    // Cost +9 DSPs (3*N vs 3), trivial at 60/220.
    logic signed [31:0] bw_c_ex, bw_c_ey, bw_c_ez;  // = ro + te_* (combinational add); used at S_SOLID hit pos
    // Registered entry point (geom_phase 0). The index/exrel logic below reads THESE, not the
    // live add, so the 32-bit ro+te add no longer chains into the cell-index path (was the
    // worst route-bound setup path -> bw_c*_r). bw_c_e* is stable across the read, so registering
    // it one geom phase earlier is value-identical.
    logic signed [31:0] bw_c_ex_r [0:RAY_POOL_N-1], bw_c_ey_r [0:RAY_POOL_N-1], bw_c_ez_r [0:RAY_POOL_N-1];
    // S_BRAM_WAIT field=6 combinational geometry (all from the registered entry point bw_c_e*_r).
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
    // DDA-step geometry pipeline phase, DECOUPLED from bram_field (M2 Task 1). The node-read
    // (bram_field) and the entry-geometry (cx/dist/dt/t_next) now run on independent counters
    // during S_BRAM_WAIT. In Task 1 they advance in lockstep (slot owns 8 consecutive cycles)
    // so timing is cycle-identical to the old piggybacked version; Task 2 compacts the read
    // alone, leaving this ~7-phase pipeline as the per-node geometry floor.
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

    // Stage counter for S_RAY_SETUP pipeline: advances 0->13 (primary mode) or 0->4 (shadow mode).
    logic [3:0] rs_wait [0:RAY_POOL_N-1];
    // Sub-counter for multiply stages routed through the shared bank: on entry to such
    // a stage (q_phase==0) the operands are issued, q_phase is set to QCOL, then it counts
    // down; at q_phase==1 (QCOL cycles after issue) the product is collected and rs_wait
    // advances. Non-multiply stages leave q_phase at 0 and advance in a single cycle.
    logic [2:0] q_phase [0:RAY_POOL_N-1];

    // ------------------------------------------------------------------------
    // Slot-tagged issue + block + collector for S_RAY_SETUP multiplies.
    // Replaces the q_phase spin so multiplies can be in flight for one slot
    // while another slot is scheduled (latency hiding). At RAY_POOL_N=1 this
    // is bit-identical to the spin: the single slot issues, blocks QCOL cycles,
    // the collector writes the SAME products into the SAME dest regs, unblocks.
    // ------------------------------------------------------------------------
    // A slot is "blocked" while waiting for a tagged multiply it issued.
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
    // Pixel launch/retire reorder buffer (owns AXIS output + busy/frame_done).
    // The core no longer sequences px/py or drives AXIS: pixel_reorder launches
    // pixels in raster order into free slots and emits finished colours on AXIS
    // in raster order. The core starts a ray when launched and pulses pr_done_*
    // when a slot's ray finishes. This module is primary-only (SHADOW_MODE=0).
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

    // any_hit is unused in primary mode (SHADOW_MODE=0 in every instance of this
    // module). The FSM no longer drives it; tie it low continuously.
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

    // Drive the shade_* outputs from the slot CURRENTLY being shaded, held stable
    // for the WHOLE shade. The shading pipeline reads its inputs across multiple
    // stages (block_id, hit_p*, ray_d*, t_hit at different cycles), NOT just on
    // start, so the inputs must persist: use shade_owner while busy, and the
    // freshly-granted slot on the grant cycle (before shade_owner is registered).
    // shade_start is the 1-cycle grant pulse. These outputs are combinational (no
    // <= anywhere); the always_ff drives only the grant register + collector.
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
        // child cell index within this node, clamped on underflow/negative.
        // Reads the REGISTERED entry point (bw_c_e*_r) so the ro+te add is off this path.
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
            // Force pulse signals low every cycle before state case
            fb_wr_en    <= '0;
            pr_done_valid <= 1'b0;
            // Entry-point multiply t_min*rd, registered per-slot in parallel (see te_x decl).
            // One DSP set per slot, no cur_slot decode in front -> short FF->DSP->FF path and
            // 1-cycle latency preserved. Consumers read ro+te_*[cur_slot] (bw_c_e*) next cycle.
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
                // unblock the slot, EXCEPT the FIRST of a 2-issue pair which keeps the slot
                // running to issue the second (it blocks on the second):
                //   DST_RS1A  -> blocks on DST_RS1B
                //   DST_SLAB0 -> blocks on DST_SLAB1
                //   DST_GDT   -> the geometry's first multiply; the slot blocks on DST_GPROD
                // So DST_GPROD (Task 2c) DOES unblock — it's the geometry's blocking multiply.
                if (cd != DST_RS1A && cd != DST_SLAB0 && cd != DST_GDT) blocked[cs] <= 1'b0;
            end

            // Register the round-robin scheduler's last grant (rotates priority).
            if (cur_valid) last_grant <= cur_slot;   // rotate round-robin past the executed slot

            // -----------------------------------------------------------------
            // Launch-init: runs EVERY cycle OUTSIDE the grant gate, keyed on
            // pr_launch_slot (NOT cur_slot). pixel_reorder launches the next
            // raster pixel into a FREE (S_IDLE) slot; this initialises its ray.
            // pr_launch_slot is always a free slot and cur_slot is always a
            // mid-ray slot, so these two write sites never target the same slot
            // in the same cycle — no conflict. Both writes live in this single
            // always_ff so the arrays have exactly one driver process.
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
            // Shading arbiter register + collector (OUTSIDE the grant gate).
            // shade_grant requires !shade_busy and shade_done requires the
            // pipeline was busy, so these fire on mutually-exclusive cycles --
            // no conflict writing shade_busy. Inert when SHADE_MODE=0 (shade_grant
            // gated off, shade_pending never set, shade_done path is shadow-only).
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

            // Execute the registered active slot. Guard with !blocked: the grant was
            // registered a cycle before execution, so a slot that issued a blocking
            // multiply last cycle (blocked now set) must NOT run — skip it (the scheduler's
            // ready[] already excludes blocked slots, so this only catches that 1-cycle stale grant).
            if (cur_valid && !blocked[cur_slot]) begin
            unique case (state[cur_slot])

            // -----------------------------------------------------------------
            // Launch is handled by the launch-init block above (outside the
            // grant gate). ready[] excludes S_IDLE so this arm is never granted;
            // it is a no-op kept only for case completeness.
            S_IDLE: ;

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
                        4'd4: begin  // len2 = dx2+dy2+dz2 (3-way add only). The NR seed
                            // y0 = 1.5 - len2/2 is deferred to stage 5 so this cycle holds just
                            // ONE 32-bit op behind the cur_slot RAM read (was add+subtract -> the
                            // worst setup path). rslen2 is read again at stage 6, unchanged.
                            rslen2[cur_slot]   <= rs_s3_dx2[cur_slot] + rs_s3_dy2[cur_slot] + rs_s3_dz2[cur_slot];
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
                        4'd5: begin  // NR seed y0 = 1.5 - len2/2 (from registered rslen2), then rsqrt: y0sq = y0^2
                            // rs_s4_y0 (needed again at stage 7) is produced here now; the
                            // subtract sits on a fresh RAM->sub->RAM path, not bundled with the
                            // stage-4 3-way add. Value-identical to the old stage-4 computation.
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
                        // Each multiply is time-multiplexed on the shared bank: q_phase==0
                        // issues the 3 lanes (x/y/z); QCOL cycles later (q_phase==1) the
                        // product is collected and rs_wait advances. 2.0_Q16.16 = 0002_0000.
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
                // Slab times come from the shared multiplier bank via the slot-tagged
                // issue/block/collector mechanism (same as S_RAY_SETUP), so they
                // survive interleaving. rs_wait sequence (0 on entry; both S_RAY_SETUP
                // exits set rs_wait<='0):
                //   0 = issue SLAB0 = qmul(-ro, inv); advance (NOT blocked)
                //   1 = issue SLAB1 = qmul(WORLD_Q-ro, inv); block; advance to sort
                //   2 = sort each pair (lo=min, hi=max)   [was rs_wait 6]
                //   3 = t_enter=max(lo), t_exit=min(hi)   [was rs_wait 7]
                //   default(4) = miss check + clamp t_min + set node + transition [was 8]
                // The collector writes rs_tx0/ty0/tz0 (SLAB0, no unblock) and
                // rs_tx1/ty1/tz1 (SLAB1, +unblock) into the SAME dest regs. At N=1 the
                // slot resumes the sort exactly when the old code reached rs_wait==6.
                case (rs_wait[cur_slot])
                    4'd0: begin    // issue SLAB0 = qmul(-ro, inv); advance (NOT blocked)
                        q_a0 <= -ro_x[cur_slot]; q_b0 <= inv_x[cur_slot];
                        q_a1 <= -ro_y[cur_slot]; q_b1 <= inv_y[cur_slot];
                        q_a2 <= -ro_z[cur_slot]; q_b2 <= inv_z[cur_slot];
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_SLAB0};
                        rs_wait[cur_slot] <= rs_wait[cur_slot] + 1'b1;
                    end
                    4'd1: begin    // issue SLAB1 = qmul(WORLD_Q-ro, inv); block; advance to sort
                        q_a0 <= WORLD_Q - ro_x[cur_slot]; q_b0 <= inv_x[cur_slot];
                        q_a1 <= WORLD_Q - ro_y[cur_slot]; q_b1 <= inv_y[cur_slot];
                        q_a2 <= WORLD_Q - ro_z[cur_slot]; q_b2 <= inv_z[cur_slot];
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_SLAB1};
                        blocked[cur_slot] <= 1'b1;
                        rs_wait[cur_slot] <= 4'd2;     // -> sort (was rs_wait 6)
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
                // Only reached when ready (port free or already ours): take ownership
                // of the single BRAM read port for the duration of this 8-cycle read.
                bram_busy   <= 1'b1;
                bram_owner  <= cur_slot;
                bram_field[cur_slot]  <= 3'd1;   // wide read: 1=latency wait, 0=latch, 2=done
                geom_phase[cur_slot]  <= 3'd0;   // start the (decoupled) geometry pipeline
                svo_rd_en   <= 1'b1;
                svo_rd_node <= node_idx[cur_slot][11:0];
                state[cur_slot]       <= S_BRAM_WAIT;
            end

            // -----------------------------------------------------------------
            // svo_bram has a registered output (1-cycle read latency after addr
            // is registered by the FSM), so data is valid 2 edges after the FSM
            // sets svo_rd_addr.  bram_field=7 is a pure wait that absorbs this
            // extra cycle; fields 0-6 then read words 0-6 with correct alignment.
            S_BRAM_WAIT: begin
                // ===== READ pipeline (bram_field): wide whole-node fetch (M2 Task 2) =====
                // svo_bram_wide returns the whole 8-word node on svo_rd_wide with 1-cycle
                // latency: 1 = absorb the latency, 0 = latch all 8 words at once, 2 = done.
                // svo_rd_wide[w*32 +: 32] == node word w (w0=bitmask, w1-4=child pairs,
                // w5-6=block bytes, w7=unused).
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
                        bram_busy <= 1'b0;              // Task 2b: release the read port the instant the
                        bram_field[cur_slot] <= 3'd2;   // node is latched, so OTHER slots can read while
                        // this slot finishes its (port-free) geometry — the overlap that wins throughput.
                        // Safe: while this slot owns the port no other slot can START a read (gated below),
                        // so svo_rd_node/svo_rd_en hold and the wide data is stable; and the geometry never
                        // touches the port.
                    end
                    default: ;   // 3'd2: done — port already released; just finishing geometry
                endcase

                // ===== GEOMETRY pipeline (geom_phase): DDA-step setup, INDEPENDENT of the read =====
                // Phase map (decoupled; value-identical to the pre-pipeline geometry):
                //   0 register entry pt | 1 capture cell+exrel | 2 dist + issue GDT |
                //   3 issue GPROD (block) | 4 commit (after GPROD collector unblocks)
                // te_* (hence bw_c_e*) and node_* are valid on phase 0, so dt/prod still issue
                // early enough to hide the shared bank latency (QCOL=4) before the commit.
                unique case (geom_phase[cur_slot])
                    3'd0: begin   // geom stage 0: register the entry point (ro+te) so the 32-bit
                        // add is OFF the cell-index path. bw_c_e* is stable across the read, so
                        // the index/exrel computed from bw_c_e*_r at phase 1 is value-identical.
                        bw_c_ex_r[cur_slot] <= bw_c_ex;
                        bw_c_ey_r[cur_slot] <= bw_c_ey;
                        bw_c_ez_r[cur_slot] <= bw_c_ez;
                        geom_phase[cur_slot] <= 3'd1;
                    end
                    3'd1: begin   // geom stage 1: capture child cell + entry-rel + node_half (from registered entry pt)
                        bw_cx_r[cur_slot]    <= bw_c_cx;    bw_cy_r[cur_slot]    <= bw_c_cy;    bw_cz_r[cur_slot]    <= bw_c_cz;
                        bw_exrel_r[cur_slot] <= bw_c_exrel; bw_eyrel_r[cur_slot] <= bw_c_eyrel; bw_ezrel_r[cur_slot] <= bw_c_ezrel;
                        bw_nhq_r[cur_slot]   <= bw_c_nhq;
                        geom_phase[cur_slot] <= 3'd2;
                    end
                    3'd2: begin   // geom stage 2: dist to next midplane (no qmul) + issue dt=node_half*|inv|
                        // Use rd_*[31] (ray-dir sign), NOT step_*[2]: step reads inverted on
                        // silicon at N>1 (confirmed by ILA: step sign != rd sign), which corrupted
                        // these DDA boundary distances -> wrong t_next -> holes/shifts. rd is the
                        // reliable sign. !step_*[2] == !rd_*[31] by construction (sim unchanged).
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
                    3'd3: begin   // geom stage 3: issue prod = dist*|inv|, then BLOCK on it
                        q_a0 <= bw_distx_r[cur_slot]; q_b0 <= qabs(inv_x[cur_slot]);
                        q_a1 <= bw_disty_r[cur_slot]; q_b1 <= qabs(inv_y[cur_slot]);
                        q_a2 <= bw_distz_r[cur_slot]; q_b2 <= qabs(inv_z[cur_slot]);
                        q_iss_v <= 1'b1; q_iss_t <= {cur_slot, DST_GPROD};
                        // Task 2c: deschedule the slot for the QCOL=4 multiply latency instead of
                        // spinning in S_BRAM_WAIT. The GPROD collector writes bw_prod_* AND clears
                        // blocked ~4 cycles later, when the slot resumes at phase 4 (the commit).
                        // GDT (issued phase 2) lands one cycle earlier and does NOT unblock. Other
                        // rays run during the wait — the whole point of the wide read.
                        blocked[cur_slot] <= 1'b1;
                        geom_phase[cur_slot] <= 3'd4;
                    end
                    default: ;   // phase 4 = commit (exit block); only reached once GPROD unblocks
                endcase

                // ===== EXIT / COMMIT: read done AND geometry done =====
                // Read done = bram_field==2 (latched). Geometry done = geom_phase==4, which the
                // slot only reaches after the GPROD collector unblocks it (Task 2c) — so by here
                // bw_dt_*/bw_prod_* are both written. The ~4-cycle multiply wait was spent blocked
                // (other rays ran), not spinning in S_BRAM_WAIT.
                if (bram_field[cur_slot] == 3'd2 && geom_phase[cur_slot] == 3'd4) begin
                    // NOTE: the read port (bram_busy/svo_rd_en) was already released at the latch
                    // (Task 2b). Do NOT touch them here — by now another slot may own the port, and
                    // clobbering its bram_busy/svo_rd_en would corrupt its in-flight read.
                    bitmask[cur_slot]   <= r_bitmask[cur_slot];
                    // dt comes from the pipelined qmul; correct in BOTH the fresh-descend and
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
                // A DDA step inside a 2x2x2 node moves to the ADJACENT cell, i.e. it
                // flips the cell bit (0<->1). Using ~c[0] instead of c+/-1 keeps cx/cy/cz
                // STRICTLY 0/1 by construction — the old c+step could momentarily hold 2,
                // and a stray 2 defeats the bit-0 bounds check (step[2]^c[0]) and makes the
                // cell run away (cy -> 3,4,6...) on silicon at N>1. The pop branch's flipped
                // value is don't-care (S_POP_STACK restores it from the stack).
                // Value-identical to c+step whenever c is in range (sim unchanged).
                // Pop-vs-continue uses the ray-direction sign DIRECTLY (rd_*[31]) rather than
                // step_*[2]. They are equal by construction (step = rd[31]?-1:+1), but rd is the
                // signal proven correct on silicon (descent reaches the right nodes), whereas the
                // step register read here was inverted at N>1 -> rays popped out of a node instead
                // of stepping to the adjacent (solid) cell. Value-identical in sim.
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
                // Hit point = entry point at the current t_min. Use the *registered*
                // copy bw_e*_r, not the combinational bw_c_e*: t_min is stable across
                // S_CHECK_CHILD -> S_SOLID, so bw_e*_r (registered last cycle) holds the
                // identical value, and this becomes a short FF->FF copy instead of the
                // long entry-point multiply+add path (which was the −0.96 ns worst path).
                hit_px_r[cur_slot]     <= bw_c_ex;
                hit_py_r[cur_slot]     <= bw_c_ey;
                hit_pz_r[cur_slot]     <= bw_c_ez;
                if (SHADE_MODE) begin
                    // hand off to shading pipeline via the arbiter: store this hit
                    // (the per-slot regs above), raise pending, park in S_WAIT_SHADE.
                    shade_is_miss_r[cur_slot] <= 1'b0;
                    shade_pending[cur_slot]   <= 1'b1;
                    state[cur_slot]           <= S_WAIT_SHADE;
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
                if (SHADE_MODE) begin
                    // Go into shading pipeline as miss via the arbiter:
                    // mark this slot as a miss, raise pending, park in S_WAIT_SHADE.
                    shade_is_miss_r[cur_slot] <= 1'b1;
                    shade_pending[cur_slot]   <= 1'b1;
                    state[cur_slot]           <= S_WAIT_SHADE;
                end else begin
                    // Non shading mode for testing traversal
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
            // S_NEXT_PIXEL is dead: pixel advance + framing are now pixel_reorder's
            // job. Nothing transitions here; the enum value is kept to preserve the
            // FSM state encoding.
            S_NEXT_PIXEL: ;

            endcase
            end  // if (cur_valid)
        end
    end

endmodule
