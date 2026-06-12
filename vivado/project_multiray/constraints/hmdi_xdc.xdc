# hdmi_out.xdc — PYNQ-Z1 HDMI OUT (TMDS) pin constraints
# Add this file to the Vivado project (Add Sources -> Add constraints).
# Pin assignments from the Digilent PYNQ-Z1 master XDC / the maths-accelerator
# reference design (~/git/EE2Project/maths-accelerator/overlay/src/base.xdc).
#
# The external port names below MUST match the ports made external from
# rgb2dvi_0's TMDS interface in the block design (see HDMI_GUIDE.md Part 6):
#   hdmi_out_clk_p/n, hdmi_out_data_p/n[2:0], hdmi_out_hpd[0]

set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports hdmi_out_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports hdmi_out_clk_p]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_p[0]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {hdmi_out_data_p[2]}]

# Hot-plug detect — NOT used in Phase 1 (no hdmi_out_hpd port in the block design).
# Leave commented unless you add an hdmi_out_hpd external port (e.g. via axi_gpio).
# set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports {hdmi_out_hpd[0]}]
