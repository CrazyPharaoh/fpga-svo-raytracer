`timescale 1ns/1ps
// stack_store.sv — all RAY_POOL_N traversal stacks in a single synchronous-read RAM.
// addr = slot * STACK_DEPTH + sp; 1-cycle read latency. Field-opaque (240-bit words).
//
// 240-bit entry layout (mirrors svo_traversal_mr per-ray stack):
//   node_idx[15:0], bitmask[15:0], t_min[31:0], t_max[31:0],
//   t_next_x/y/z[31:0] each, cx/cy/cz[5:0] each,
//   node_half[5:0], orig_x/y/z[5:0] each, +6 pad.
//
// Icarus: (w_slot * STACK_DEPTH + w_sp) is evaluated in 32-bit context (int literal),
// then truncated to [$clog2(DEPTH)-1:0] by the wire assignment — correct with -g2012.

module stack_store #(
    parameter int RAY_POOL_N  = 4,
    parameter int STACK_DEPTH = 12,
    parameter int ENTRY_W     = 240
)(
    input  logic                              clk,
    // write port
    input  logic                              we,
    input  logic [$clog2(RAY_POOL_N)-1:0]     w_slot,
    input  logic [$clog2(STACK_DEPTH)-1:0]    w_sp,
    input  logic [ENTRY_W-1:0]                w_data,
    // read port (synchronous: r_data valid the cycle after r_slot/r_sp registered)
    input  logic [$clog2(RAY_POOL_N)-1:0]     r_slot,
    input  logic [$clog2(STACK_DEPTH)-1:0]    r_sp,
    output logic [ENTRY_W-1:0]                r_data
);
    localparam int DEPTH = RAY_POOL_N * STACK_DEPTH;

    (* ram_style = "block" *)
    logic [ENTRY_W-1:0] mem [0:DEPTH-1];

    wire [$clog2(DEPTH)-1:0] w_addr = w_slot * STACK_DEPTH + w_sp;
    wire [$clog2(DEPTH)-1:0] r_addr = r_slot * STACK_DEPTH + r_sp;

    always_ff @(posedge clk) begin
        if (we) mem[w_addr] <= w_data;
        r_data <= mem[r_addr];
    end

endmodule
