# sim/Makefile
# cocotb + Verilator testbench for svo_traversal.sv (Phase 1)
# and svo_full_tb.sv (Phase 2, full shading + shadows).

SIM           ?= verilator
TOPLEVEL_LANG ?= verilog

EXTRA_ARGS  = --language 1800-2012
EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE
EXTRA_ARGS += -Wno-UNOPTFLAT
EXTRA_ARGS += --public-flat-rw

OUTPUT_DIR = output
$(shell mkdir -p $(OUTPUT_DIR))

RTL_DIR = $(abspath ../vivado/ip/svo_raytracer/hdl)

# ─── Fast-sim crop ───────────────────────────────────────────────────────────
# RENDER_DIV downscales the render by an integer factor (same FOV), gating
# correctness ~DIV^2 faster. Drives both the RTL build (-GIMG_W/-GIMG_H) and the
# Python tb / gen_reference (via the exported env var) so they stay matched.
#   make                       full 320x240 (bit-identical to before)
#   RENDER_DIV=5 make          64x48 render, ~25x faster
# NOTE: changing RENDER_DIV changes COMPILE_ARGS -> run `make clean` first.
RENDER_DIV ?= 1
RENDER_W   := $(shell expr 320 / $(RENDER_DIV))
RENDER_H   := $(shell expr 240 / $(RENDER_DIV))
export RENDER_DIV

# ─── Phase 1: traversal-only (SHADE_MODE=0) ──────────────────────────────────
VERILOG_SOURCES = $(RTL_DIR)/shared_qmul3.sv $(RTL_DIR)/svo_traversal.sv
TOPLEVEL        = svo_traversal
MODULE          = tb_svo_traversal
COMPILE_ARGS    = -GSHADE_MODE=0 -GIMG_W=$(RENDER_W) -GIMG_H=$(RENDER_H)

include $(shell cocotb-config --makefiles)/Makefile.sim

# ─── Phase 2: full shading + shadows ─────────────────────────────────────────
shade:
	$(MAKE) -f Makefile.shade
	@mkdir -p $(OUTPUT_DIR)/shaded
	@cp $(OUTPUT_DIR)/hardware_render_shaded.png $(OUTPUT_DIR)/shaded/hardware_render_shaded_$$(date +%Y%m%d_%H%M%S).png && echo "Archived dated render -> $(OUTPUT_DIR)/shaded/"

compare:
	python3 gen_reference.py
	python3 compare.py

compare-shade:
	python3 gen_reference_shaded.py
	python3 compare_shaded.py

.PHONY: compare compare-shade shade clean

clean::
	rm -rf sim_build __pycache__ results.xml shade_build
	find $(OUTPUT_DIR) -mindepth 1 -maxdepth 1 ! -name shaded -exec rm -rf {} +
