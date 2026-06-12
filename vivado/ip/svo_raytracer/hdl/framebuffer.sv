// framebuffer.sv — legacy, not connected in the current design.
// True dual-port BRAM, 320×240 = 76800 × 24-bit RGB.
// Write: ray pipeline @ clk_sys. Read: HDMI controller @ clk_pixel.
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

    // Zero-init for simulation; synthesis ignores initial blocks.
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
