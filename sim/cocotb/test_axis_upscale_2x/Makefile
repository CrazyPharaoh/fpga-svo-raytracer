VERILOG_SOURCES += $(RTL_DIR)/axis_upscale_2x.sv
TOPLEVEL         = axis_upscale_2x
MODULE           = test_axis_upscale_2x
TOPLEVEL_LANG    = verilog

# tiny frame for a fast, exhaustive framing test (logic is size-independent)
COMPILE_ARGS    += -Paxis_upscale_2x.IN_W=4 -Paxis_upscale_2x.IN_H=3

include ../Makefile.common
