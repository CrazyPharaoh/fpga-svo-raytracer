# vox_loader.py
# Parse a MagicaVoxel .vox file into the engine's block_id grid + colour LUT,
# then feed the existing svo_builder pipeline unchanged.
#
# Pure Python: only struct, dataclasses, numpy. No external deps.
#
# LUT word format: [31:24] = material flag, [23:0] = packed RGB (R<<16|G<<8|B).
# Material flags: 0=static, 1=water, 2=lava, 3=glow.
# block_id 0 is reserved for air (never a solid hit); used colours -> block_ids 1..15.

import struct
from dataclasses import dataclass
from typing import List, Tuple

import numpy as np

WORLD_SIZE = 64
MAX_COLOURS = 15    # block_ids 1..15; block_id 0 = air
MAX_NODES = 4096    # SVO must fit in BRAM (32768 words / 8 words-per-node)

MAT_STATIC, MAT_WATER, MAT_LAVA, MAT_GLOW = 0, 1, 2, 3


class TooManyColoursError(Exception):
    pass


class NodeBudgetError(Exception):
    pass


# Designate animation materials by exact RGB. Edit to match the colours you paint with.
# (255,255,102) pale-yellow is SAND -> static, NOT glow. To make a block glow, add its
# RGB here with MAT_GLOW.
DEFAULT_MATERIAL_RULES = {
    (0, 255, 255): MAT_WATER,   # cyan
    (0, 102, 255): MAT_WATER,   # blue
    (255, 102, 0): MAT_LAVA,    # orange
}


def rules_from_materials(materials: dict) -> dict:
    """Build a {(r,g,b): flag} rules dict from a scene-config "materials" section:
    {"water": [[r,g,b], ...], "lava": [...], "glow": [...]}. Unknown material
    names raise (loud beats silent)."""
    name_to_flag = {"water": MAT_WATER, "lava": MAT_LAVA, "glow": MAT_GLOW}
    rules = {}
    for name, colours in (materials or {}).items():
        flag = name_to_flag[name]
        for rgb in colours:
            rules[tuple(rgb)] = flag
    return rules


@dataclass
class Vox:
    size: Tuple[int, int, int]
    voxels: List[Tuple[int, int, int, int]]   # (x, y, z, colorIndex 1..255)
    palette: List[Tuple[int, int, int, int]]  # 256 RGBA; palette[i] == colorIndex (i+1)

    def rgb(self, color_index: int) -> Tuple[int, int, int]:
        r, g, b, _a = self.palette[color_index - 1]
        return (r, g, b)


def _iter_chunks(buf, start, end):
    """Yield (chunk_id, content_bytes) over the chunk region [start, end)."""
    i = start
    while i < end:
        cid = buf[i:i + 4]
        content_len, child_len = struct.unpack_from("<II", buf, i + 4)
        content_start = i + 12
        content = buf[content_start:content_start + content_len]
        yield cid, content
        i = content_start + content_len + child_len


def parse_vox(path: str) -> Vox:
    """Parse a MagicaVoxel .vox container into a Vox (size, voxels, palette)."""
    with open(path, "rb") as f:
        buf = f.read()
    if buf[:4] != b"VOX ":
        raise ValueError(f"{path}: not a MagicaVoxel .vox file (bad magic)")
    # MAIN chunk: its children hold SIZE/XYZI/RGBA. MAIN content_len is 0.
    main_id, _main_content = next(_iter_chunks(buf, 8, len(buf)))
    assert main_id == b"MAIN", f"expected MAIN, got {main_id!r}"
    _main_content_len, main_child_len = struct.unpack_from("<II", buf, 12)
    child_start = 20

    size = None
    voxels = []
    palette = None
    saw_rgba = False
    for cid, content in _iter_chunks(buf, child_start, child_start + main_child_len):
        if cid == b"SIZE":
            size = struct.unpack_from("<III", content, 0)
        elif cid == b"XYZI":
            (n,) = struct.unpack_from("<I", content, 0)
            for k in range(n):
                x, y, z, c = content[4 + k * 4: 8 + k * 4]
                voxels.append((x, y, z, c))
        elif cid == b"RGBA":
            palette = [tuple(content[j * 4: j * 4 + 4]) for j in range(256)]
            saw_rgba = True

    if size is None:
        raise ValueError(f"{path}: no SIZE chunk")
    if not saw_rgba:
        raise ValueError(f"{path}: no RGBA palette chunk - re-export with palette")
    return Vox(size=size, voxels=voxels, palette=palette)


