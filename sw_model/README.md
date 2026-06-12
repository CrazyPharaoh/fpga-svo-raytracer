# `sw_model/` — software ray tracer (CPU baseline)

An optimised-C renderer of the same scene and algorithm as the hardware, used as the
performance baseline. It is a **floating-point algorithmic port**, not a bit-accurate
or cycle-accurate model of the fixed-point hardware; it produces the same image and
is run on two processors to bracket the comparison: the board's own ARM Cortex-A9
(the fair same-chip baseline) and a desktop CPU (the performance-per-watt reference).

## Build and run

First export the scene the hardware uses:

```bash
make scene                     # writes scene/world.blob from the FPGA world
```

On the desktop:

```bash
make run                       # single-thread, renders 320x240
make run-omp THREADS=16        # OpenMP across N cores (blank = all)
```

On the board's ARM Cortex-A9:

```bash
make upload                    # copy the source + scene blob to the board
# then, in an SSH session on the board:
cd sw_model
make arm PREC=float
./rt_arm scene/world.blob 320 240 50
```

Both builds print frames-per-second and rays-per-second.

`PREC=float` selects the single-precision build used as the fair CPU baseline; the
default is `double` (the correctness anchor against the Python golden reference).

## Files

| File | Role |
|------|------|
| `raytracer.c` | the C renderer: octree traversal + shading, OpenMP-parallel |
| `export_scene.py` | exports the FPGA scene (`world.vox`) to a binary blob the C model reads |
| `ppm2png.py` | converts a rendered PPM to PNG (standard library only, also runs on the board) |
| `Makefile` | the build and run targets above |
