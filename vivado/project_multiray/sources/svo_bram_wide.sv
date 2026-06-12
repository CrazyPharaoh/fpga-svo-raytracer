`timescale 1ns/1ps
// svo_bram_wide.sv — 8-word-plane SVO RAM with 256-bit whole-node read port.
//
// Implemented as 8 independent 1D arrays so Vivado infers each as a separate BRAM.
// A single 2D array [0:7][0:4095] is treated as a 1M-bit variable and fails; a single
// asymmetric 256-bit array falls back to LUTRAM. Eight 32-bit planes avoid both.
//
//   Port A: 32-bit write (loader), addr_a = {node[11:0], word[2:0]}.
//   Port B: 256-bit whole-node read; dout_b_wide[w*32 +: 32] = word w.
module svo_bram_wide (
    input  logic         clk_a,
    input  logic         en_a,
    input  logic [14:0]  addr_a,        // {node[11:0], word[2:0]}
    input  logic [31:0]  din_a,
    output logic [31:0]  dout_a,

    input  logic         clk_b,
    input  logic         en_b,
    input  logic [11:0]  addr_b_node,   // node index
    output logic [255:0] dout_b_wide
);
    wire [11:0] na = addr_a[14:3];
    wire [2:0]  wa = addr_a[2:0];

    assign dout_a = '0;   // Port A is write-only here

    genvar g;
    generate for (g = 0; g < 8; g++) begin : plane
        (* ram_style = "block" *) logic [31:0] m [0:4095];
        initial for (int i = 0; i < 4096; i++) m[i] = '0;
        always @(posedge clk_a)
            if (en_a && wa == g[2:0]) m[na] <= din_a;
        always @(posedge clk_b)
            if (en_b) dout_b_wide[g*32 +: 32] <= m[addr_b_node];
    end endgenerate

endmodule
