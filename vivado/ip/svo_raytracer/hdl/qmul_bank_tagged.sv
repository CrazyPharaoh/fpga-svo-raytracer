`timescale 1ns/1ps
// qmul_bank_tagged.sv — shared_qmul3 (LAT=3) + a tag pipeline so each product
// emerges labelled with the {slot,dest} that issued it. QCOL = LAT + 1 = 4:
// one cycle for the wrapper's operand register + 3 for the bank.
// Products p0/p1/p2 are valid the cycle res_valid is high, tagged by res_tag.
module qmul_bank_tagged #(
    parameter int TAG_W = 8,
    parameter int QCOL  = 4
)(
    input  logic               clk,
    input  logic               iss_valid,
    input  logic [TAG_W-1:0]   iss_tag,
    input  logic signed [31:0] a0, b0, a1, b1, a2, b2,
    output logic               res_valid,
    output logic [TAG_W-1:0]   res_tag,
    output logic signed [31:0] p0, p1, p2
);
    // One cycle of operand registration before feeding the bank.
    // This is the +1 that makes QCOL = LAT+1 = 4.
    logic signed [31:0] a0_r, b0_r, a1_r, b1_r, a2_r, b2_r;
    always_ff @(posedge clk) begin
        a0_r <= a0; b0_r <= b0;
        a1_r <= a1; b1_r <= b1;
        a2_r <= a2; b2_r <= b2;
    end

    // 3-lane shared multiplier bank (LAT=3 internally).
    shared_qmul3 #(.LAT(3)) u_bank (
        .clk (clk),
        .a0  (a0_r), .b0 (b0_r),
        .a1  (a1_r), .b1 (b1_r),
        .a2  (a2_r), .b2 (b2_r),
        .p0  (p0),   .p1 (p1),   .p2 (p2)
    );

    // Tag/valid pipeline, depth QCOL = LAT+1 = 4.
    // v_pipe[0]/t_pipe[0] capture iss_valid/iss_tag in the same cycle as
    // the operand registers, so both pipelines advance in lock-step.
    // res_valid/res_tag appear at v_pipe[QCOL-1] exactly when p0/p1/p2 are valid.
    logic             v_pipe [0:QCOL-1];
    logic [TAG_W-1:0] t_pipe [0:QCOL-1];

    // Initialise to 0 so Icarus does not propagate X through the valid flag.
    initial begin
        for (int i = 0; i < QCOL; i++) begin
            v_pipe[i] = 1'b0;
            t_pipe[i] = '0;
        end
    end

    always_ff @(posedge clk) begin
        v_pipe[0] <= iss_valid;
        t_pipe[0] <= iss_tag;
        for (int i = 1; i < QCOL; i++) begin
            v_pipe[i] <= v_pipe[i-1];
            t_pipe[i] <= t_pipe[i-1];
        end
    end

    assign res_valid = v_pipe[QCOL-1];
    assign res_tag   = t_pipe[QCOL-1];

endmodule
