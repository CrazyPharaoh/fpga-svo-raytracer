VIVADO_PROJECT := /mnt/c/Users/Ali/Documents/Imperial/FYP/project
BIT_SRC := $(VIVADO_PROJECT)/svo_raytracer.runs/impl_1/svo_system_wrapper.bit
HWH_SRC := $(VIVADO_PROJECT)/svo_raytracer.gen/sources_1/bd/svo_system/hw_handoff/svo_system.hwh

# HDMI build (project_hdmi copy); same internal layout as the base project.
VIVADO_PROJECT_HDMI := /mnt/c/Users/Ali/Documents/Imperial/FYP/project_hdmi
BIT_SRC_HDMI := $(VIVADO_PROJECT_HDMI)/svo_raytracer.runs/impl_1/svo_system_wrapper.bit
HWH_SRC_HDMI := $(VIVADO_PROJECT_HDMI)/svo_raytracer.gen/sources_1/bd/svo_system/hw_handoff/svo_system.hwh

# Multi-ray build (project_multiray copy); same internal layout.
VIVADO_PROJECT_MULTI := /mnt/c/Users/Ali/Documents/Imperial/FYP/project_multiray
BIT_SRC_MULTI := $(VIVADO_PROJECT_MULTI)/svo_raytracer.runs/impl_1/svo_system_wrapper.bit
HWH_SRC_MULTI := $(VIVADO_PROJECT_MULTI)/svo_raytracer.gen/sources_1/bd/svo_system/hw_handoff/svo_system.hwh

PYNQ      := xilinx@192.168.2.99
PYNQ_DIR  := /home/xilinx/jupyter_notebooks

PY_FILES  := svo_builder.py display_frame.py main_phase1.py main.py camera.py hdmi_display.py fly.py fly_camera.py fpga_diag.py vox_loader.py

.PHONY: upload upload-hdmi upload-multi upload-py

# Pull fresh bitstream + HWH from Vivado, then SCP everything to the PYNQ
upload:
	cp "$(BIT_SRC)" svo_system.bit
	cp "$(HWH_SRC)" svo_system.hwh
	scp svo_system.bit svo_system.hwh $(PY_FILES) display_frame.ipynb *.vox scene.json $(PYNQ):$(PYNQ_DIR)/

# Like upload, but from the HDMI project
upload-hdmi:
	cp "$(BIT_SRC_HDMI)" svo_system.bit
	cp "$(HWH_SRC_HDMI)" svo_system.hwh
	scp svo_system.bit svo_system.hwh $(PY_FILES) display_frame.ipynb $(PYNQ):$(PYNQ_DIR)/

# Like upload, but from the multi-ray project
upload-multi:
	cp "$(BIT_SRC_MULTI)" svo_system.bit
	cp "$(HWH_SRC_MULTI)" svo_system.hwh
	scp svo_system.bit svo_system.hwh $(PY_FILES) display_frame.ipynb *.vox scene.json $(PYNQ):$(PYNQ_DIR)/

# Upload Python/notebook files only (no bitstream)
upload-py:
	scp $(PY_FILES) display_frame.ipynb *.vox scene.json $(PYNQ):$(PYNQ_DIR)/
