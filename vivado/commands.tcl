# Regenerate block design wrapper so any IP parameter changes (e.g. SHADE_MODE)
# propagate into the synthesis netlist before it runs.
generate_target all [get_files -filter {FILE_TYPE == "Block Designs"}]

# Reset the IP OOC synthesis run so Vivado never uses a stale cached DCP.
# The IP run name matches the block design instance: top_0_0.
foreach ip_run [get_runs -filter {IS_SYNTHESIS && NAME =~ "*top_0*"}] {
    reset_run $ip_run
    launch_runs $ip_run -jobs 16
    wait_on_run $ip_run
}

launch_runs synth_1 -jobs 16
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {error "Synthesis failed"}

launch_runs impl_1 -jobs 16
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {error "Implementation failed"}

launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
