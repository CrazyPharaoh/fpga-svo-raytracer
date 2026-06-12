HDL_SRC := vivado/ip/svo_raytracer/hdl
HDL_DST := /mnt/c/Users/Ali/Documents/Imperial/FYP/sources

.PHONY: sync-hdl

# Copy RTL sources to the Windows Vivado sources folder
sync-hdl:
	cp $(HDL_SRC)/*.sv "$(HDL_DST)/"
	@echo "Copied $(HDL_SRC)/*.sv → $(HDL_DST)/"
