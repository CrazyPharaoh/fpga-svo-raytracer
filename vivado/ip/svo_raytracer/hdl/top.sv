// top.sv
// Top-level of the svo_raytracer custom IP block.
// Phase 1: SHADE_MODE=0 — hit→white, miss→sky (no shading_pipeline instance).
// Phase 2: SHADE_MODE=1 — full shading + shadow traversal.
// rgb2dvi is instantiated separately in the Vivado block design.
`timescale 1ns/1ps
module top #(
    parameter int  C_S_AXI_DATA_WIDTH = 32,
    parameter int  C_S_AXI_ADDR_WIDTH = 8,
    parameter bit  SHADE_MODE         = 1   // Phase 2: full shading + shadow rays
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

    logic [3:0] dbg_state_w;
    logic [3:0] dbg_rs_wait_w;
    logic [8:0] dbg_px_w;
    logic [7:0] dbg_py_w;
    logic       dbg_tvalid_w;
    logic       dbg_tready_w;

    // -------------------------------------------------------------------------
    // AXI slave → pipeline wires
    // -------------------------------------------------------------------------
    logic        ctrl_trigger, status_busy, status_frame_done;
    logic signed [31:0] cam_pos_x, cam_pos_y, cam_pos_z;
    logic signed [31:0] cam_right_x, cam_right_y, cam_right_z;
    logic signed [31:0] cam_up_x, cam_up_y, cam_up_z;
    logic signed [31:0] cam_fwd_x, cam_fwd_y, cam_fwd_z;
    logic signed [31:0] cam_scale;
    logic signed [31:0] light_dir_x, light_dir_y, light_dir_z;
    logic [14:0] svo_wr_addr;
    logic [31:0] svo_wr_data;
    logic        svo_wr_en;
    logic [31:0] lut [0:5];
    logic [31:0] sky_color_reg, fog_color_reg;
    logic signed [31:0] fog_start_reg, shadow_bias_reg;

    // -------------------------------------------------------------------------
    // SVO BRAM — shared by primary traversal and shadow traversal (arbitrated)
    // -------------------------------------------------------------------------
    // Primary traversal read port
    logic [14:0] svo_rd_addr_prim;
    logic [31:0] svo_rd_data_prim;
    logic        svo_rd_en_prim;

    // Shadow traversal read port
    logic [14:0] svo_rd_addr_shad;
    logic [31:0] svo_rd_data_shad;
    logic        svo_rd_en_shad;

    // Simple priority arbiter: primary wins; shadow gets access when primary idle
    logic [14:0] svo_rd_addr_mux;
    logic        svo_rd_en_mux;
    logic [31:0] svo_rd_data_mux;

    always_comb begin
        if (svo_rd_en_prim) begin
            svo_rd_addr_mux = svo_rd_addr_prim;
            svo_rd_en_mux   = 1'b1;
        end else begin
            svo_rd_addr_mux = svo_rd_addr_shad;
            svo_rd_en_mux   = svo_rd_en_shad;
        end
    end
    assign svo_rd_data_prim = svo_rd_data_mux;
    assign svo_rd_data_shad = svo_rd_data_mux;

    // -------------------------------------------------------------------------
    // AXI-Stream from traversal to VDMA
    // -------------------------------------------------------------------------
    logic        axis_tvalid_int;
    logic [31:0] axis_tdata_int;
    logic        axis_tlast_int;
    logic [0:0]  axis_tuser_int;

    // -------------------------------------------------------------------------
    // Shading pipeline ↔ primary traversal
    // -------------------------------------------------------------------------
    logic        shade_start,      shade_done;
    logic        shade_is_miss;
    logic [1:0]  shade_hit_face;
    logic        shade_hit_face_sign;
    logic [7:0]  shade_block_id;
    logic signed [31:0] shade_t_hit;
    logic signed [31:0] shade_ray_dx, shade_ray_dy, shade_ray_dz;
    logic signed [31:0] shade_hit_px, shade_hit_py, shade_hit_pz;
    logic [23:0] shade_pixel_color;

    // -------------------------------------------------------------------------
    // Shadow traversal ↔ shading pipeline
    // -------------------------------------------------------------------------
    logic        shadow_start, shadow_done, shadow_any_hit;
    logic signed [31:0] shadow_ro_x, shadow_ro_y, shadow_ro_z;
    logic signed [31:0] shadow_rd_x, shadow_rd_y, shadow_rd_z;

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
        .dbg_state(dbg_state_w), .dbg_rs_wait(dbg_rs_wait_w),
        .dbg_px(dbg_px_w), .dbg_py(dbg_py_w),
        .dbg_tvalid(dbg_tvalid_w), .dbg_tready(dbg_tready_w)
    );

    // svo_wr_addr is incremented in the same non-blocking cycle as svo_wr_en is
    // asserted, so by the time svo_wr_en propagates to the BRAM (1 cycle later)
    // addr is already addr+1.  A 1-cycle delayed copy corrects this.
    logic [14:0] svo_wr_addr_lat;
    always_ff @(posedge clk) svo_wr_addr_lat <= svo_wr_addr;

    svo_bram svo_mem (
        .clk_a(clk), .en_a(svo_wr_en),
        .addr_a(svo_wr_addr_lat), .din_a(svo_wr_data),
        .clk_b(clk), .en_b(svo_rd_en_mux),
        .addr_b(svo_rd_addr_mux), .dout_b(svo_rd_data_mux)
    );

    svo_traversal #(.SHADOW_MODE(0), .SHADE_MODE(SHADE_MODE)) traversal (
        .clk(clk), .rst(rst), .start(ctrl_trigger),
        .cam_pos_x(cam_pos_x),   .cam_pos_y(cam_pos_y),   .cam_pos_z(cam_pos_z),
        .cam_right_x(cam_right_x),.cam_right_y(cam_right_y),.cam_right_z(cam_right_z),
        .cam_up_x(cam_up_x),     .cam_up_y(cam_up_y),     .cam_up_z(cam_up_z),
        .cam_fwd_x(cam_fwd_x),   .cam_fwd_y(cam_fwd_y),   .cam_fwd_z(cam_fwd_z),
        .cam_scale(cam_scale),
        .sky_color(sky_color_reg[23:0]),
        .svo_rd_addr(svo_rd_addr_prim), .svo_rd_data(svo_rd_data_prim),
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
        .dbg_tvalid(dbg_tvalid_w), .dbg_tready(dbg_tready_w)
    );

    // Phase 2 only: shading pipeline + shadow traversal
    generate if (SHADE_MODE) begin : g_shading

        shading_pipeline shading (
            .clk(clk), .rst(rst), .start(shade_start),
            .is_miss(shade_is_miss),
            .hit_face(shade_hit_face), .hit_face_sign(shade_hit_face_sign),
            .block_id(shade_block_id), .t_hit(shade_t_hit),
            .ray_dx(shade_ray_dx), .ray_dy(shade_ray_dy), .ray_dz(shade_ray_dz),
            .hit_px(shade_hit_px), .hit_py(shade_hit_py), .hit_pz(shade_hit_pz),
            .light_dir_x(light_dir_x), .light_dir_y(light_dir_y), .light_dir_z(light_dir_z),
            .sky_color(sky_color_reg[23:0]), .fog_color(fog_color_reg[23:0]),
            .fog_start(fog_start_reg), .shadow_bias(shadow_bias_reg),
            .lut('{sky_color_reg[23:0], // reuse lut slots
                   lut[0][23:0], lut[1][23:0], lut[2][23:0],
                   lut[3][23:0], lut[4][23:0]}),
            .shadow_start(shadow_start),
            .shadow_ro_x(shadow_ro_x), .shadow_ro_y(shadow_ro_y), .shadow_ro_z(shadow_ro_z),
            .shadow_rd_x(shadow_rd_x), .shadow_rd_y(shadow_rd_y), .shadow_rd_z(shadow_rd_z),
            .shadow_done(shadow_done), .shadow_hit(shadow_any_hit),
            .pixel_color(shade_pixel_color), .done(shade_done)
        );

        svo_traversal #(.SHADOW_MODE(1), .SHADE_MODE(0)) shadow_trav (
            .clk(clk), .rst(rst), .start(shadow_start),
            .cam_pos_x(shadow_ro_x), .cam_pos_y(shadow_ro_y), .cam_pos_z(shadow_ro_z),
            .cam_fwd_x(shadow_rd_x), .cam_fwd_y(shadow_rd_y), .cam_fwd_z(shadow_rd_z),
            // unused in SHADOW_MODE — tied to zero
            .cam_right_x('0), .cam_right_y('0), .cam_right_z('0),
            .cam_up_x('0),    .cam_up_y('0),    .cam_up_z('0),
            .cam_scale('0),   .sky_color('0),
            .svo_rd_addr(svo_rd_addr_shad), .svo_rd_data(svo_rd_data_shad),
            .svo_rd_en(svo_rd_en_shad),
            .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),
            .axis_tvalid(), .axis_tdata(), .axis_tlast(), .axis_tuser(),
            .axis_tready('0),
            .shade_start(), .shade_is_miss(), .shade_hit_face(), .shade_hit_face_sign(),
            .shade_block_id(), .shade_t_hit(),
            .shade_ray_dx(), .shade_ray_dy(), .shade_ray_dz(),
            .shade_hit_px(), .shade_hit_py(), .shade_hit_pz(),
            .shade_done('0), .shade_pixel_color('0),
            .busy(), .frame_done(shadow_done), .any_hit(shadow_any_hit),
            .dbg_state(), .dbg_rs_wait(),
            .dbg_px(), .dbg_py(),
            .dbg_tvalid(), .dbg_tready()
        );

    end else begin : g_no_shading
        // tie off shading outputs
        assign shade_done        = '0;
        assign shade_pixel_color = '0;
        assign shadow_done       = '0;
        assign shadow_any_hit    = '0;
        assign svo_rd_en_shad    = '0;
        assign svo_rd_addr_shad  = '0;
    end endgenerate

    assign axis_tvalid = axis_tvalid_int;
    assign axis_tdata  = axis_tdata_int;
    assign axis_tkeep  = 4'b1111;
    assign axis_tlast  = axis_tlast_int;
    assign axis_tuser  = axis_tuser_int;

    assign irq = status_frame_done;

endmodule
