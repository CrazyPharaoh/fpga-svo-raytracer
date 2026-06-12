# `sim/` — simulation and verification

Verifies the RTL against a Python golden reference using **cocotb** (with Verilator
or Icarus). The same scene and camera drive both the Python reference renderer and an
RTL simulation; a per-pixel difference is the headline correctness metric and the
difference image is the diagnostic.

## Frame-level render and compare

| Command | What it does |
|---------|--------------|
| `make` | phase 1: geometry-only render (white hits, sky misses) in simulation |
| `make shade` | phase 2: the full shaded and shadowed render |
| `make compare` | diff the phase-1 render against the Python reference |
| `make compare-shade` | diff the shaded render against the reference |
| `make clean` | remove the simulation build |

Useful variables:

- `RENDER_DIV=5 make` renders at 1/5 resolution at the same field of view, roughly
  25× faster, for quick iteration. Changing it changes the compile arguments, so run
  `make clean` first.
- `WORLD=procedural make` uses the built-in procedural world instead of `world.vox`.

## Per-module unit tests (cocotb)

Each RTL block has its own testbench under `cocotb/test_*/`. Run one with, e.g.:

```bash
cd cocotb/test_svo_traversal && make
```

The suite covers the traversal core, the shared multiplier bank, the scheduler, the
stack store, the pixel reorder buffer, the wide and shadow node memories, the
AXI-Lite register file, and the 2× upscaler. These localise a regression to a single
module rather than leaving it to be diagnosed at the system level.

## Key files

| File | Role |
|------|------|
| `svo_full_tb.sv` | full-system testbench wrapper (top module + a VDMA stream model) |
| `tb_svo_full.py`, `tb_svo_traversal.py` | cocotb drivers for the full system and the traversal core |
| `gen_reference.py`, `gen_reference_shaded.py` | the Python golden-reference renderers |
| `compare.py`, `compare_shaded.py` | per-pixel image-difference tools |
| `sim_profiling.py` | FSM cycle profiler (reports where the cycles go) |
| `test_nr_accuracy.py` | bit-accurate Newton-Raphson reciprocal / inverse-sqrt accuracy sweep |
| `output/` | golden reference images, cycle profiles, and rendered outputs |
