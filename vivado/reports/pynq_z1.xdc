## SVO raytracer timing constraints for PYNQ-Z1
## Instance hierarchy: svo_system_i/top_0/inst/traversal/...

## S_RAY_SETUP is now fully pipelined — no multicycle path needed there.
## Every stage computes at most one dependent qmul, keeping every path < 10 ns.

## DDA state registers: t_next_x/y/z are written ONLY in
## S_BRAM_WAIT at bram_field=6, which fires ≥9 cycles after the last update
## to the source registers (t_min, rd_*, ro_*, inv_*).
##
## The continuous-assign chain that feeds them is two chained qmuls deep:
##   bw_ex_c   = ro   + qmul(t_min, rd)            [1st qmul, ~13 ns]
##   bw_dist_c = f(bw_ex_c, node_origin, node_half) [LUT logic]
##   t_next_bw = t_min + qmul(bw_dist_c, abs_inv)   [2nd qmul, +13 ns]
## Total path ~26 ns confirmed in timing report (logic 19 ns + route 7 ns).
## Budget = 4 cycles × 10 ns = 40 ns.
##
## Hold multiplier = N-1 = 3 restores the ORIGINAL hold position (t=0 ns).
## Formula (UG903): hold_cycles = setup_mult - 1 - hold_mult
##   → 4 - 1 - 3 = 0 hold cycles → check at t=0 ns → trivially met.
##
## WRONG (used previously): hold_mult=0
##   → 4 - 1 - 0 = 3 hold cycles → 30 ns minimum path → impossible for
##   the 0.75 ns carry-chain paths within t_next itself, causing Vivado
##   to insert routing detours and destroying setup timing.
##
## The t_next registers also receive short carry-chain paths from their own
## bits (e.g. t_next_z_reg[7] → adder → t_next_z_reg[8], 0.75 ns) in
## S_EMPTY. With hold restored to 0 cycles, these trivially pass.
set_multicycle_path 4 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_x_reg*}]
set_multicycle_path 3 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_x_reg*}]
set_multicycle_path 4 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_y_reg*}]
set_multicycle_path 3 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_y_reg*}]
set_multicycle_path 4 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_z_reg*}]
set_multicycle_path 3 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/t_next_z_reg*}]

## dt_x/y/z: bw_abs_i*_c negation-before-DSP gives ~12 ns path.
## Captured only when sources are stable for 2+ cycles:
##   - S_BRAM_WAIT field=6: inv_* stable since S_RAY_SETUP; node_half stable since S_MIXED/S_IDLE
##     (both at least 10 cycles before field=6, same negation path feeds dt_*_bw_c and dt_*_pop_c)
##   - S_POP_STACK: inv_* per-ray constant; stk_node_half[sp-1] (pre-decrement sp) stable since S_MIXED
## setup=2 → 20 ns budget (fits 2 ns CARRY4 + 8 ns DSP + routing).
##
## hold=1 is MANDATORY. Formula (UG903): hold_cycles = setup_mult - 1 - hold_mult
##   → 2 - 1 - 1 = 0 hold cycles → trivially met for all paths.
## WARNING: hold=0 (Vivado default) → 2 - 1 - 0 = 1 hold cycle → 10 ns minimum path
##   → impossible for short intra-register carry paths → Vivado inserts routing detours
##   → setup timing destroyed (same failure mode documented for t_next_* above).
set_multicycle_path 2 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_x_reg*}]
set_multicycle_path 1 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_x_reg*}]
set_multicycle_path 2 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_y_reg*}]
set_multicycle_path 1 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_y_reg*}]
set_multicycle_path 2 -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_z_reg*}]
set_multicycle_path 1 -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal/dt_z_reg*}]
