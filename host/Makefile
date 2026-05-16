VIVADO_PROJECT := /mnt/c/Users/Ali/Documents/Imperial/FYP/project
BIT_SRC := $(VIVADO_PROJECT)/svo_raytracer.runs/impl_1/svo_system_wrapper.bit
HWH_SRC := $(VIVADO_PROJECT)/svo_raytracer.gen/sources_1/bd/svo_system/hw_handoff/svo_system.hwh

PYNQ      := xilinx@192.168.2.99
PYNQ_DIR  := /home/xilinx/jupyter_notebooks

PY_FILES  := svo_builder.py display_frame.py main_phase1.py main.py camera.py

.PHONY: upload upload-py

# Always pull fresh bitstream + HWH from Vivado, then upload everything
upload:
	cp "$(BIT_SRC)" svo_system.bit
	cp "$(HWH_SRC)" svo_system.hwh
	scp svo_system.bit svo_system.hwh $(PY_FILES) display_frame.ipynb $(PYNQ):$(PYNQ_DIR)/

# Upload only Python/notebook files (no new bitstream needed)
upload-py:
	scp $(PY_FILES) display_frame.ipynb $(PYNQ):$(PYNQ_DIR)/
