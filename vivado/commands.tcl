# ============================================================================
# Full build — paste this whole block into the Vivado Tcl console.
#   regenerate BD  ->  clean (non-incremental) synth  ->  aggressive timing-opt
#   impl + phys_opt  ->  timing report  ->  (then bitstream once WNS >= 0).
# ============================================================================

# --- Synthesis: force a clean, NON-incremental synth from the current RTL -----
reset_run synth_1

# Disable incremental synthesis. It silently reused a stale checkpoint (top.dcp) and
# kept giving the old netlist no matter what the RTL said. Keep this OFF while iterating.
catch { reset_incremental_synthesis [get_runs synth_1] }

# Clear the IP cache. CRITICAL: cached IP netlists are keyed by the .xci
# customization, NOT the HDL content — so raw edits to ipshared/*.sv (or the IP
# catalog source) are INVISIBLE to a build that hits the cache. This is exactly
# how the axis_upscale_2x SOF-lock fix got silently dropped from a bitstream
# (Bug 14 retest: routed design had no 'synced' register, b1a4 never compiled).
config_ip_cache -clear_output_repo

# Force packaged IPs to re-copy their sources from the IP catalog (FYP/ip) and
# regenerate output products. Without the reset, up-to-date products are reused.
catch { reset_target all [get_ips svo_system_axis_upscale_2x_0_0] }

# Regenerate the block-design wrapper so IP / parameter changes propagate to synth,
# and refresh the ipshared copies of the RTL from the IP source.
generate_target all [get_files -filter {FILE_TYPE == "Block Designs"}]

# Reset any IP out-of-context synthesis run so no stale cached DCP is stitched in.
foreach ip_run [get_runs -filter {IS_SYNTHESIS && NAME =~ "*top_0*"}] {
    reset_run $ip_run
    launch_runs $ip_run -jobs 16
    wait_on_run $ip_run
}

launch_runs synth_1 -jobs 16
wait_on_run synth_1

# --- Implementation: aggressive strategy for the last fraction of a ns ---------
# Worst path is route-dominated (~54% route) and only ~0.5 ns short, so an extra
# timing-opt strategy + post-route phys_opt should close it. (Swap to
# Performance_NetDelay_high if the route delay stays high.)
reset_run impl_1
set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED            true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Run place + route + phys_opt (stop before bitstream so we can check WNS first).
launch_runs impl_1 -to_step route_design -jobs 16
wait_on_run impl_1

# --- Bitstream — uncomment and run AFTER confirming WNS >= 0 above -------------
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
