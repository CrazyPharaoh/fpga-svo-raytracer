VERILOG_SOURCES += $(RTL_DIR)/svo_bram.sv
VERILOG_SOURCES += $(RTL_DIR)/shared_qmul3.sv
VERILOG_SOURCES += $(RTL_DIR)/svo_traversal.sv
TOPLEVEL         = svo_traversal
TOPLEVEL_LANG    = verilog
MODULE           = test_svo_traversal
SIM              = verilator

# Fast-sim crop (mirrors sim/Makefile.shade): RENDER_DIV downscales the frame at
# the same FOV so a full render fits under MAX_CYCLES. Post-SP1 ray-setup is
# ~60 cyc/ray, so a full 320x240 (4.6M cyc) exceeds the 3M-cycle timeout.
RENDER_DIV ?= 5
RENDER_W   := $(shell expr 320 / $(RENDER_DIV))
RENDER_H   := $(shell expr 240 / $(RENDER_DIV))
export RENDER_DIV
COMPILE_ARGS += -GIMG_W=$(RENDER_W) -GIMG_H=$(RENDER_H)

# Suppress benign width/case lint (matches sim/Makefile.shade) — Verilator 5.x
# fatals on WIDTHEXPAND otherwise; these are pre-existing zero-extensions that
# Vivado handles fine.
EXTRA_ARGS += --language 1800-2012
EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT

include ../Makefile.common
