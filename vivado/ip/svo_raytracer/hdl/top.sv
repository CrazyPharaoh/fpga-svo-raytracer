// top.sv
// Top-level of the svo_raytracer custom IP block.
// Phase 1: SHADE_MODE=0 — hit→white, miss→sky (no shading_pipeline instance).
// Phase 2: SHADE_MODE=1 — full shading + shadow traversal.
// rgb2dvi is instantiated separately in the Vivado block design.
`timescale 1ns/1ps
module top #(
    parameter int  C_S_AXI_DATA_WIDTH = 32,
    parameter int  C_S_AXI_ADDR_WIDTH = 8,
    parameter bit  SHADE_MODE         = 1,  // Phase 2: full shading + shadow rays
    // Multi-ray pool size for the primary traversal core (svo_traversal_mr).
    // RAY_POOL_N=1 = single ray (original behaviour). RAY_POOL_N=4 = interleaved
    // multi-ray core (M1). Works in BOTH Phase 1 (SHADE_MODE=0) and Phase 2
    // (SHADE_MODE=1, shaded+shadowed): the shading pipeline is arbitrated across
    // slots (one shade at a time) and the shadow ray reads BRAM port A while the
    // primary reads port B, so the two never contend.
    parameter int  RAY_POOL_N          = 4
)(
    // AXI4-Lite slave
    input  logic        s_axi_aclk,
    input  logic        s_axi_aresetn,
    input  logic [7:0]  s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [7:0]  s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    output logic        irq,          // frame_done → IRQ_F2P on PS

    // AXI-Stream pixel output → AXI VDMA in block design
    output logic        axis_tvalid,
    output logic [31:0] axis_tdata,
    output logic [3:0]  axis_tkeep,
    output logic        axis_tlast,
    output logic [0:0]  axis_tuser,
    input  logic        axis_tready
);

    logic clk = s_axi_aclk;
    logic rst = ~s_axi_aresetn;

    // (* mark_debug *) flags these nets for ILA insertion via "Set Up Debug".
    // All on clk (clk_fpga_0, 100 MHz). See svo_traversal_mr for the dbg_mr packing.
    (* mark_debug = "true" *) logic [3:0]  dbg_state_w;   // state[cur_slot]
    logic [3:0] dbg_rs_wait_w;
    (* mark_debug = "true" *) logic [8:0]  dbg_px_w;      // px[cur_slot]
    (* mark_debug = "true" *) logic [7:0]  dbg_py_w;      // py[cur_slot]
    logic       dbg_tvalid_w;
    logic       dbg_tready_w;
    (* mark_debug = "true" *) logic [31:0] dbg_mr_w;      // all slot states + scheduler/arbiter flags
    // New ILA probes from the multi-ray core (executing slot + its ray data).
    (* mark_debug = "true" *) logic [1:0]  dbg_cur_slot_w;
    (* mark_debug = "true" *) logic [31:0] dbg_d0_w;      // {node_idx, bitmask}
    (* mark_debug = "true" *) logic [31:0] dbg_d1_w;      // {sp,cidx,cx,cy,cz}

    // -------------------------------------------------------------------------
    // AXI slave → pipeline wires
    // -------------------------------------------------------------------------
    logic        ctrl_trigger, status_frame_done;
    (* mark_debug = "true" *) logic status_busy;   // ILA trigger: rises at render start
    logic signed [31:0] cam_pos_x, cam_pos_y, cam_pos_z;
    logic signed [31:0] cam_right_x, cam_right_y, cam_right_z;
    logic signed [31:0] cam_up_x, cam_up_y, cam_up_z;
    logic signed [31:0] cam_fwd_x, cam_fwd_y, cam_fwd_z;
    logic signed [31:0] cam_scale;
    logic signed [31:0] light_dir_x, light_dir_y, light_dir_z;
    logic [14:0] svo_wr_addr;
    logic [31:0] svo_wr_data;
    logic        svo_wr_en;
    logic [31:0] lut [0:15];
    logic [31:0] sky_color_reg, fog_color_reg;
    logic signed [31:0] fog_start_reg, shadow_bias_reg;
    logic [31:0] time_phase;
    logic        shadow_on;
    logic [3:0]  max_depth;

    // -------------------------------------------------------------------------
    // SVO BRAM — true dual-port. Primary traversal reads port B; shadow
    // traversal reads port A (idle for writes during render). No arbiter — the
    // two readers are fully independent, so neither desyncs the other's
    // sequential 8-word node reads.
    // -------------------------------------------------------------------------
    // Primary traversal read port (port B) — M2 wide read: node index in, whole node out
    logic [11:0]  svo_rd_node_prim;
    logic [255:0] svo_rd_wide_prim;
    logic         svo_rd_en_prim;

    // Shadow traversal read ports — one per shading lane (see SHADE_LANES below).
    // Lane 0 reads the shadow-geometry BRAM Port A, lane 1 reads Port B.
    localparam int SHADE_LANES = 2;
    logic [14:0] svo_rd_addr_shad [0:SHADE_LANES-1];
    logic [31:0] svo_rd_data_shad [0:SHADE_LANES-1];
    logic        svo_rd_en_shad   [0:SHADE_LANES-1];

    // -------------------------------------------------------------------------
    // AXI-Stream from traversal to VDMA
    // -------------------------------------------------------------------------
    logic        axis_tvalid_int;
    logic [31:0] axis_tdata_int;
    logic        axis_tlast_int;
    logic [0:0]  axis_tuser_int;

    // -------------------------------------------------------------------------
    // Shading pipeline ↔ primary traversal — one bundle per shading lane (SHADE_LANES above).
    // -------------------------------------------------------------------------
    logic        shade_start         [0:SHADE_LANES-1];
    logic        shade_done          [0:SHADE_LANES-1];
    logic        shade_is_miss       [0:SHADE_LANES-1];
    logic [1:0]  shade_hit_face      [0:SHADE_LANES-1];
    logic        shade_hit_face_sign [0:SHADE_LANES-1];
    logic [7:0]  shade_block_id      [0:SHADE_LANES-1];
    logic signed [31:0] shade_t_hit  [0:SHADE_LANES-1];
    logic signed [31:0] shade_ray_dx [0:SHADE_LANES-1], shade_ray_dy [0:SHADE_LANES-1], shade_ray_dz [0:SHADE_LANES-1];
    logic signed [31:0] shade_hit_px [0:SHADE_LANES-1], shade_hit_py [0:SHADE_LANES-1], shade_hit_pz [0:SHADE_LANES-1];
    logic [23:0] shade_pixel_color   [0:SHADE_LANES-1];

    // -------------------------------------------------------------------------
    // Shadow traversal ↔ shading pipeline — one per lane.
    // -------------------------------------------------------------------------
    logic        shadow_start [0:SHADE_LANES-1], shadow_done [0:SHADE_LANES-1], shadow_any_hit [0:SHADE_LANES-1];
    logic signed [31:0] shadow_ro_x [0:SHADE_LANES-1], shadow_ro_y [0:SHADE_LANES-1], shadow_ro_z [0:SHADE_LANES-1];
    logic signed [31:0] shadow_rd_x [0:SHADE_LANES-1], shadow_rd_y [0:SHADE_LANES-1], shadow_rd_z [0:SHADE_LANES-1];

    // =========================================================================
    // Submodule instances
    // =========================================================================

    axi_lite_slave axi_slave (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(s_axi_aresetn),
        .S_AXI_AWADDR(s_axi_awaddr), .S_AXI_AWVALID(s_axi_awvalid), .S_AXI_AWREADY(s_axi_awready),
        .S_AXI_WDATA(s_axi_wdata),   .S_AXI_WSTRB(s_axi_wstrb),    .S_AXI_WVALID(s_axi_wvalid),
        .S_AXI_WREADY(s_axi_wready),
        .S_AXI_BRESP(s_axi_bresp),   .S_AXI_BVALID(s_axi_bvalid),  .S_AXI_BREADY(s_axi_bready),
        .S_AXI_ARADDR(s_axi_araddr), .S_AXI_ARVALID(s_axi_arvalid),.S_AXI_ARREADY(s_axi_arready),
        .S_AXI_RDATA(s_axi_rdata),   .S_AXI_RRESP(s_axi_rresp),    .S_AXI_RVALID(s_axi_rvalid),
        .S_AXI_RREADY(s_axi_rready),
        .ctrl_trigger(ctrl_trigger), .status_busy(status_busy),
        .status_frame_done(status_frame_done),
        .cam_pos_x(cam_pos_x),   .cam_pos_y(cam_pos_y),   .cam_pos_z(cam_pos_z),
        .cam_right_x(cam_right_x),.cam_right_y(cam_right_y),.cam_right_z(cam_right_z),
        .cam_up_x(cam_up_x),     .cam_up_y(cam_up_y),     .cam_up_z(cam_up_z),
        .cam_fwd_x(cam_fwd_x),   .cam_fwd_y(cam_fwd_y),   .cam_fwd_z(cam_fwd_z),
        .cam_scale(cam_scale),
        .light_dir_x(light_dir_x),.light_dir_y(light_dir_y),.light_dir_z(light_dir_z),
        .svo_wr_addr(svo_wr_addr),.svo_wr_data(svo_wr_data),.svo_wr_en(svo_wr_en),
        .lut(lut),
        .sky_color(sky_color_reg), .fog_color(fog_color_reg),
        .fog_start(fog_start_reg), .shadow_bias(shadow_bias_reg),
        .time_phase(time_phase),
        .shadow_on(shadow_on), .max_depth(max_depth),
        .dbg_state(dbg_state_w), .dbg_rs_wait(dbg_rs_wait_w),
        .dbg_px(dbg_px_w), .dbg_py(dbg_py_w),
        .dbg_tvalid(dbg_tvalid_w), .dbg_tready(dbg_tready_w),
        .dbg_mr(dbg_mr_w)
    );

    // svo_wr_addr is incremented in the same non-blocking cycle as svo_wr_en is
    // asserted, so by the time svo_wr_en propagates to the BRAM (1 cycle later)
    // addr is already addr+1.  A 1-cycle delayed copy corrects this.
    logic [14:0] svo_wr_addr_lat;
    always_ff @(posedge clk) svo_wr_addr_lat <= svo_wr_addr;

    // M2 asymmetric main BRAM: Port A = 32-bit write (upload) ONLY — shadows now read the
    // dedicated svo_bram_shadow, freeing Port A. Port B = 256-bit whole-node primary read.
    svo_bram_wide svo_mem (
        .clk_a(clk), .en_a(svo_wr_en), .addr_a(svo_wr_addr_lat), .din_a(svo_wr_data),
        .dout_a(),                                 // unused (shadows moved off Port A)
        .clk_b(clk), .en_b(svo_rd_en_prim),
        .addr_b_node(svo_rd_node_prim), .dout_b_wide(svo_rd_wide_prim)  // primary reads port B (256-bit)
    );

    svo_traversal_mr #(.RAY_POOL_N(RAY_POOL_N), .SHADOW_MODE(0), .SHADE_MODE(SHADE_MODE), .SHADE_LANES(SHADE_LANES)) traversal (
        .clk(clk), .rst(rst), .start(ctrl_trigger),
        .cam_pos_x(cam_pos_x),   .cam_pos_y(cam_pos_y),   .cam_pos_z(cam_pos_z),
        .cam_right_x(cam_right_x),.cam_right_y(cam_right_y),.cam_right_z(cam_right_z),
        .cam_up_x(cam_up_x),     .cam_up_y(cam_up_y),     .cam_up_z(cam_up_z),
        .cam_fwd_x(cam_fwd_x),   .cam_fwd_y(cam_fwd_y),   .cam_fwd_z(cam_fwd_z),
        .cam_scale(cam_scale),
        .sky_color(sky_color_reg[23:0]),
        .max_depth(max_depth),
        .svo_rd_node(svo_rd_node_prim), .svo_rd_wide(svo_rd_wide_prim),
        .svo_rd_en(svo_rd_en_prim),
        .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),   // legacy — unconnected
        .axis_tvalid(axis_tvalid_int), .axis_tdata(axis_tdata_int),
        .axis_tlast(axis_tlast_int),   .axis_tuser(axis_tuser_int),
        .axis_tready(axis_tready),
        .shade_start(shade_start),    .shade_is_miss(shade_is_miss),
        .shade_hit_face(shade_hit_face), .shade_hit_face_sign(shade_hit_face_sign),
        .shade_block_id(shade_block_id), .shade_t_hit(shade_t_hit),
        .shade_ray_dx(shade_ray_dx),  .shade_ray_dy(shade_ray_dy),  .shade_ray_dz(shade_ray_dz),
        .shade_hit_px(shade_hit_px),  .shade_hit_py(shade_hit_py),  .shade_hit_pz(shade_hit_pz),
        .shade_done(shade_done),  .shade_pixel_color(shade_pixel_color),
        .busy(status_busy), .frame_done(status_frame_done), .any_hit(),
        .dbg_state(dbg_state_w), .dbg_rs_wait(dbg_rs_wait_w),
        .dbg_px(dbg_px_w), .dbg_py(dbg_py_w),
        .dbg_tvalid(dbg_tvalid_w), .dbg_tready(dbg_tready_w),
        .dbg_mr(dbg_mr_w),
        .dbg_cur_slot(dbg_cur_slot_w), .dbg_d0(dbg_d0_w), .dbg_d1(dbg_d1_w)
    );

    // -------------------------------------------------------------------------
    // Shadows ON: Option A (2026-06-02) temporarily dropped the shadow_trav
    // instance to free ~68 DSP and close Phase 2 timing. The shared multiplier
    // banks (shared_qmul3) have since cut DSP usage dramatically, so hard shadows
    // are restored. Must match SHADOW_EN in sim/svo_full_tb.sv.
    // -------------------------------------------------------------------------
    localparam bit SHADOW_EN = 1'b1;

    // Phase 2 only: SHADE_LANES parallel shading lanes (shader + shadow ray each).
    generate if (SHADE_MODE) begin : g_shading

        // Geometry-only shadow BRAM (w0-w4): TWO single-read copies, one per shading lane,
        // both written by the loader. (A single dual-read copy does not infer block RAM —
        // see svo_bram_shadow.) Each gives its lane an independent read port, with no
        // contention with the primary (main Port B) or with each other.
        if (SHADOW_EN) begin : g_shadow_mem
            svo_bram_shadow shadow_mem0 (
                .clk(clk), .en_a(svo_wr_en), .addr_a(svo_wr_addr_lat), .din_a(svo_wr_data),
                .addr_b(svo_rd_addr_shad[0]), .dout_b(svo_rd_data_shad[0])
            );
            svo_bram_shadow shadow_mem1 (
                .clk(clk), .en_a(svo_wr_en), .addr_a(svo_wr_addr_lat), .din_a(svo_wr_data),
                .addr_b(svo_rd_addr_shad[1]), .dout_b(svo_rd_data_shad[1])
            );
        end

        for (genvar L = 0; L < SHADE_LANES; L++) begin : g_lane
            shading_pipeline shading (
                .clk(clk), .rst(rst), .start(shade_start[L]),
                .is_miss(shade_is_miss[L]),
                .hit_face(shade_hit_face[L]), .hit_face_sign(shade_hit_face_sign[L]),
                .block_id(shade_block_id[L]), .t_hit(shade_t_hit[L]),
                .ray_dx(shade_ray_dx[L]), .ray_dy(shade_ray_dy[L]), .ray_dz(shade_ray_dz[L]),
                .hit_px(shade_hit_px[L]), .hit_py(shade_hit_py[L]), .hit_pz(shade_hit_pz[L]),
                .light_dir_x(light_dir_x), .light_dir_y(light_dir_y), .light_dir_z(light_dir_z),
                .sky_color(sky_color_reg[23:0]), .fog_color(fog_color_reg[23:0]),
                .fog_start(fog_start_reg), .shadow_bias(shadow_bias_reg),
                .lut(lut),   // block_id N -> lut[N]
                .time_phase(time_phase),
                .shadow_on(shadow_on),
                .shadow_start(shadow_start[L]),
                .shadow_ro_x(shadow_ro_x[L]), .shadow_ro_y(shadow_ro_y[L]), .shadow_ro_z(shadow_ro_z[L]),
                .shadow_rd_x(shadow_rd_x[L]), .shadow_rd_y(shadow_rd_y[L]), .shadow_rd_z(shadow_rd_z[L]),
                .shadow_done(shadow_done[L]), .shadow_hit(shadow_any_hit[L]),
                .pixel_color(shade_pixel_color[L]), .done(shade_done[L])
            );

            if (SHADOW_EN) begin : g_shadow
                svo_traversal #(.SHADOW_MODE(1), .SHADE_MODE(0)) shadow_trav (
                    .clk(clk), .rst(rst), .start(shadow_start[L]),
                    .cam_pos_x(shadow_ro_x[L]), .cam_pos_y(shadow_ro_y[L]), .cam_pos_z(shadow_ro_z[L]),
                    .cam_fwd_x(shadow_rd_x[L]), .cam_fwd_y(shadow_rd_y[L]), .cam_fwd_z(shadow_rd_z[L]),
                    .cam_right_x('0), .cam_right_y('0), .cam_right_z('0),
                    .cam_up_x('0),    .cam_up_y('0),    .cam_up_z('0),
                    .cam_scale('0),   .sky_color('0),
                    .max_depth(max_depth),   // shadows follow the depth cap too
                    .svo_rd_addr(svo_rd_addr_shad[L]), .svo_rd_data(svo_rd_data_shad[L]),
                    .svo_rd_en(svo_rd_en_shad[L]),
                    .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),
                    .axis_tvalid(), .axis_tdata(), .axis_tlast(), .axis_tuser(),
                    .axis_tready('0),
                    .shade_start(), .shade_is_miss(), .shade_hit_face(), .shade_hit_face_sign(),
                    .shade_block_id(), .shade_t_hit(),
                    .shade_ray_dx(), .shade_ray_dy(), .shade_ray_dz(),
                    .shade_hit_px(), .shade_hit_py(), .shade_hit_pz(),
                    .shade_done('0), .shade_pixel_color('0),
                    .busy(), .frame_done(shadow_done[L]), .any_hit(shadow_any_hit[L]),
                    .dbg_state(), .dbg_rs_wait(),
                    .dbg_px(), .dbg_py(),
                    .dbg_tvalid(), .dbg_tready()
                );
            end else begin : g_no_shadow
                // Shadows off: treat every surface as fully lit.
                assign shadow_done[L]      = 1'b1;
                assign shadow_any_hit[L]   = 1'b0;
                assign svo_rd_en_shad[L]   = 1'b0;
                assign svo_rd_addr_shad[L] = '0;
            end
        end

    end else begin : g_no_shading
        // Phase 1: tie off all shading/shadow lanes.
        for (genvar L = 0; L < SHADE_LANES; L++) begin : g_tie
            assign shade_done[L]        = '0;
            assign shade_pixel_color[L] = '0;
            assign shadow_done[L]       = '0;
            assign shadow_any_hit[L]    = '0;
            assign svo_rd_en_shad[L]    = '0;
            assign svo_rd_addr_shad[L]  = '0;
        end
    end endgenerate

    assign axis_tvalid = axis_tvalid_int;
    assign axis_tdata  = axis_tdata_int;
    assign axis_tkeep  = 4'b1111;
    assign axis_tlast  = axis_tlast_int;
    assign axis_tuser  = axis_tuser_int;

    assign irq = status_frame_done;

endmodule
