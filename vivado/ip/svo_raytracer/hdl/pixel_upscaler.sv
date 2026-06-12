// pixel_upscaler.sv — legacy, not part of the active render pipeline.
// Combinational 2× nearest-neighbour: maps 640×480 HDMI coords to 320×240 framebuffer address.
// fy*320 = fy*256 + fy*64 — two shifts and an add, no DSP.
`timescale 1ns/1ps
module pixel_upscaler (
    input  logic [9:0]  hx,       // HDMI pixel x, 0..639
    input  logic [9:0]  hy,       // HDMI pixel y, 0..479
    output logic [16:0] fb_addr   // framebuffer word address, 0..76799
);
    logic [8:0] fx;
    logic [7:0] fy;

    assign fx = hx[9:1];   // divide by 2 → 0..319
    assign fy = hy[9:1];   // divide by 2 → 0..239

    assign fb_addr = ({9'd0, fy} << 8) + ({9'd0, fy} << 6) + {8'd0, fx};

endmodule
