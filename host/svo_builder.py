# host/svo_builder.py
# CPU-side SVO build and serialise functions.
# Extracted from hardware_ref/fpga_svo_raytracer.py so the PYNQ host can
# reuse them without importing the full reference model.

import math
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional

WORLD_SIZE  = 64
MAX_DEPTH   = 6

# Set to 1 to generate a simple test world (single block at world centre)
# instead of the full terrain. All callers use build_world() unchanged.
TESTING = 0

STATE_EMPTY = 0b00
STATE_SOLID = 0b11
STATE_MIXED = 0b01

BLOCK_AIR     = 0
BLOCK_STONE   = 1
BLOCK_GRASS   = 2
BLOCK_GLOWING = 3
BLOCK_SAND    = 4   # low terrain (beaches)
BLOCK_SNOW    = 5   # high peaks
# NOTE: block_id 0..5 only — shading LUT is 6 entries and the LUT index is clamped to 5
# in shading_pipeline.sv (and gen_reference_shaded.py). Adding a 7th colour needs the LUT
# array + register map extended (see CLAUDE.md / the LUT plumbing in axi_lite_slave.sv).


@dataclass
class SVONode:
    bitmask:  int       = 0
    children: List      = field(default_factory=lambda: [None] * 8)
    block_id: List[int] = field(default_factory=lambda: [0] * 8)


def _build_test_world() -> np.ndarray:
    """Return a 64^3 grid with a single 8x8x8 stone block at the world centre."""
    grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    c = WORLD_SIZE // 2
    grid[c - 4:c + 4, c - 4:c + 4, c - 4:c + 4] = BLOCK_STONE
    return grid


def build_world() -> np.ndarray:
    """Return a 64^3 uint8 voxel grid. Returns test world when TESTING=1."""
    if TESTING:
        return _build_test_world()
    grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    for x in range(WORLD_SIZE):
        for z in range(WORLD_SIZE):
            h = max(1, min(6, 1 + int(2 * (math.sin(0.4 * x) + math.cos(0.35 * z) + 2))))
            for y in range(h):
                grid[x, y, z] = BLOCK_STONE
            # Height-based surface colour: sand low, grass mid, snow on peaks.
            top = BLOCK_SNOW if h >= 5 else (BLOCK_SAND if h <= 2 else BLOCK_GRASS)
            grid[x, h - 1, z] = top
    # Glowing cluster at world centre
    cx, cz = WORLD_SIZE // 2, WORLD_SIZE // 2
    peak = max(1, min(6, 1 + int(2 * (math.sin(0.4 * cx) + math.cos(0.35 * cz) + 2))))
    for dx in range(4):
        for dy in range(5):
            for dz in range(4):
                grid[cx + dx, peak + 3 + dy, cz + dz] = BLOCK_GLOWING
    return grid


def build_svo(grid: np.ndarray, ox=0, oy=0, oz=0, size=None) -> SVONode:
    """Recursively build an SVO from the voxel grid. Returns the root SVONode."""
    if size is None:
        size = WORLD_SIZE
    node = SVONode()
    half = size // 2
    for cidx in range(8):
        cx = ox + (half if cidx & 1 else 0)
        cy = oy + (half if cidx & 2 else 0)
        cz = oz + (half if cidx & 4 else 0)
        sub = grid[cx:cx + half, cy:cy + half, cz:cz + half]
        if sub.max() == BLOCK_AIR:
            bits = STATE_EMPTY
        elif half == 1:
            bits = STATE_SOLID
            node.block_id[cidx] = int(sub[0, 0, 0])
        else:
            child = build_svo(grid, cx, cy, cz, half)
            # Collapse uniform-solid subtrees into a single SOLID leaf
            all_same_solid = all(
                ((child.bitmask >> (i * 2)) & 3) == STATE_SOLID
                and child.block_id[i] == child.block_id[0]
                for i in range(8)
            )
            if all_same_solid:
                bits = STATE_SOLID
                node.block_id[cidx] = child.block_id[0]
            else:
                bits = STATE_MIXED
                node.children[cidx] = child
        node.bitmask |= (bits << (cidx * 2))
    return node


def flatten_svo(root: SVONode) -> List[SVONode]:
    """
    BFS traversal of the SVO tree.
    Returns a flat list of SVONodes where each node's children[i] is either
    None (leaf) or an integer index into the returned list.
    """
    obj_to_idx = {}
    queue = [root]
    ordered = []

    while queue:
        node = queue.pop(0)
        obj_to_idx[id(node)] = len(ordered)
        ordered.append(node)
        for i in range(8):
            if isinstance(node.children[i], SVONode):
                queue.append(node.children[i])

    # Replace child SVONode references with integer indices
    for node in ordered:
        for i in range(8):
            if isinstance(node.children[i], SVONode):
                node.children[i] = obj_to_idx[id(node.children[i])]
            elif node.children[i] is None:
                node.children[i] = 0   # null pointer

    return ordered


def serialise_nodes(nodes: List[SVONode]) -> List[int]:
    """
    Serialise a flat node list into a sequence of 32-bit words for streaming
    into the FPGA BRAM via SVO_DATA register.

    Each node occupies exactly 8 words:
      word 0    bitmask [15:0]
      words 1-4 child_ptr pairs: word k holds child_ptr[2k-2] in [15:0]
                                           and child_ptr[2k-1] in [31:16]
      words 5-6 block_id quads:  word 5 holds block_id[0..3] packed 8-bit each
                                  word 6 holds block_id[4..7]
      word 7    padding (zero)
    """
    words = []
    for n in nodes:
        words.append(n.bitmask & 0xFFFF)
        for i in range(0, 8, 2):
            words.append(
                ((n.children[i + 1] & 0xFFFF) << 16) | (n.children[i] & 0xFFFF)
            )
        for i in range(0, 8, 4):
            w = 0
            for j in range(4):
                w |= (n.block_id[i + j] & 0xFF) << (j * 8)
            words.append(w)
        words.append(0)   # padding word 7
    return words
