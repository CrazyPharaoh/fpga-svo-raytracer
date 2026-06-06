`timescale 1ns/1ps
// svo_bram_wide.sv — whole-node SVO RAM (M2 wide read), as 8 SEPARATE word-plane RAMs.
//
// Each plane is a simple 1D `logic [31:0] m [0:4095]` — the exact pattern the original
// svo_bram used and which Vivado reliably infers as BLOCK RAM. (A single 2D array
// mem[0:7][0:4095] is treated as one 1M-bit variable and errors out; the asymmetric
// 256-bit single-array form falls back to LUTRAM. Separate 1D planes avoid both.)
//
//   Port A: 32-bit write (loader, addr_a = {node[11:0], word[2:0]}). dout_a unused here
//           (shadows read the dedicated svo_bram_shadow).
//   Port B: 256-bit whole-node read; dout_b_wide[w*32 +: 32] = node word w.
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
        // write the selected word-plane
        always @(posedge clk_a)
            if (en_a && wa == g[2:0]) m[na] <= din_a;
        // wide read: every plane drives its 32-bit slice every cycle
        always @(posedge clk_b)
            if (en_b) dout_b_wide[g*32 +: 32] <= m[addr_b_node];
    end endgenerate

endmodule
