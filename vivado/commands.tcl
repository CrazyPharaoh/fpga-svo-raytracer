# Full build — paste into the Vivado Tcl console.
#   BD regenerate -> non-incremental synth -> aggressive impl + phys_opt
#   -> timing report -> bitstream (once WNS >= 0).

# Non-incremental synth from current RTL
reset_run synth_1
catch { reset_incremental_synthesis [get_runs synth_1] }

# Clear IP cache — cached netlists are keyed by .xci, not HDL content,
# so edits to IP source files are invisible without this.
config_ip_cache -clear_output_repo

# Reset packaged-IP output products so sources are re-copied from the IP catalog.
catch { reset_target all [get_ips svo_system_axis_upscale_2x_0_0] }

# Regenerate BD wrapper so IP/parameter changes propagate to synth.
generate_target all [get_files -filter {FILE_TYPE == "Block Designs"}]

# Reset and re-run OOC synth for the raytracer IP so no stale DCP is stitched in.
foreach ip_run [get_runs -filter {IS_SYNTHESIS && NAME =~ "*top_0*"}] {
    reset_run $ip_run
    launch_runs $ip_run -jobs 16
    wait_on_run $ip_run
}

launch_runs synth_1 -jobs 16
wait_on_run synth_1

# Aggressive impl strategy + phys_opt for timing closure
reset_run impl_1
set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED            true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Stop after route so WNS can be checked before writing the bitstream.
launch_runs impl_1 -to_step route_design -jobs 16
wait_on_run impl_1

# Uncomment once WNS >= 0:
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
