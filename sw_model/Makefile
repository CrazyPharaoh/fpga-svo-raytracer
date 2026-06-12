# sw_model/Makefile — software raytracer baseline
#
#   make scene        # export the FPGA scene (world.vox) -> scene/world.blob
#   make desktop      # scalar single-thread, -march=native       -> rt_desktop
#   make desktop-omp  # OpenMP all-core                            -> rt_desktop_omp
#   make arm          # native build for the PYNQ Cortex-A9        -> rt_arm
#   make run          # build desktop + render 320x240, 5 frames
#   make clean
#
# Precision: add PREC=float for the single-precision (fair CPU baseline) build;
# default is double (the correctness anchor vs the Python golden).

CC      ?= gcc
PREC    ?= double
SRC      = raytracer.c
LDLIBS   = -lm
WARN     = -Wall -Wextra
PPM     ?= frame.ppm
PNG     ?= frame.png

# PYNQ target (same board as host/Makefile). The software model is pure CPU —
# no bitstream/overlay needed, just the source + the prebuilt scene blob.
PYNQ     ?= xilinx@192.168.2.99
PYNQ_DIR ?= /home/xilinx/sw_model

ifeq ($(PREC),float)
PRECDEF  = -DUSE_FLOAT
endif

.PHONY: scene desktop desktop-omp arm run run-omp upload png clean

# Copy source + prebuilt scene blob to the PYNQ. Then SSH in and `make arm`.
upload: scene
	ssh $(PYNQ) 'mkdir -p $(PYNQ_DIR)/scene'
	scp raytracer.c Makefile $(PYNQ):$(PYNQ_DIR)/
	scp scene/world.blob $(PYNQ):$(PYNQ_DIR)/scene/
	@echo "Uploaded. Now: ssh $(PYNQ)  then  cd sw_model && make arm PREC=float && ./rt_arm scene/world.blob"

scene:
	python3 export_scene.py scene/world.blob

desktop: $(SRC)
	$(CC) -O3 -march=native $(WARN) $(PRECDEF) $(SRC) -o rt_desktop $(LDLIBS)

desktop-omp: $(SRC)
	$(CC) -O3 -march=native -fopenmp $(WARN) $(PRECDEF) $(SRC) -o rt_desktop_omp $(LDLIBS)

# Build this ON the PYNQ (native gcc). NEON for the A9's SIMD.
arm: $(SRC)
	$(CC) -O3 -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard $(WARN) $(PRECDEF) $(SRC) -o rt_arm $(LDLIBS)

# Thread count for the OpenMP build. Blank = all cores; override e.g. THREADS=4.
THREADS  ?=
FRAMES   ?= 50

run: scene desktop
	./rt_desktop scene/world.blob 320 240 5 $(PPM)
	$(MAKE) png

# OpenMP run with a chosen thread count: `make run-omp THREADS=4` (blank = all cores).
run-omp: scene desktop-omp
	RT_THREADS=$(THREADS) ./rt_desktop_omp scene/world.blob 320 240 $(FRAMES) $(PPM)

# Convert a rendered PPM to PNG (pure stdlib, no PIL — also works on the PYNQ).
png:
	python3 ppm2png.py $(PPM) $(PNG)

clean:
	rm -f rt_desktop rt_desktop_omp rt_arm frame.ppm frame.png scene/world.blob
