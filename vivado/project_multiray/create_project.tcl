#==============================================================================
# create_project.tcl — recreate the svo_system Vivado project from the source
# files committed in this folder (no large generated run/cache dirs needed).
#
# Run it from the Vivado Tcl console:
#       cd <path-to-this-folder>
#       source create_project.tcl
#
# or in batch mode:
#       vivado -mode batch -source create_project.tcl
#
# Target: PYNQ-Z1, Xilinx Zynq-7020 (xc7z020clg400-1). Built with Vivado 2025.2.
# After this finishes, build the bitstream with:   source commands.tcl
#==============================================================================

set origin    [file normalize [file dirname [info script]]]
set proj_name svo_raytracer
set proj_dir  $origin/build

# --- Fresh project on the PYNQ-Z1 part + board --------------------------------
create_project $proj_name $proj_dir -part xc7z020clg400-1 -force
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

# --- Point the IP catalog at the two custom IPs so the BD can resolve them ----
#   sources/ = svo_raytracer (the render core)   ip/ = axis_upscale_2x (HDMI 2x)
set_property ip_repo_paths [list $origin/sources $origin/ip] [current_project]
update_ip_catalog

# --- Bring in the block design (its IP .xci configs travel under bd/) ----------
read_bd $origin/bd/svo_system/svo_system.bd
generate_target all [get_files svo_system.bd]

# --- Generate + import the HDL wrapper and make it the synthesis top ----------
make_wrapper -files [get_files svo_system.bd] -top -import
set_property top svo_system_wrapper [current_fileset]

# --- HDMI-OUT pin / timing constraints ----------------------------------------
add_files -fileset constrs_1 -norecurse $origin/constraints/hmdi_xdc.xdc

update_compile_order -fileset sources_1

puts "================================================================"
puts " Project created in: $proj_dir"
puts " Next:  source commands.tcl    (synth -> impl -> write_bitstream)"
puts "================================================================"
