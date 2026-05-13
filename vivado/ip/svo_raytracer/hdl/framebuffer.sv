// framebuffer.sv
// True dual-port framebuffer BRAM.
// Write port: ray/shading pipeline @ clk_sys (100 MHz)
// Read  port: HDMI controller      @ clk_pixel (25.175 MHz)
// Size: 320×240 = 76800 pixels × 24-bit RGB
`timescale 1ns/1ps
module framebuffer (
    input  logic        wr_clk,
    input  logic        wr_en,
    input  logic [16:0] wr_addr,   // 0..76799
    input  logic [23:0] wr_data,   // {R,G,B}

    input  logic        rd_clk,
    input  logic        rd_en,
    input  logic [16:0] rd_addr,
    output logic [23:0] rd_data
);
    (* ram_style = "block" *)
    logic [23:0] mem [0:76799];

    // Initialise to 0 so simulation starts clean (synthesis ignores this).
    initial begin
        integer i;
        for (i = 0; i < 76800; i++) mem[i] = '0;
        rd_data = '0;
    end

    always @(posedge wr_clk)
        if (wr_en) mem[wr_addr] <= wr_data;

    always @(posedge rd_clk)
        if (rd_en) rd_data <= mem[rd_addr];

endmodule
