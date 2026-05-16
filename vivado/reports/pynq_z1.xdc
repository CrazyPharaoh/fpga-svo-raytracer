## SVO raytracer timing constraints for PYNQ-Z1
## Instance hierarchy: svo_system_i/top_0/inst/traversal/...

## Multicycle path for the traversal FSM.
## S_RAY_SETUP stays active for 11 cycles (rs_wait counter) before registers
## capture — so combinational chains that start from any register (including
## axi_slave cam_* regs) and end in traversal registers have a 110 ns budget.
## Worst measured path: ~79 ns (14 DSP48E1 chain). 11 × 10 ns = 110 ns ✓
## -to only (no -from) so cross-module axi_slave→traversal paths are covered.
set_multicycle_path -setup -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal*}] 11
set_multicycle_path -hold  -to [get_cells -hierarchical -filter {NAME =~ *top_0/inst/traversal*}] 10