def build_colour_remap(vox: Vox) -> dict:
    """Map each used .vox colourIndex -> a contiguous block_id (1..N), ascending."""
    used = sorted({c for (_x, _y, _z, c) in vox.voxels})
    if len(used) > MAX_COLOURS:
        raise TooManyColoursError(
            f"{len(used)} distinct colours used, max {MAX_COLOURS}. "
            f"Merge these in MagicaVoxel: {[vox.rgb(c) for c in used]}"
        )
    return {c: bid for bid, c in enumerate(used, start=1)}


def build_material_flags(vox: Vox, remap: dict, rules=None) -> dict:
    """Return {block_id: material_flag} from palette RGB rules (default: static)."""
    rules = DEFAULT_MATERIAL_RULES if rules is None else rules
    return {bid: rules.get(vox.rgb(ci), MAT_STATIC) for ci, bid in remap.items()}


def pack_lut_word(rgb, flag) -> int:
    """Pack RGB + material flag into a 32-bit LUT word: [31:24]=flag, [23:0]=RGB."""
    r, g, b = rgb
    return ((flag & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF)


def embed_grid(vox: "Vox", remap: dict) -> np.ndarray:
    """Place a .vox model (any size up to 64^3) into the fixed 64^3 engine grid.

    The hardware always traverses 64^3; a smaller model just occupies a sub-region
    (empty octants collapse to air and rays pass through). Placement: floor-aligned
    in Y (sits on the ground) and centred in X/Z so the default camera frames it.
    MagicaVoxel is Z-up, the engine is Y-up: (vx,vy,vz) -> grid[x=vx, y=vz, z=vy],
    so MagicaVoxel size = (X, Y, Z) maps to engine extents (X, Z=height, Y).
    """
    sx, sy, sz = vox.size
    if max(sx, sy, sz) > WORLD_SIZE:
        raise ValueError(
            f"world {vox.size} exceeds {WORLD_SIZE}^3 — downscale in MagicaVoxel "
            f"or rebuild with a larger WORLD_SIZE")
    ox = (WORLD_SIZE - sx) // 2     # centre engine-X
    oz = (WORLD_SIZE - sy) // 2     # centre engine-Z (= MagicaVoxel Y)
    grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    for (vx, vy, vz, ci) in vox.voxels:
        grid[vx + ox, vz, vy + oz] = remap[ci]   # Y floor-aligned (offset 0)
    return grid


def load_world(path: str, rules=None):
    """Parse a .vox into (grid[64,64,64] uint8 block_ids, lut_words[16]).

    Worlds up to 64^3 are embedded (floor-aligned, X/Z-centred); see embed_grid.
    Raises NodeBudgetError if the built SVO exceeds MAX_NODES.
    """
    vox = parse_vox(path)
    remap = build_colour_remap(vox)
    flags = build_material_flags(vox, remap, rules)
    grid = embed_grid(vox, remap)

    lut_words = [0] * 16
    for ci, bid in remap.items():
        lut_words[bid] = pack_lut_word(vox.rgb(ci), flags[bid])

    # validate node budget against the real builder
    import svo_builder
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
    if len(nodes) > MAX_NODES:
        raise NodeBudgetError(
            f"SVO has {len(nodes)} nodes, max {MAX_NODES} - simplify the scene"
        )
    return grid, lut_words
