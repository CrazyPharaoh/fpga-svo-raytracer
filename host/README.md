# `host/` — PYNQ host software

Python that runs on the PYNQ-Z1's ARM processor. It builds and uploads the octree,
sets the camera and rendering registers over AXI-Lite, triggers renders, reads frames
back, and drives the interactive demonstrator. The board is reached over the network
at `192.168.2.99` by default.

## Deploying to the board

Run from a PC on the same network as the board:

| Command | Copies |
|---------|--------|
| `make upload-multi` | bitstream + hand-off file + all host Python + `world.vox` (the multi-ray HDMI build) |
| `make upload-py` | host Python only, no new bitstream |
| `make upload` | the base (non-HDMI) build |

## Running

### Interactive fly-through (the demonstration) — `fly.py`

The renderer needs root to load the bitstream, so run it from a terminal inside the
board's Jupyter interface (open `http://192.168.2.99:9090`, then **New → Terminal**),
not a plain SSH session:

```bash
cd jupyter_notebooks
sudo python3 fly.py
```

Controls:

- `W/A/S/D` move, arrow keys look, `Space`/`C` up/down, `-`/`=` zoom
- `I/J/K/L` move the sun, `O` toggle automatic sun orbit
- `T` toggle shadows, `[` / `]` lower / raise the traversal depth (level of detail)
- `F` capture the current frame and print its camera, `Q` quit

The frame rate is printed live as you move.

### Single render in Jupyter — `display_frame.ipynb`

Open the notebook in the board's Jupyter server and run the cells top to bottom: it
loads the bitstream, arms the VDMA, uploads the octree, sets the camera, renders one
frame, and shows it inline. No monitor required.

## Key files

| File | Role |
|------|------|
| `svo_builder.py` | builds the SVO from a voxel grid (`build_svo` / `flatten` / `serialise`) |
| `vox_loader.py` | loads a MagicaVoxel `.vox` world and extracts the 16-entry colour/material lookup table |
| `camera.py`, `fly_camera.py` | camera maths (Q16.16 conversion, basis vectors) |
| `fly.py` | the interactive fly-through demonstrator |
| `display_frame.ipynb`, `display_frame.py` | single-render entry point |
| `fpga_diag.py`, `hdmi_display.py` | bring-up and HDMI-output diagnostics |
| `main.py`, `main_phase1.py` | older entry points, kept for reference |
| `test_vox_loader.py`, `test_fly_camera.py` | host-side unit tests (`pytest`) |

The full AXI register map is defined in the `axi_lite_slave.sv` register file under
`vivado/ip/svo_raytracer/hdl/`.

## `evdev_offline/`

Offline-install wheels (`evdev` plus its build dependencies) for the optional
`--evdev` USB-keyboard input backend, since the board has no internet access:

```bash
pip install --no-index --find-links evdev_offline evdev
```

The default keyboard backend reads the controlling terminal and needs none of this.
