# host/svo_builder.py — CPU-side SVO build and serialise functions.

import math
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional

WORLD_SIZE  = 64
MAX_DEPTH   = 6

TESTING = 0   # set to 1 for a single test block at world centre

STATE_EMPTY = 0b00
STATE_SOLID = 0b11
STATE_MIXED = 0b01

BLOCK_AIR     = 0
BLOCK_STONE   = 1
BLOCK_GRASS   = 2
BLOCK_GLOWING = 3
BLOCK_SAND    = 4
BLOCK_SNOW    = 5


@dataclass
class SVONode:
    bitmask:  int       = 0
    children: List      = field(default_factory=lambda: [None] * 8)
    block_id: List[int] = field(default_factory=lambda: [0] * 8)
    dom_block: int      = 0   # representative block for depth-cap shading (serialised in word 7)


def _build_test_world() -> np.ndarray:
    """Return a 64^3 grid with a single 8x8x8 stone block at the world centre."""
    grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    c = WORLD_SIZE // 2
    grid[c - 4:c + 4, c - 4:c + 4, c - 4:c + 4] = BLOCK_STONE
    return grid


def build_world() -> np.ndarray:
    """Return a 64^3 uint8 voxel grid. When TESTING=1, returns a single test block."""
    if TESTING:
        return _build_test_world()
    grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    for x in range(WORLD_SIZE):
        for z in range(WORLD_SIZE):
            h = max(1, min(6, 1 + int(2 * (math.sin(0.4 * x) + math.cos(0.35 * z) + 2))))
            for y in range(h):
                grid[x, y, z] = BLOCK_STONE
            top = BLOCK_SNOW if h >= 5 else (BLOCK_SAND if h <= 2 else BLOCK_GRASS)
            grid[x, h - 1, z] = top
    # Glowing cluster above world centre
    cx, cz = WORLD_SIZE // 2, WORLD_SIZE // 2
    peak = max(1, min(6, 1 + int(2 * (math.sin(0.4 * cx) + math.cos(0.35 * cz) + 2))))
    for dx in range(4):
        for dy in range(5):
            for dz in range(4):
                grid[cx + dx, peak + 3 + dy, cz + dz] = BLOCK_GLOWING
    return grid


def build_svo(grid: np.ndarray, ox=0, oy=0, oz=0, size=None) -> SVONode:
    """Recursively build an SVO from the voxel grid; returns the root SVONode."""
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
    # dom_block: first non-air block in this node's children, for depth-cap shading.
    for cidx in range(8):
        st = (node.bitmask >> (cidx * 2)) & 3
        if st == STATE_SOLID and node.block_id[cidx] != BLOCK_AIR:
            node.dom_block = node.block_id[cidx]; break
        if st == STATE_MIXED and node.children[cidx].dom_block != BLOCK_AIR:
            node.dom_block = node.children[cidx].dom_block; break
    return node


def flatten_svo(root: SVONode) -> List[SVONode]:
    """BFS the SVO tree; returns a flat list where children[i] is an integer index or 0."""
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

    for node in ordered:
        for i in range(8):
            if isinstance(node.children[i], SVONode):
                node.children[i] = obj_to_idx[id(node.children[i])]
            elif node.children[i] is None:
                node.children[i] = 0   # null pointer

    return ordered


def serialise_nodes(nodes: List[SVONode]) -> List[int]:
    """Serialise a flat node list to 32-bit words for BRAM upload via SVO_DATA (0x4C).

    8 words per node:
      word 0:   bitmask [15:0]
      words 1–4: child_ptr pairs (two 16-bit indices per word)
      words 5–6: block_id quads (four 8-bit IDs per word)
      word 7:   dom_block (depth-cap representative block, 8-bit)
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
        words.append(n.dom_block & 0xFF)
    return words
