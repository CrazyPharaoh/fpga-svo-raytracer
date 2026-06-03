`timescale 1ns/1ps
// ray_scheduler.sv — round-robin-over-ready arbiter.
// Given a ready bitmask and the last granted slot, grant the next ready slot
// in rotating priority (last_grant+1, +2, ... wrap). Purely combinational; the
// caller registers last_grant from grant when grant_valid.
module ray_scheduler #(
    parameter int RAY_POOL_N = 4
)(
    input  logic [RAY_POOL_N-1:0]            ready,
    input  logic [$clog2(RAY_POOL_N)-1:0]    last_grant,
    output logic                             grant_valid,
    output logic [$clog2(RAY_POOL_N)-1:0]    grant
);
    // Temporary index variable declared outside the loop for Icarus compatibility
    // (Icarus does not support 'automatic' variable lifetime override in always_comb).
    int idx;

    always_comb begin
        grant_valid = 1'b0;
        grant       = '0;
        // Scan slots in rotating order starting at last_grant+1.
        for (int i = 1; i <= RAY_POOL_N; i++) begin
            idx = (last_grant + i) % RAY_POOL_N;
            if (!grant_valid && ready[idx]) begin
                grant_valid = 1'b1;
                grant       = idx[$clog2(RAY_POOL_N)-1:0];
            end
        end
    end
endmodule
