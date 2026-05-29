// sim/svo_full_tb.sv
// Simulation wrapper: primary traversal (SHADE_MODE=1) + shading_pipeline +
// shadow traversal (SHADOW_MODE=1), with BRAM arbiter.
// Exposes the same BRAM-read and AXI-Stream ports as svo_traversal.sv so that
// tb_svo_full.py can reuse the existing Python bram_model coroutine.
`timescale 1ns/1ps
module svo_full_tb (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // Camera registers (Q16.16) — same as svo_traversal primary-ray ports
    input  logic signed [31:0] cam_pos_x,   cam_pos_y,   cam_pos_z,
    input  logic signed [31:0] cam_right_x, cam_right_y, cam_right_z,
    input  logic signed [31:0] cam_up_x,    cam_up_y,    cam_up_z,
    input  logic signed [31:0] cam_fwd_x,   cam_fwd_y,   cam_fwd_z,
    input  logic signed [31:0] cam_scale,

    // Scene colours (Q16.16 packed RGB for colours, Q16.16 distances)
    input  logic [23:0] sky_color,
    input  logic [23:0] fog_color,
    input  logic signed [31:0] fog_start,
    input  logic signed [31:0] shadow_bias,

    // Light direction (Q16.16, normalised)
    input  logic signed [31:0] light_dir_x, light_dir_y, light_dir_z,

    // Colour LUT: 6 entries, RGB packed [23:16]=R [15:8]=G [7:0]=B
    // lut_0..5 map to block_id 0..5 in shading_pipeline
    input  logic [23:0] lut_0, lut_1, lut_2, lut_3, lut_4, lut_5,

    // SVO BRAM read port (Python bram_model drives svo_rd_data)
    output logic [14:0] svo_rd_addr,
    input  logic [31:0] svo_rd_data,
    output logic        svo_rd_en,

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

    // -------------------------------------------------------------------------
    // Primary traversal ↔ shading pipeline
    // -------------------------------------------------------------------------
    logic        shade_start,   shade_done;
    logic        shade_is_miss;
    logic [1:0]  shade_hit_face;
    logic        shade_hit_face_sign;
    logic [7:0]  shade_block_id;
    logic signed [31:0] shade_t_hit;
    logic signed [31:0] shade_ray_dx, shade_ray_dy, shade_ray_dz;
    logic signed [31:0] shade_hit_px, shade_hit_py, shade_hit_pz;
    logic [23:0] shade_pixel_color;

    // -------------------------------------------------------------------------
    // Shading pipeline ↔ shadow traversal
    // -------------------------------------------------------------------------
    logic        shadow_start, shadow_done, shadow_any_hit;
    logic signed [31:0] shadow_ro_x, shadow_ro_y, shadow_ro_z;
    logic signed [31:0] shadow_rd_x, shadow_rd_y, shadow_rd_z;

    // -------------------------------------------------------------------------
    // BRAM arbiter: primary wins; shadow gets access when primary idle
    // (mirrors the arbiter in top.sv)
    // -------------------------------------------------------------------------
    logic [14:0] svo_rd_addr_prim, svo_rd_addr_shad;
    logic        svo_rd_en_prim,   svo_rd_en_shad;

    always_comb begin
        if (svo_rd_en_prim) begin
            svo_rd_addr = svo_rd_addr_prim;
            svo_rd_en   = 1'b1;
        end else begin
            svo_rd_addr = svo_rd_addr_shad;
            svo_rd_en   = svo_rd_en_shad;
        end
    end
    // Both traversals share the single read-data bus
    // svo_rd_data is driven by the Python bram_model from outside

    // -------------------------------------------------------------------------
    // LUT: individual ports → unpacked array for shading_pipeline
    // -------------------------------------------------------------------------
    logic [31:0] lut_arr [0:5];
    assign lut_arr[0] = lut_0;
    assign lut_arr[1] = lut_1;
    assign lut_arr[2] = lut_2;
    assign lut_arr[3] = lut_3;
    assign lut_arr[4] = lut_4;
    assign lut_arr[5] = lut_5;

    // -------------------------------------------------------------------------
    // Primary traversal — SHADE_MODE=1, SHADOW_MODE=0
    // -------------------------------------------------------------------------
    svo_traversal #(.SHADOW_MODE(0), .SHADE_MODE(1)) traversal (
        .clk(clk), .rst(rst), .start(start),
        .cam_pos_x(cam_pos_x),     .cam_pos_y(cam_pos_y),     .cam_pos_z(cam_pos_z),
        .cam_right_x(cam_right_x), .cam_right_y(cam_right_y), .cam_right_z(cam_right_z),
        .cam_up_x(cam_up_x),       .cam_up_y(cam_up_y),       .cam_up_z(cam_up_z),
        .cam_fwd_x(cam_fwd_x),     .cam_fwd_y(cam_fwd_y),     .cam_fwd_z(cam_fwd_z),
        .cam_scale(cam_scale),
        .sky_color(sky_color),
        .svo_rd_addr(svo_rd_addr_prim), .svo_rd_data(svo_rd_data), .svo_rd_en(svo_rd_en_prim),
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
        .dbg_tvalid(dbg_tvalid), .dbg_tready(dbg_tready)
    );

    // -------------------------------------------------------------------------
    // Shading pipeline
    // -------------------------------------------------------------------------
    shading_pipeline shading (
        .clk(clk), .rst(rst), .start(shade_start),
        .is_miss(shade_is_miss),
        .hit_face(shade_hit_face), .hit_face_sign(shade_hit_face_sign),
        .block_id(shade_block_id), .t_hit(shade_t_hit),
        .ray_dx(shade_ray_dx),     .ray_dy(shade_ray_dy),   .ray_dz(shade_ray_dz),
        .hit_px(shade_hit_px),     .hit_py(shade_hit_py),   .hit_pz(shade_hit_pz),
        .light_dir_x(light_dir_x), .light_dir_y(light_dir_y), .light_dir_z(light_dir_z),
        .sky_color(sky_color),     .fog_color(fog_color),
        .fog_start(fog_start),     .shadow_bias(shadow_bias),
        .lut(lut_arr),
        .shadow_start(shadow_start),
        .shadow_ro_x(shadow_ro_x), .shadow_ro_y(shadow_ro_y), .shadow_ro_z(shadow_ro_z),
        .shadow_rd_x(shadow_rd_x), .shadow_rd_y(shadow_rd_y), .shadow_rd_z(shadow_rd_z),
        .shadow_done(shadow_done), .shadow_hit(shadow_any_hit),
        .pixel_color(shade_pixel_color), .done(shade_done)
    );

    // -------------------------------------------------------------------------
    // Shadow traversal — SHADOW_MODE=1, SHADE_MODE=0
    // -------------------------------------------------------------------------
    svo_traversal #(.SHADOW_MODE(1), .SHADE_MODE(0)) shadow_trav (
        .clk(clk), .rst(rst), .start(shadow_start),
        .cam_pos_x(shadow_ro_x), .cam_pos_y(shadow_ro_y), .cam_pos_z(shadow_ro_z),
        .cam_fwd_x(shadow_rd_x), .cam_fwd_y(shadow_rd_y), .cam_fwd_z(shadow_rd_z),
        .cam_right_x('0), .cam_right_y('0), .cam_right_z('0),
        .cam_up_x('0),    .cam_up_y('0),    .cam_up_z('0),
        .cam_scale('0),   .sky_color('0),
        .svo_rd_addr(svo_rd_addr_shad), .svo_rd_data(svo_rd_data), .svo_rd_en(svo_rd_en_shad),
        .fb_wr_addr(), .fb_wr_data(), .fb_wr_en(),
        .axis_tvalid(), .axis_tdata(), .axis_tlast(), .axis_tuser(),
        .axis_tready('0),
        .shade_start(), .shade_is_miss(), .shade_hit_face(), .shade_hit_face_sign(),
        .shade_block_id(), .shade_t_hit(),
        .shade_ray_dx(), .shade_ray_dy(), .shade_ray_dz(),
        .shade_hit_px(), .shade_hit_py(), .shade_hit_pz(),
        .shade_done('0), .shade_pixel_color('0),
        .busy(), .frame_done(shadow_done), .any_hit(shadow_any_hit),
        .dbg_state(), .dbg_rs_wait(), .dbg_px(), .dbg_py(),
        .dbg_tvalid(), .dbg_tready()
    );

endmodule
