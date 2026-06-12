#!/usr/bin/env python3
# sw_model/export_scene.py
# Export the scene (SVO nodes + 16-entry LUT + camera + shading constants) to a
# flat little-endian binary blob for raytracer.c. Scene parameters come from
# gen_reference_shaded.py, which mirrors shading_pipeline.sv.
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

# Camera — must match gen_reference_shaded.py (and tb_svo_full.py) for the C output
# to be comparable to reference_render_shaded.png. fov_scale is not exported; the C
# model computes it from its own resolution (tan(fov/2)/(W/2)).
CAM_POS   = (72.5269, 29.4615, 72.5337)
CAM_FWD   = (-0.684,  -0.2537, -0.684)
CAM_RIGHT = ( 0.7071,  0.0,    -0.7071)
CAM_UP    = (-0.1794,  0.9673, -0.1794)

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

    out += struct.pack('<3f', *g.LIGHT_DIR)        # pre-normalised
    out += struct.pack('<f',  g.AMBIENT)
    out += struct.pack('<f',  g.FOG_INV_RANGE)
    out += struct.pack('<f',  g.FOG_START)
    out += struct.pack('<f',  g.SHADOW_BIAS)

    out += struct.pack('<4B', *g.SKY_COLOR, 0)
    out += struct.pack('<4B', *g.FOG_COLOR, 0)
    out += struct.pack('<I',  1 if g.SHADOWS_ENABLED else 0)
    out += struct.pack('<i',  g.TIME_PHASE)

    # LUT: 16 words, [31:24]=material flag, [23:0]=RGB
    assert len(g._LUT_WORDS) == 16
    for w in g._LUT_WORDS:
        out += struct.pack('<I', w & 0xFFFFFFFF)

    # Nodes: bitmask(u16) + children[8](u16) + block_id[8](u8) = 26 bytes each
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
