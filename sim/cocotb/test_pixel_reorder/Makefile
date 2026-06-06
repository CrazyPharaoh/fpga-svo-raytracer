VERILOG_SOURCES += $(RTL_DIR)/pixel_reorder.sv
TOPLEVEL         = pixel_reorder
MODULE           = test_pixel_reorder
TOPLEVEL_LANG    = verilog
ifeq ($(SIM),verilator)
  COMPILE_ARGS  += -GIMG_W=4 -GIMG_H=2 -GRAY_POOL_N=4
else
  COMPILE_ARGS  += -Ppixel_reorder.IMG_W=4 -Ppixel_reorder.IMG_H=2 -Ppixel_reorder.RAY_POOL_N=4
endif
include ../Makefile.common
