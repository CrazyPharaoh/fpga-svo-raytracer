// svo_bram.sv — true dual-port block RAM for SVO node storage.
// Port A: 32-bit write (AXI-Lite loader).
// Port B: 32-bit read  (traversal FSM).
// Depth: 4096 nodes × 8 words/node = 32768 × 32-bit words.
`timescale 1ns/1ps
module svo_bram (
    input  logic        clk_a,
    input  logic        en_a,
    input  logic [14:0] addr_a,
    input  logic [31:0] din_a,
    output logic [31:0] dout_a,

    input  logic        clk_b,
    input  logic        en_b,
    input  logic [14:0] addr_b,
    output logic [31:0] dout_b
);
    (* ram_style = "block" *)
    logic [31:0] mem [0:32767];

    // Zero-init for clean simulation; synthesis ignores initial blocks.
    initial begin
        integer i;
        for (i = 0; i < 32768; i++) mem[i] = '0;
        dout_a = '0;
        dout_b = '0;
    end

    always @(posedge clk_a) begin
        if (en_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk_b)
        if (en_b) dout_b <= mem[addr_b];

endmodule
