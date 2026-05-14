# sim/Makefile
# cocotb + Verilator testbench for svo_traversal.sv

SIM           ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(shell pwd)/../vivado/ip/svo_raytracer/hdl/svo_traversal.sv

TOPLEVEL = svo_traversal
MODULE   = tb_svo_traversal

EXTRA_ARGS  = --language 1800-2012
EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE
EXTRA_ARGS += -Wno-UNOPTFLAT

OUTPUT_DIR = output
$(shell mkdir -p $(OUTPUT_DIR))

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: compare clean

compare: sim
	python3 gen_reference.py
	python3 compare.py

clean::
	rm -rf sim_build __pycache__ results.xml $(OUTPUT_DIR)
