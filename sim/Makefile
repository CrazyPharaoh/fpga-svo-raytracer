# sim/Makefile — cocotb + Verilator: Phase 1 (traversal only) and Phase 2 (shading + shadows)

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
# RENDER_DIV downscales the render (same FOV), ~DIV² faster.
# Drives both RTL (-GIMG_W/-GIMG_H) and the Python tb via the exported env var.
#   make              full 320×240
#   RENDER_DIV=5 make 64×48, ~25× faster
# Changing RENDER_DIV changes COMPILE_ARGS — run `make clean` first.
RENDER_DIV ?= 1
RENDER_W   := $(shell expr 320 / $(RENDER_DIV))
RENDER_H   := $(shell expr 240 / $(RENDER_DIV))
export RENDER_DIV

# Multi-ray pool size. Overridable: `RAY_POOL_N=6 make`.
# Changing RAY_POOL_N changes COMPILE_ARGS — run `make clean` first.
RAY_POOL_N ?= 4

# ─── Phase 1: traversal-only (SHADE_MODE=0) ──────────────────────────────────
# RAY_POOL_N=1 is bit-identical to the single-ray baseline.
VERILOG_SOURCES = $(RTL_DIR)/shared_qmul3.sv $(RTL_DIR)/pixel_reorder.sv $(RTL_DIR)/ray_scheduler.sv $(RTL_DIR)/svo_traversal_mr.sv
TOPLEVEL        = svo_traversal_mr
MODULE          = tb_svo_traversal
COMPILE_ARGS    = -GSHADE_MODE=0 -GRAY_POOL_N=$(RAY_POOL_N) -GIMG_W=$(RENDER_W) -GIMG_H=$(RENDER_H)

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

# Run the single-ray baseline in a worktree for FSM cycle comparison.
# See profile_baseline.sh for details.
RENDER_DIV   ?= 5
BASELINE_REF ?= d5095bc
shade-baseline:
	RENDER_DIV=$(RENDER_DIV) BASELINE_REF=$(BASELINE_REF) bash profile_baseline.sh

.PHONY: compare compare-shade shade shade-baseline clean

clean::
	rm -rf sim_build __pycache__ results.xml shade_build
	find $(OUTPUT_DIR) -mindepth 1 -maxdepth 1 ! -name shaded ! -name profiles ! -name golden -exec rm -rf {} +
