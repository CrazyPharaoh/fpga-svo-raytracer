#!/usr/bin/env python3
# sw_model/export_scene.py
#
# Dump the EXACT scene the FPGA renders (SVO nodes + 16-entry LUT + camera +
# shading constants) into a flat little-endian binary blob the C software model
# reads. Single source of truth = sim/gen_reference_shaded.py, which itself
# mirrors shading_pipeline.sv — so the C model renders the same workload.
#
# Usage:  python3 export_scene.py [out.blob]   (default: scene/world.blob)

import os
import sys
import struct

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
for _p in ('sim', 'host', 'hardware_ref'):
    sys.path.insert(0, os.path.join(_ROOT, _p))

import svo_builder                      # noqa: E402
import gen_reference_shaded as g        # noqa: E402  (loads world.vox + LUT at import)

# ── Camera — MUST match gen_reference_shaded.py main() (and tb_svo_full.py) so the
#    C output is comparable to reference_render_shaded.png. fov_scale is NOT exported:
#    it depends on render width, so the C model computes it from its own resolution
#    exactly as the reference does (tan(fov/2)/(W/2)).
CAM_POS   = (48.0095, 16.7627, 27.9686)
CAM_FWD   = (-0.9094, -0.337,  0.2437)
CAM_RIGHT = (-0.2588,  0.0,   -0.9659)
CAM_UP    = (-0.3255,  0.9415, 0.0872)

MAGIC   = b'SVOC'
VERSION = 1


def build_blob() -> bytes:
    grid  = g._GRID
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))

    out = bytearray()
    out += MAGIC
    out += struct.pack('<I', VERSION)
    out += struct.pack('<I', len(nodes))

    out += struct.pack('<3f', *CAM_POS)
    out += struct.pack('<3f', *CAM_FWD)
    out += struct.pack('<3f', *CAM_RIGHT)
    out += struct.pack('<3f', *CAM_UP)

    out += struct.pack('<3f', *g.LIGHT_DIR)        # already normalised
    out += struct.pack('<f',  g.AMBIENT)
    out += struct.pack('<f',  g.FOG_INV_RANGE)
    out += struct.pack('<f',  g.FOG_START)
    out += struct.pack('<f',  g.SHADOW_BIAS)

    out += struct.pack('<4B', *g.SKY_COLOR, 0)
    out += struct.pack('<4B', *g.FOG_COLOR, 0)
    out += struct.pack('<I',  1 if g.SHADOWS_ENABLED else 0)
    out += struct.pack('<i',  g.TIME_PHASE)

    # 16 LUT words: [31:24]=material flag, [23:0]=RGB
    assert len(g._LUT_WORDS) == 16
    for w in g._LUT_WORDS:
        out += struct.pack('<I', w & 0xFFFFFFFF)

    # nodes: bitmask(u16) + children[8](u16) + block_id[8](u8) = 26 bytes each
    for n in nodes:
        out += struct.pack('<H', n.bitmask & 0xFFFF)
        out += struct.pack('<8H', *[c & 0xFFFF for c in n.children])
        out += struct.pack('<8B', *[b & 0xFF for b in n.block_id])

    return bytes(out), nodes


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_HERE, 'scene', 'world.blob')
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    blob, nodes = build_blob()
    with open(out_path, 'wb') as f:
        f.write(blob)
    print(f"Wrote {out_path}: {len(nodes)} nodes, {len(blob)} bytes")
    print(f"  shadows={'on' if g.SHADOWS_ENABLED else 'off'}  "
          f"fog_start={g.FOG_START}  ambient={g.AMBIENT:.5f}  "
          f"light_dir={tuple(round(c,4) for c in g.LIGHT_DIR)}")


if __name__ == '__main__':
    main()
