// svo_bram.sv
// True dual-port block RAM for SVO node storage.
// Port A: write-only (AXI-Lite loader)
// Port B: read-only  (traversal FSM)
// Depth: 4096 nodes × 8 words/node = 32768 × 32-bit words
`timescale 1ns/1ps
module svo_bram (
    // Port A — write (AXI loader)
    input  logic        clk_a,
    input  logic        en_a,
    input  logic [14:0] addr_a,
    input  logic [31:0] din_a,

    // Port B — read (traversal FSM)
    input  logic        clk_b,
    input  logic        en_b,
    input  logic [14:0] addr_b,
    output logic [31:0] dout_b
);
    (* ram_style = "block" *)
    logic [31:0] mem [0:32767];

    // Initialise to 0 so simulation starts clean (synthesis ignores this).
    initial begin
        integer i;
        for (i = 0; i < 32768; i++) mem[i] = '0;
        dout_b = '0;
    end

    always @(posedge clk_a)
        if (en_a) mem[addr_a] <= din_a;

    always @(posedge clk_b)
        if (en_b) dout_b <= mem[addr_b];

endmodule
