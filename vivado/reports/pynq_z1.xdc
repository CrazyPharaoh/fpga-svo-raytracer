## SVO raytracer timing constraints for PYNQ-Z1
## Instance hierarchy: svo_system_i/top_0/inst/traversal/...

## Multicycle path for the traversal FSM.
## S_RAY_SETUP stays active for 16 cycles (rs_wait counter 0-15) before registers
## capture — so combinational chains that start from any register (including
## axi_slave cam_* regs) and end in traversal registers have a 160 ns budget.
## Worst measured path: ~115 ns (21 DSP48E1 chain, 2-iter qrecip). 16 × 10 ns = 160 ns ✓
##
## Scope: -to only (no -from) covers:
##   • cam_* (axi_slave) → traversal: cross-module ray-setup paths
##   • px/py (traversal) → traversal: pixel-counter normalisation chain
##   • qmul DSP pipeline regs (traversal) → traversal: Vivado inserts PREG=1 on
##     intermediate DSPs in the qrecip/normalisation cascade (e.g. qmul_return0__9);
##     without -to coverage those sub-paths violate at -105 ns.
##
## DDA single-cycle paths (t_next_*, cx/cy/cz, t_min, etc.) are also destinations
## in traversal* but their combinational depth is ≤8 ns, so they have positive slack
## even under this constraint and Vivado routes them at their natural length.
set_multicycle_path -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal*}] 16
set_multicycle_path -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal*}] 15
