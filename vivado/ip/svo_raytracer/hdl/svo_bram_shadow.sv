`timescale 1ns/1ps
// svo_bram_shadow.sv — geometry-only SVO copy (w0-w4) for ONE shadow lane.
//
// Write port (loader) + ONE narrow read port (this lane). Instantiate once PER shading
// lane (both written by the loader in parallel). Built as word-planes like svo_bram_wide,
// so each plane is write+1-read and infers BLOCK RAM. (A single dual-READ-port version is
// write+2-reads, which exceeds a block RAM's 2 ports -> Vivado reports ram_style="block"
// infeasible and dumps the whole thing into LUTRAM. Two single-read copies infer cleanly.)
//
//   Port A: 32-bit write (loader, w0-w4 only), addr_a = {node[11:0], word[2:0]}.
//   Port B: 32-bit read (this lane), addr_b = {node[11:0], word[2:0]}.
//   Words 5-7 read back as 0 (unused by the shadow), so the unmodified svo_traversal
//   shadow core (which reads all 8 words) works as-is.
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
        always @(posedge clk) if (en_a && wa == g[2:0]) m[na] <= din_a; // port A write
        always @(posedge clk) rd_cand[g] <= m[nb];                       // port B read
    end endgenerate

    // Select the requested word (1-cycle delayed word index aligns with the registered read).
    logic [2:0] wb_q;
    always @(posedge clk) wb_q <= wb;
    wire [2:0] wb_qc = (wb_q < 3'(GW)) ? wb_q : 3'd0;
    assign dout_b = (wb_q < 3'(GW)) ? rd_cand[wb_qc] : 32'd0;

endmodule
