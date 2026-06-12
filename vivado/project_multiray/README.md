# Vivado project — multi-ray SVO raytracer (PYNQ-Z1)

Everything needed to rebuild the FPGA bitstream from source. The large generated
Vivado directories (`*.runs`, `*.gen`, `*.cache`, ~300 MB) are **not** committed —
the scripts here regenerate them.

## Contents

| Path | What it is |
|------|------------|
| `sources/` | The **svo_raytracer** custom IP — the whole render core (traversal, shading, multiplier bank, AXI registers). |
| `ip/` | The **axis_upscale_2x** custom IP — the 2× line upscaler on the HDMI path. |
| `bd/svo_system/` | The **block design**: PS7 + AXI VDMA + the render IP + the HDMI-out chain (v_tc, v_axi4s_vid_out, rgb2dvi). The Xilinx IP `.xci` configs travel with it. |
| `constraints/` | HDMI-OUT pin/timing constraints (`hmdi_xdc.xdc`). |
| `create_project.tcl` | Recreates the Vivado project from the above. |
| `commands.tcl` | Build flow: synthesis → implementation → bitstream. |

## Requirements

Vivado **2025.2** (or a close version) with the **Digilent PYNQ-Z1 board files**
installed. Target device: Zynq-7020, `xc7z020clg400-1`.

## Rebuild (scripted)

In the Vivado Tcl console:

```tcl
cd <path-to-this-folder>
source create_project.tcl     ;# creates ./build/svo_raytracer.xpr
source commands.tcl           ;# synth + impl + write_bitstream
```

Outputs land in:

```
build/svo_raytracer.runs/impl_1/svo_system_wrapper.bit
build/svo_raytracer.gen/sources_1/bd/svo_system/hw_handoff/svo_system.hwh
```

Then deploy to the board — from the repo's `host/` folder run `make upload-multi`
(copies the `.bit`/`.hwh` and host scripts to the PYNQ). See Appendix B of the
report for the full run-on-hardware guide.

## Rebuild (manual, if the script hiccups)

1. **Create Project** → part `xc7z020clg400-1`, board `www.digilentinc.com:pynq-z1:part0:1.0`.
2. **Settings → IP → Repository** → add this folder's `sources/` and `ip/`.
3. **Add Sources → Add existing block design** → `bd/svo_system/svo_system.bd`.
4. Right-click the BD in Sources → **Create HDL Wrapper** (let Vivado manage), set as top.
5. **Add Sources → Add constraints** → `constraints/hmdi_xdc.xdc`.
6. In the Tcl console: `source commands.tcl`.
