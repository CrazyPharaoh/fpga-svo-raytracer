// sim/svo_full_tb.sv — full-system simulation wrapper.
// Instantiates svo_traversal_mr (SHADE_MODE=1) + SHADE_LANES shading pipelines +
// SHADE_LANES shadow traversals. Exposes BRAM-read and AXI-Stream ports so that
// tb_svo_full.py can drive it with the Python bram_model coroutine.
`timescale 1ns/1ps
module svo_full_tb #(
    parameter int IMG_W = 320,   // overridable for the RENDER_DIV fast-sim crop
    parameter int IMG_H = 240,
    parameter int RAY_POOL_N = 4 // primary multi-ray core pool size
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // Camera registers (Q16.16) — same as svo_traversal primary-ray ports
    input  logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    input  logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    input  logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    input  logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    input  logic signed [31:0] cam_scale,

    // Scene colours: packed RGB [23:0] for colours, Q16.16 for distances
    input  logic [23:0] sky_color,
    input  logic [23:0] fog_color,
    input  logic signed [31:0] fog_start,
    input  logic signed [31:0] shadow_bias,

    // Light direction (Q16.16, normalised)
    input  logic signed [31:0] light_dir_x, light_dir_y, light_dir_z,

    // Per-frame animation counter (raw bits)
    input  logic [31:0] time_phase,
    input  logic        shadow_on,
    input  logic [3:0]  max_depth,

    // lut[0..15]: block_id → colour; [31:24]=material flag, [23:0]=RGB
    input  logic [31:0] lut_0, lut_1, lut_2, lut_3, lut_4, lut_5, lut_6, lut_7,
    input  logic [31:0] lut_8, lut_9, lut_10, lut_11, lut_12, lut_13, lut_14, lut_15,

    // SVO BRAM read ports — driven by Python bram_model.
    output logic [11:0]  svo_rd_node_prim,
    input  logic [255:0] svo_rd_wide_prim,
    output logic         svo_rd_en_prim,
    output logic [14:0] svo_rd_addr_shad,    // shadow lane 0
    input  logic [31:0] svo_rd_data_shad,
    output logic        svo_rd_en_shad,
    output logic [14:0] svo_rd_addr_shad1,   // shadow lane 1
    input  logic [31:0] svo_rd_data_shad1,
    output logic        svo_rd_en_shad1,

    // AXI-Stream pixel output
    output logic        axis_tvalid,
    output logic [31:0] axis_tdata,
    output logic        axis_tlast,
    output logic [0:0]  axis_tuser,
    input  logic        axis_tready,

    // Status
    output logic        busy,
    output logic        frame_done,

    // Debug ports (forwarded from primary traversal)
    output logic [3:0]  dbg_state,
    output logic [3:0]  dbg_rs_wait,
    output logic [8:0]  dbg_px,
    output logic [7:0]  dbg_py,
    output logic        dbg_tvalid,
    output logic        dbg_tready
);

    localparam int SHADE_LANES = 2;

    // --- primary traversal ↔ shading handshake signals (one bundle per lane) ---
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

    // --- shading pipeline ↔ shadow traversal handshake signals (one per lane) ---
    logic        shadow_start [0:SHADE_LANES-1], shadow_done [0:SHADE_LANES-1], shadow_any_hit [0:SHADE_LANES-1];
    logic signed [31:0] shadow_ro_x [0:SHADE_LANES-1], shadow_ro_y [0:SHADE_LANES-1], shadow_ro_z [0:SHADE_LANES-1];
    logic signed [31:0] shadow_rd_x [0:SHADE_LANES-1], shadow_rd_y [0:SHADE_LANES-1], shadow_rd_z [0:SHADE_LANES-1];

    // shadow BRAM ports collected into arrays for the generate loop
    logic [14:0] svo_rd_addr_shad_a [0:SHADE_LANES-1];
    logic [31:0] svo_rd_data_shad_a [0:SHADE_LANES-1];
    logic        svo_rd_en_shad_a   [0:SHADE_LANES-1];
    assign svo_rd_addr_shad  = svo_rd_addr_shad_a[0];
    assign svo_rd_en_shad    = svo_rd_en_shad_a[0];
    assign svo_rd_data_shad_a[0] = svo_rd_data_shad;
    assign svo_rd_addr_shad1 = svo_rd_addr_shad_a[1];
    assign svo_rd_en_shad1   = svo_rd_en_shad_a[1];
    assign svo_rd_data_shad_a[1] = svo_rd_data_shad1;

    // LUT: flatten individual ports to unpacked array for shading_pipeline
    logic [31:0] lut_arr [0:15];
    assign lut_arr[0]=lut_0; assign lut_arr[1]=lut_1; assign lut_arr[2]=lut_2;
    assign lut_arr[3]=lut_3; assign lut_arr[4]=lut_4; assign lut_arr[5]=lut_5;
    assign lut_arr[6]=lut_6; assign lut_arr[7]=lut_7; assign lut_arr[8]=lut_8;
    assign lut_arr[9]=lut_9; assign lut_arr[10]=lut_10; assign lut_arr[11]=lut_11;
    assign lut_arr[12]=lut_12; assign lut_arr[13]=lut_13; assign lut_arr[14]=lut_14;
    assign lut_arr[15]=lut_15;

    // --- primary multi-ray traversal (SHADE_MODE=1, SHADOW_MODE=0) ---
    svo_traversal_mr #(.RAY_POOL_N(RAY_POOL_N), .SHADOW_MODE(0), .SHADE_MODE(1), .SHADE_LANES(SHADE_LANES), .IMG_W(IMG_W), .IMG_H(IMG_H)) traversal (
        .clk(clk), .rst(rst), .start(start),
        .cam_pos_x(cam_pos_x),     .cam_pos_y(cam_pos_y),     .cam_pos_z(cam_pos_z),
        .cam_right_x(cam_right_x), .cam_right_y(cam_right_y), .cam_right_z(cam_right_z),
        .cam_up_x(cam_up_x),       .cam_up_y(cam_up_y),       .cam_up_z(cam_up_z),
        .cam_fwd_x(cam_fwd_x),     .cam_fwd_y(cam_fwd_y),     .cam_fwd_z(cam_fwd_z),
        .cam_scale(cam_scale),
        .sky_color(sky_color),
        .max_depth(max_depth),
        .svo_rd_node(svo_rd_node_prim), .svo_rd_wide(svo_rd_wide_prim), .svo_rd_en(svo_rd_en_prim),
        .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),
        .axis_tvalid(axis_tvalid), .axis_tdata(axis_tdata),
        .axis_tlast(axis_tlast),   .axis_tuser(axis_tuser),
        .axis_tready(axis_tready),
        .shade_start(shade_start),
        .shade_is_miss(shade_is_miss),
        .shade_hit_face(shade_hit_face),     .shade_hit_face_sign(shade_hit_face_sign),
        .shade_block_id(shade_block_id),     .shade_t_hit(shade_t_hit),
        .shade_ray_dx(shade_ray_dx),         .shade_ray_dy(shade_ray_dy), .shade_ray_dz(shade_ray_dz),
        .shade_hit_px(shade_hit_px),         .shade_hit_py(shade_hit_py), .shade_hit_pz(shade_hit_pz),
        .shade_done(shade_done),             .shade_pixel_color(shade_pixel_color),
        .busy(busy), .frame_done(frame_done), .any_hit(),
        .dbg_state(dbg_state), .dbg_rs_wait(dbg_rs_wait),
        .dbg_px(dbg_px), .dbg_py(dbg_py),
        .dbg_tvalid(dbg_tvalid), .dbg_tready(dbg_tready),
        .dbg_mr(),
        .dbg_cur_slot(), .dbg_d0(), .dbg_d1()
    );

    // --- SHADE_LANES shading + shadow lanes (must match SHADOW_EN in top.sv) ---
    localparam bit SHADOW_EN = 1'b1;
    generate for (genvar L = 0; L < SHADE_LANES; L++) begin : g_lane
        shading_pipeline shading (
            .clk(clk), .rst(rst), .start(shade_start[L]),
            .is_miss(shade_is_miss[L]),
            .hit_face(shade_hit_face[L]), .hit_face_sign(shade_hit_face_sign[L]),
            .block_id(shade_block_id[L]), .t_hit(shade_t_hit[L]),
            .ray_dx(shade_ray_dx[L]),     .ray_dy(shade_ray_dy[L]),   .ray_dz(shade_ray_dz[L]),
            .hit_px(shade_hit_px[L]),     .hit_py(shade_hit_py[L]),   .hit_pz(shade_hit_pz[L]),
            .light_dir_x(light_dir_x), .light_dir_y(light_dir_y), .light_dir_z(light_dir_z),
            .sky_color(sky_color),     .fog_color(fog_color),
            .fog_start(fog_start),     .shadow_bias(shadow_bias),
            .lut(lut_arr),
            .time_phase(time_phase),
            .shadow_on(shadow_on),
            .shadow_start(shadow_start[L]),
            .shadow_ro_x(shadow_ro_x[L]), .shadow_ro_y(shadow_ro_y[L]), .shadow_ro_z(shadow_ro_z[L]),
            .shadow_rd_x(shadow_rd_x[L]), .shadow_rd_y(shadow_rd_y[L]), .shadow_rd_z(shadow_rd_z[L]),
            .shadow_done(shadow_done[L]), .shadow_hit(shadow_any_hit[L]),
            .pixel_color(shade_pixel_color[L]), .done(shade_done[L])
        );

        if (SHADOW_EN) begin : g_shadow
            svo_traversal #(.SHADOW_MODE(1), .SHADE_MODE(0), .IMG_W(IMG_W), .IMG_H(IMG_H)) shadow_trav (
                .clk(clk), .rst(rst), .start(shadow_start[L]),
                .cam_pos_x(shadow_ro_x[L]), .cam_pos_y(shadow_ro_y[L]), .cam_pos_z(shadow_ro_z[L]),
                .cam_fwd_x(shadow_rd_x[L]), .cam_fwd_y(shadow_rd_y[L]), .cam_fwd_z(shadow_rd_z[L]),
                .cam_right_x('0), .cam_right_y('0), .cam_right_z('0),
                .cam_up_x('0),    .cam_up_y('0),    .cam_up_z('0),
                .cam_scale('0),   .sky_color('0),
                .max_depth(max_depth),
                .svo_rd_addr(svo_rd_addr_shad_a[L]), .svo_rd_data(svo_rd_data_shad_a[L]), .svo_rd_en(svo_rd_en_shad_a[L]),
                .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),
                .axis_tvalid(), .axis_tdata(), .axis_tlast(), .axis_tuser(),
                .axis_tready('0),
                .shade_start(), .shade_is_miss(), .shade_hit_face(), .shade_hit_face_sign(),
                .shade_block_id(), .shade_t_hit(),
                .shade_ray_dx(), .shade_ray_dy(), .shade_ray_dz(),
                .shade_hit_px(), .shade_hit_py(), .shade_hit_pz(),
                .shade_done('0), .shade_pixel_color('0),
                .busy(), .frame_done(shadow_done[L]), .any_hit(shadow_any_hit[L]),
                .dbg_state(), .dbg_rs_wait(), .dbg_px(), .dbg_py(),
                .dbg_tvalid(), .dbg_tready()
            );
        end else begin : g_no_shadow
            assign shadow_done[L]      = 1'b1;
            assign shadow_any_hit[L]   = 1'b0;
            assign svo_rd_en_shad_a[L] = 1'b0;
            assign svo_rd_addr_shad_a[L] = '0;
        end
    end endgenerate

endmodule
