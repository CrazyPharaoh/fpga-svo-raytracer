`timescale 1ns/1ps
// svo_bram_shadow.sv — geometry-only SVO copy (words 0–4) for one shadow lane.
//
// One instance per shading lane, all written in parallel by the loader.
// Each word-plane has one write port + one read port and infers as BLOCK RAM.
// A shared dual-read-port design (write+2-reads) exceeds BRAM port count and falls
// back to LUTRAM; separate instances avoid this.
//
//   Port A: 32-bit write (loader, words 0–4), addr_a = {node[11:0], word[2:0]}.
//   Port B: 32-bit read (this lane), addr_b = {node[11:0], word[2:0]}.
//   Words 5–7 return 0 (shadow traversal reads all 8 words but ignores 5–7).
module svo_bram_shadow (
    input  logic        clk,
    input  logic        en_a,
    input  logic [14:0] addr_a,
    input  logic [31:0] din_a,
    input  logic [14:0] addr_b,
    output logic [31:0] dout_b         // 1-cycle registered read
);
    localparam int GW = 5;             // geometry word-planes (w0..w4)
    wire [11:0] na = addr_a[14:3];  wire [2:0] wa = addr_a[2:0];
    wire [11:0] nb = addr_b[14:3];  wire [2:0] wb = addr_b[2:0];

    logic [31:0] rd_cand [0:GW-1];     // per-plane registered read

    genvar g;
    generate for (g = 0; g < GW; g++) begin : plane
        (* ram_style = "block" *) logic [31:0] m [0:4095];
        initial for (int i = 0; i < 4096; i++) m[i] = '0;
        always @(posedge clk) if (en_a && wa == g[2:0]) m[na] <= din_a;
        always @(posedge clk) rd_cand[g] <= m[nb];
    end endgenerate

    // wb_q delays the word index by 1 cycle to align with the registered read data.
    logic [2:0] wb_q;
    always @(posedge clk) wb_q <= wb;
    wire [2:0] wb_qc = (wb_q < 3'(GW)) ? wb_q : 3'd0;
    assign dout_b = (wb_q < 3'(GW)) ? rd_cand[wb_qc] : 32'd0;

endmodule
