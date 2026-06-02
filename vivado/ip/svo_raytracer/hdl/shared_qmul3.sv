`timescale 1ns/1ps
// shared_qmul3.sv — 3-lane, fixed-latency Q16.16 multiplier.
// p_i = (a_i * b_i)[47:16], valid LAT cycles after a_i/b_i are presented.
// Each lane is independent and fully pipelined (input reg -> product reg ->
// output slice reg) so it packs into DSP48 pipeline registers. LAT = 3.
module shared_qmul3 #(
    parameter int LAT = 3   // pipeline depth of each lane (this impl is 3)
)(
    input  logic               clk,
    input  logic signed [31:0] a0, b0,
    input  logic signed [31:0] a1, b1,
    input  logic signed [31:0] a2, b2,
    output logic signed [31:0] p0, p1, p2
);
    logic signed [31:0] a0_r, b0_r, a1_r, b1_r, a2_r, b2_r;
    logic signed [63:0] m0, m1, m2;
    always_ff @(posedge clk) begin
        a0_r <= a0; b0_r <= b0;        // stage 1: input registers
        a1_r <= a1; b1_r <= b1;
        a2_r <= a2; b2_r <= b2;
        m0   <= a0_r * b0_r;           // stage 2: product register
        m1   <= a1_r * b1_r;
        m2   <= a2_r * b2_r;
        p0   <= m0[47:16];             // stage 3: output register
        p1   <= m1[47:16];
        p2   <= m2[47:16];
    end
endmodule
