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
    output logic        any_hit       // SHADOW_MODE: 1 when first solid hit found
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
        r  = 32'h0001_0000;
        r2 = qmul(xabs, r); r2 = 32'h0002_0000 - r2; r = qmul(r, r2);
        r2 = qmul(xabs, r); r2 = 32'h0002_0000 - r2; r = qmul(r, r2);
        return (x < 0) ? -r : r;
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

    state_t state;
    logic [3:0] state_raw; assign state_raw = state;   // integer alias for waveform viewers

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

    logic signed [31:0] rs_tx0, rs_tx1, rs_ty0, rs_ty1, rs_tz0, rs_tz1, rs_world_q, rs_tmp;
    logic signed [31:0] bw_ex, bw_ey, bw_ez, bw_abs_ix, bw_abs_iy, bw_abs_iz;
    logic signed [31:0] bw_ex_rel, bw_ey_rel, bw_ez_rel;   // position within node (Q16.16)
    logic signed [31:0] bw_dist_x, bw_dist_y, bw_dist_z;   // distance to next boundary
    logic signed [31:0] bw_nh;                               // node_half in Q16.16
    logic [5:0]         bw_icx, bw_icy, bw_icz;
    logic [1:0]         em_face;
    logic               em_fsign;
    logic signed [31:0] rsu, rsv, rsdx, rsdy, rsdz, rslen2, rsinv_len, rsndx, rsndy, rsndz;

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

    // Wait counter for S_RAY_SETUP: holds the state for 11 cycles so the
    // 14-DSP48 combinational chain (~79 ns) settles before registers capture.
    // Matches the set_multicycle_path -setup 11 constraint in the XDC.
    logic [3:0] rs_wait;

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
            px <= '0; py <= '0; sp <= '0; rs_wait <= '0;
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
                    busy    <= 1'b1;
                    px      <= '0;
                    py      <= '0;
                    rs_wait <= '0;
                    state   <= S_RAY_SETUP;
                end
            end

            // -----------------------------------------------------------------
            // S_RAY_SETUP: compute normalised ray direction from pixel + camera.
            //
            // Primary mode has a 14-DSP48 combinational chain (~79 ns) that
            // cannot close timing in a single 10 ns cycle.  rs_wait holds the
            // FSM here for 11 cycles so the chain settles before the registers
            // capture.  This matches set_multicycle_path -setup 11 in the XDC.
            // Shadow mode has no deep chain and exits immediately.
            S_RAY_SETUP: begin
                if (SHADOW_MODE) begin
                    // Shadow mode: ray fully specified by cam_pos / cam_fwd
                    ro_x <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                    rd_x <= cam_fwd_x; rd_y <= cam_fwd_y; rd_z <= cam_fwd_z;
                    inv_x <= qrecip(cam_fwd_x);
                    inv_y <= qrecip(cam_fwd_y);
                    inv_z <= qrecip(cam_fwd_z);
                    step_x <= (cam_fwd_x >= 0) ? 3'sd1 : -3'sd1;
                    step_y <= (cam_fwd_y >= 0) ? 3'sd1 : -3'sd1;
                    step_z <= (cam_fwd_z >= 0) ? 3'sd1 : -3'sd1;
                    sp    <= '0;
                    state <= S_ROOT_SLAB;
                end else begin
                    // Primary mode: wait for combinational chain to settle
                    if (rs_wait < 4'd10) begin
                        rs_wait <= rs_wait + 1'b1;
                    end else begin
                        rs_wait <= '0;
                        rsu  = qmul(($signed({px, 16'd0}) - 32'sh00A0_0000), cam_scale);
                        rsv  = qmul(($signed({py, 16'd0}) - 32'sh0078_0000), cam_scale);
                        rsdx = cam_fwd_x + qmul(rsu, cam_right_x) - qmul(rsv, cam_up_x);
                        rsdy = cam_fwd_y + qmul(rsu, cam_right_y) - qmul(rsv, cam_up_y);
                        rsdz = cam_fwd_z + qmul(rsu, cam_right_z) - qmul(rsv, cam_up_z);
                        rslen2    = qmul(rsdx, rsdx) + qmul(rsdy, rsdy) + qmul(rsdz, rsdz);
                        rsinv_len = 32'sh0001_8000 - qmul(32'sh0000_8000, rslen2);
                        rsinv_len = qmul(rsinv_len, 32'sh0001_8000 - qmul(32'sh0000_8000, qmul(rslen2, qmul(rsinv_len, rsinv_len))));
                        rsndx = qmul(rsdx, rsinv_len);
                        rsndy = qmul(rsdy, rsinv_len);
                        rsndz = qmul(rsdz, rsinv_len);
                        rd_x <= rsndx;
                        rd_y <= rsndy;
                        rd_z <= rsndz;
                        ro_x <= cam_pos_x; ro_y <= cam_pos_y; ro_z <= cam_pos_z;
                        inv_x <= qrecip(rsndx);
                        inv_y <= qrecip(rsndy);
                        inv_z <= qrecip(rsndz);
                        step_x <= (rsndx >= 0) ? 3'sd1 : -3'sd1;
                        step_y <= (rsndy >= 0) ? 3'sd1 : -3'sd1;
                        step_z <= (rsndz >= 0) ? 3'sd1 : -3'sd1;
                        sp    <= '0;
                        state <= S_ROOT_SLAB;
                    end
                end
            end

            // -----------------------------------------------------------------
            S_ROOT_SLAB: begin
                rs_world_q = WORLD_SIZE << 16;
                rs_tx0 = qmul(-ro_x,              inv_x); rs_tx1 = qmul(rs_world_q - ro_x, inv_x);
                rs_ty0 = qmul(-ro_y,              inv_y); rs_ty1 = qmul(rs_world_q - ro_y, inv_y);
                rs_tz0 = qmul(-ro_z,              inv_z); rs_tz1 = qmul(rs_world_q - ro_z, inv_z);
                if (rs_tx0 > rs_tx1) begin rs_tmp=rs_tx0; rs_tx0=rs_tx1; rs_tx1=rs_tmp; end
                if (rs_ty0 > rs_ty1) begin rs_tmp=rs_ty0; rs_ty0=rs_ty1; rs_ty1=rs_tmp; end
                if (rs_tz0 > rs_tz1) begin rs_tmp=rs_tz0; rs_tz0=rs_tz1; rs_tz1=rs_tmp; end
                t_min <= (rs_tx0>rs_ty0)?((rs_tx0>rs_tz0)?rs_tx0:rs_tz0):((rs_ty0>rs_tz0)?rs_ty0:rs_tz0);
                t_max <= (rs_tx1<rs_ty1)?((rs_tx1<rs_tz1)?rs_tx1:rs_tz1):((rs_ty1<rs_tz1)?rs_ty1:rs_tz1);
                if ((rs_tx0>rs_ty0 ? (rs_tx0>rs_tz0 ? rs_tx0:rs_tz0):(rs_ty0>rs_tz0 ? rs_ty0:rs_tz0)) >
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
                bram_field  <= '0;
                svo_rd_en   <= 1'b1;
                svo_rd_addr <= {node_idx[11:0], 3'd0};
                state       <= S_BRAM_WAIT;
            end

            // -----------------------------------------------------------------
            S_BRAM_WAIT: begin
                unique case (bram_field)
                    3'd0: r_bitmask       <= svo_rd_data[15:0];
                    3'd1: begin r_child[0]<=svo_rd_data[15:0]; r_child[1]<=svo_rd_data[31:16]; end
                    3'd2: begin r_child[2]<=svo_rd_data[15:0]; r_child[3]<=svo_rd_data[31:16]; end
                    3'd3: begin r_child[4]<=svo_rd_data[15:0]; r_child[5]<=svo_rd_data[31:16]; end
                    3'd4: begin r_child[6]<=svo_rd_data[15:0]; r_child[7]<=svo_rd_data[31:16]; end
                    3'd5: begin
                        r_block[0]<=svo_rd_data[7:0];   r_block[1]<=svo_rd_data[15:8];
                        r_block[2]<=svo_rd_data[23:16]; r_block[3]<=svo_rd_data[31:24];
                    end
                    3'd6: begin
                        r_block[4]<=svo_rd_data[7:0];   r_block[5]<=svo_rd_data[15:8];
                        r_block[6]<=svo_rd_data[23:16]; r_block[7]<=svo_rd_data[31:24];
                    end
                    default: ;
                endcase
                if (bram_field < 3'd6) begin
                    bram_field  <= bram_field + 1'b1;
                    svo_rd_addr <= {node_idx[11:0], bram_field + 1'b1};
                end else begin
                    svo_rd_en <= '0;
                    bitmask   <= r_bitmask;
                    bw_ex  = ro_x + qmul(t_min, rd_x);
                    bw_ey  = ro_y + qmul(t_min, rd_y);
                    bw_ez  = ro_z + qmul(t_min, rd_z);
                    bw_icx = ($signed(bw_ex) < 0) ? 6'd0 : bw_ex[21:16];
                    bw_icy = ($signed(bw_ey) < 0) ? 6'd0 : bw_ey[21:16];
                    bw_icz = ($signed(bw_ez) < 0) ? 6'd0 : bw_ez[21:16];
                    bw_icx = bw_icx - node_origin_x;
                    bw_icy = bw_icy - node_origin_y;
                    bw_icz = bw_icz - node_origin_z;
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
                    if (step_x > 0)
                        bw_dist_x = (bw_icx >= node_half) ?
                            ((bw_nh <<< 1) - bw_ex_rel) :   // cx=1: 2*nh - pos
                            (bw_nh - bw_ex_rel);             // cx=0: nh - pos
                    else
                        bw_dist_x = (bw_icx >= node_half) ?
                            (bw_ex_rel - bw_nh) :            // cx=1: pos - nh
                            bw_ex_rel;                       // cx=0: pos - 0
                    if (step_y > 0)
                        bw_dist_y = (bw_icy >= node_half) ?
                            ((bw_nh <<< 1) - bw_ey_rel) :
                            (bw_nh - bw_ey_rel);
                    else
                        bw_dist_y = (bw_icy >= node_half) ?
                            (bw_ey_rel - bw_nh) :
                            bw_ey_rel;
                    if (step_z > 0)
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
                    cx <= cx + 6'(step_x); t_min <= t_next_x; t_next_x <= t_next_x + dt_x;
                    em_face = 2'd0; em_fsign = (step_x < 0);
                end else if (t_next_y <= t_next_z) begin
                    cy <= cy + 6'(step_y); t_min <= t_next_y; t_next_y <= t_next_y + dt_y;
                    em_face = 2'd1; em_fsign = (step_y < 0);
                end else begin
                    cz <= cz + 6'(step_z); t_min <= t_next_z; t_next_z <= t_next_z + dt_z;
                    em_face = 2'd2; em_fsign = (step_z < 0);
                end
                hit_face        <= em_face;
                hit_face_sign_r <= em_fsign;
                if (cx > 1 || cy > 1 || cz > 1 || cx[5] || cy[5] || cz[5])
                    state <= S_POP_STACK;
                else
                    state <= S_CHECK_CHILD;
            end

            // -----------------------------------------------------------------
            S_SOLID: begin
                t_hit        <= t_min;
                block_id_hit <= r_block[cidx];
                hit_px_r     <= ro_x + qmul(t_min, rd_x);
                hit_py_r     <= ro_y + qmul(t_min, rd_y);
                hit_pz_r     <= ro_z + qmul(t_min, rd_z);
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
                    shade_hit_px        <= ro_x + qmul(t_min, rd_x);
                    shade_hit_py        <= ro_y + qmul(t_min, rd_y);
                    shade_hit_pz        <= ro_z + qmul(t_min, rd_z);
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
                    t_min         <= stk_t_min    [sp-1]; t_max <= stk_t_max [sp-1];
                    t_next_x      <= stk_t_next_x [sp-1];
                    t_next_y      <= stk_t_next_y [sp-1];
                    t_next_z      <= stk_t_next_z [sp-1];
                    cx            <= stk_cx       [sp-1];
                    cy            <= stk_cy       [sp-1];
                    cz            <= stk_cz       [sp-1];
                    node_half     <= stk_node_half[sp-1];
                    node_origin_x <= stk_orig_x   [sp-1];
                    node_origin_y <= stk_orig_y   [sp-1];
                    node_origin_z <= stk_orig_z   [sp-1];
                    state <= S_EMPTY;
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
