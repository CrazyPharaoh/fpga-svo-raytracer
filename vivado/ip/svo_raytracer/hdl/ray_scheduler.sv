`timescale 1ns/1ps
// ray_scheduler.sv — round-robin-over-ready arbiter (rotating priority).
// Grants the first ready slot after last_grant (wrapping). Purely combinational.
// NOTE: candidate index uses bit-truncation of (last_grant + i), i.e. mod 2**W,
// which equals mod RAY_POOL_N only when RAY_POOL_N is a power of 2 (our N=4 is).
module ray_scheduler #(
    parameter int RAY_POOL_N = 4
)(
    input  logic [RAY_POOL_N-1:0]            ready,
    input  logic [$clog2(RAY_POOL_N)-1:0]    last_grant,
    output logic                             grant_valid,
    output logic [$clog2(RAY_POOL_N)-1:0]    grant
);
    localparam int W = $clog2(RAY_POOL_N);
    always_comb begin
        grant_valid = 1'b0;
        grant       = '0;
        for (int i = 1; i <= RAY_POOL_N; i++) begin
            // candidate = (last_grant + i) mod RAY_POOL_N, via W-bit truncation
            if (!grant_valid && ready[W'(last_grant + W'(i))]) begin
                grant_valid = 1'b1;
                grant       = W'(last_grant + W'(i));
            end
        end
    end
endmodule
