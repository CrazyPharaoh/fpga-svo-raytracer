"""
fpga_svo_raytracer.py — FPGA-Targeted Sparse Voxel Octree Raytracer
Python golden reference model for hardware translation to Verilog/VHDL.

All traversal logic mirrors a fixed-register-file hardware design:
 - No dynamic allocation inside the traversal loop
 - No division inside the traversal loop (reciprocals pre-computed)
 - No recursion inside traversal (fixed LIFO stack of depth STACK_DEPTH)
 - No sorting of children (DDA natural front-to-back ordering)
"""

# ---------------------------------------------------------------------------
# Imports (ALL at top — prohibited inside functions per hardware spec)
# ---------------------------------------------------------------------------
import math
import os
import glob
import sys
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional

# ---------------------------------------------------------------------------
# Global Constants — Hardware Parameters
# ---------------------------------------------------------------------------
WORLD_SIZE    = 64          # CPU: Voxels per axis (must be power of 2)
MAX_DEPTH     = 6           # CPU: SVO depth = log2(64) = 6 levels
STACK_DEPTH   = 12          # HW: Fixed LIFO stack depth (register file size) — doubled for safety
IMG_W         = 320         # HW: Render resolution width
IMG_H         = 240         # HW: Render resolution height
NUM_FRAMES    = 30          # CPU: Animation frames
FOV_DEG       = 60.0        # CPU: Field of view in degrees
MAX_T         = 200.0       # HW: Far-plane clipping distance
FOG_START     = 15.0        # HW: Distance at which fog begins
SHADOW_BIAS   = 0.01        # HW: Offset origin along normal to avoid self-intersection

# HW: 3-state bitmask codes (2 bits per child slot — single shift+AND per lookup)
STATE_EMPTY   = 0b00        # Air — ray passes through, no shading
STATE_SOLID   = 0b11        # Solid — terminates ray, shade this hit
STATE_MIXED   = 0b01        # Internal — descend into child node

# CPU: Voxel block IDs
BLOCK_AIR     = 0
BLOCK_STONE   = 1
BLOCK_GRASS   = 2
BLOCK_GLOWING = 3           # Dynamic LUT block — pulsing emissive

# HW: Constant color registers (written by CPU before pipeline starts)
SKY_COLOR     = (135, 206, 235)
GROUND_COLOR  = (80,  60,  40)
FOG_COLOR     = (180, 200, 220)

# HW: Camera orbit parameters
ORBIT_RADIUS  = 30
ORBIT_HEIGHT  = 20

# HW: Infinity sentinel for "already-crossed" DDA boundary
INF = float('inf')

# ---------------------------------------------------------------------------
# Data Structures
# ---------------------------------------------------------------------------

@dataclass
class SVONode:
    """
    Hardware analog: A BRAM row containing one octree node.
    bitmask: 16-bit integer; 2 bits x 8 children = bits [15:0]
      child i occupies bits [2i+1 : 2i]
    children: list of child node indices (None = leaf)
    block_id: per-child block type for SOLID leaves
    """
    bitmask:  int       = 0
    children: List      = field(default_factory=lambda: [None] * 8)
    block_id: List[int] = field(default_factory=lambda: [0] * 8)


@dataclass
class Metrics:
    """Observation layer — not hardware. Incremented inside traversal."""
    primary_rays:    int = 0
    shadow_rays:     int = 0
    nodes_visited:   int = 0
    bitmask_checks:  int = 0


# Global metrics accumulator
metrics = Metrics()

# ---------------------------------------------------------------------------
# Color LUT — CPU: list of 256 [r,g,b] lists (hardware: register file)
# ---------------------------------------------------------------------------
color_lut: List[List[int]] = [[0, 0, 0]] * 256
color_lut = [list(c) for c in color_lut]   # ensure mutable sublists
color_lut[BLOCK_AIR]     = [0,   0,   0]
color_lut[BLOCK_STONE]   = [120, 120, 120]
color_lut[BLOCK_GRASS]   = [60,  160,  40]
color_lut[BLOCK_GLOWING] = [255,   0,   0]   # CPU: updated each frame

# ---------------------------------------------------------------------------
# Math Helpers — CPU setup & HW shading pipeline primitives
# ---------------------------------------------------------------------------

def _norm(v):
    """Normalise a 3-tuple. HW: parallel multiply-add + reciprocal sqrt."""
    x, y, z = v
    mag = math.sqrt(x*x + y*y + z*z)
    if mag < 1e-12:
        return (0.0, 0.0, 1.0)
    im = 1.0 / mag
    return (x*im, y*im, z*im)

def _dot(a, b):
    """Dot product. HW: 3 multipliers + 2 adders, single pipeline stage."""
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]

def _cross(a, b):
    """Cross product. HW: 6 multipliers + 3 adders."""
    return (
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0],
    )

def _sub(a, b):
    """Component-wise subtraction."""
    return (a[0]-b[0], a[1]-b[1], a[2]-b[2])

def _add(a, b):
    """Component-wise addition."""
    return (a[0]+b[0], a[1]+b[1], a[2]+b[2])

def _scale(v, s):
    """Scalar multiply. HW: 3 multipliers."""
    return (v[0]*s, v[1]*s, v[2]*s)

def _neg(v):
    """Negate. HW: bitwise sign flip on each mantissa."""
    return (-v[0], -v[1], -v[2])

def _lerp(a, b, t):
    """Linear interpolation scalar. HW: multiply-add."""
    return a + (b - a) * t

def _lerp3(a, b, t):
    """Linear interpolation 3-tuple. HW: 3 parallel multiply-adds."""
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )

def _clamp(x, lo, hi):
    """Clamp. HW: comparator + mux."""
    return lo if x < lo else (hi if x > hi else x)

def _reflect(l, n):
    """
    Reflect light direction L about normal N.
    result = 2*(L.N)*N - L
    HW: dot product + 3 multiply-adds.
    """
    d = _dot(l, n)
    return (2.0*d*n[0] - l[0], 2.0*d*n[1] - l[1], 2.0*d*n[2] - l[2])

def _mat3_mul_vec(m, v):
    """
    3x3 matrix (row-major list of 3 tuples) times a 3-vector.
    HW: 9 multipliers + 6 adders in combinational logic.
    """
    return (
        m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]*v[2],
        m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]*v[2],
        m[2][0]*v[0] + m[2][1]*v[1] + m[2][2]*v[2],
    )

# ---------------------------------------------------------------------------
# Pre-computed constant: LIGHT_DIR
# CPU: computed once at startup, stored in constant register.
# ---------------------------------------------------------------------------
LIGHT_DIR = _norm((1.0, 2.0, 1.5))   # HW: constant register, written at init

# ---------------------------------------------------------------------------
# World Generation
# ---------------------------------------------------------------------------

def build_world(grid: np.ndarray) -> None:
    """
    CPU: Populate the flat voxel grid with terrain.
    - Terrain floor at y=0: BLOCK_STONE
    - Sine/cosine height map y=1..h: BLOCK_GRASS
    - 2x2x2 BLOCK_GLOWING cluster at world-centre top
    """
    WS = WORLD_SIZE
    for x in range(WS):
        for z in range(WS):
            # CPU: Height map — sine/cosine formula
            h = 1 + int(2 * (math.sin(x * 0.4) + math.cos(z * 0.35) + 2))
            h = max(1, min(h, 6))   # clamp to [1,6]
            grid[x, 0, z] = BLOCK_STONE    # floor layer
            for y in range(1, h + 1):
                grid[x, y, z] = BLOCK_GRASS

    # CPU: 4×5×4 glowing cluster at centre, raised 3 voxels above terrain peak
    GLOW_W, GLOW_H, GLOW_D = 4, 5, 4   # width(x), height(y), depth(z)
    cx = WORLD_SIZE // 2 - GLOW_W // 2  # 30 — centred on x
    cz = WORLD_SIZE // 2 - GLOW_D // 2  # 30 — centred on z
    # Find the highest terrain voxel inside the cluster footprint
    base_h = 0
    for dx2 in range(GLOW_W):
        for dz2 in range(GLOW_D):
            for y in range(WORLD_SIZE - 1, -1, -1):
                if grid[cx + dx2, y, cz + dz2] != BLOCK_AIR:
                    if y + 1 > base_h:
                        base_h = y + 1
                    break
    gy = base_h + 3   # raise 3 voxels clear of terrain
    for dx2 in range(GLOW_W):
        for dz2 in range(GLOW_D):
            for dy2 in range(GLOW_H):
                if gy + dy2 < WORLD_SIZE:
                    grid[cx + dx2, gy + dy2, cz + dz2] = BLOCK_GLOWING

# ---------------------------------------------------------------------------
# SVO Builder Helpers
# ---------------------------------------------------------------------------

def _set_child_state(node: SVONode, child_idx: int, state: int, blk: int) -> None:
    """
    CPU: Encode state into 2-bit field of bitmask at position child_idx.
    HW analog: shift-register write to bitmask register during build phase.
    """
    shift = child_idx * 2                        # CPU: bit position
    node.bitmask &= ~(0b11 << shift)             # CPU: clear old bits
    node.bitmask |= (state << shift)             # CPU: write new state
    node.block_id[child_idx] = blk              # CPU: store block type

def _get_child_state(node: SVONode, child_idx: int) -> int:
    """
    HW: Single-cycle shift + 2-bit AND mask.
    Returns STATE_EMPTY, STATE_SOLID, or STATE_MIXED.
    """
    return (node.bitmask >> (child_idx * 2)) & 0b11   # HW: shift + AND

# ---------------------------------------------------------------------------
# SVO Builder — CPU-side recursive construction
# ---------------------------------------------------------------------------

def build_svo(grid: np.ndarray) -> List[SVONode]:
    """
    CPU: Top-down recursive SVO builder.
    Returns list of SVONode (index 0 = root).
    Recursion is acceptable here — this is CPU-side setup, not hardware pipeline.
    """
    nodes: List[SVONode] = []

    def alloc() -> int:
        """CPU: Allocate a new node, return its index."""
        idx = len(nodes)
        nodes.append(SVONode())
        return idx

    def build(nidx: int, depth: int, ox: int, oy: int, oz: int, size: int) -> None:
        half = size // 2
        for cz in range(2):
            for cy in range(2):
                for cx in range(2):
                    cidx = cx | (cy << 1) | (cz << 2)   # CPU: child index encoding
                    bx = ox + cx * half
                    by = oy + cy * half
                    bz = oz + cz * half
                    x1 = min(bx + half, WORLD_SIZE)
                    y1 = min(by + half, WORLD_SIZE)
                    z1 = min(bz + half, WORLD_SIZE)

                    # CPU: Out-of-bounds octant → always empty
                    if bx >= WORLD_SIZE or by >= WORLD_SIZE or bz >= WORLD_SIZE:
                        _set_child_state(nodes[nidx], cidx, STATE_EMPTY, BLOCK_AIR)
                        continue

                    sub = grid[bx:x1, by:y1, bz:z1]

                    if sub.size == 0 or np.all(sub == BLOCK_AIR):
                        # CPU: Entirely air — empty leaf
                        _set_child_state(nodes[nidx], cidx, STATE_EMPTY, BLOCK_AIR)
                    elif (depth + 1) == MAX_DEPTH:
                        # CPU: Max depth reached — force solid for any non-air voxel
                        dominant = int(sub.flat[0]) if sub.flat[0] != BLOCK_AIR else BLOCK_STONE
                        _set_child_state(nodes[nidx], cidx, STATE_SOLID, dominant)
                    elif np.all(sub == sub.flat[0]) and sub.flat[0] != BLOCK_AIR:
                        # CPU: Uniform non-air region — solid leaf
                        dominant = int(sub.flat[0])
                        _set_child_state(nodes[nidx], cidx, STATE_SOLID, dominant)
                    else:
                        # CPU: Mixed — must descend further
                        _set_child_state(nodes[nidx], cidx, STATE_MIXED, BLOCK_AIR)
                        child_nidx = alloc()
                        nodes[nidx].children[cidx] = child_nidx
                        build(child_nidx, depth + 1, bx, by, bz, half)

    root = alloc()
    build(root, 0, 0, 0, 0, WORLD_SIZE)
    return nodes

# ---------------------------------------------------------------------------
# Camera & Transformation Helpers
# ---------------------------------------------------------------------------

def make_look_at(eye, target, up):
    """
    CPU: Build a 3x3 rotation matrix from camera parameters.
    HW: Matrix is pre-loaded into ray-generation registers before each frame.
    Returns row-major 3x3 as list of 3 tuples.
    """
    forward = _norm(_sub(target, eye))        # CPU: -Z axis in view space
    right   = _norm(_cross(forward, up))      # CPU: +X axis
    up_     = _cross(right, forward)          # CPU: +Y axis (recomputed for orthogonality)
    # Row-major: [right, up_, forward]
    return [right, up_, forward]

def make_orbit_camera(frame_idx: int, radius: float, height: float):
    """
    CPU: Compute eye position and rotation matrix for orbit animation frame.
    HW: Called once per frame by CPU control logic; results loaded into registers.
    """
    angle = frame_idx * (2.0 * math.pi / NUM_FRAMES)   # CPU: frame angle
    cx = WORLD_SIZE / 2.0 + math.sin(angle) * radius   # CPU: orbit X
    cz = WORLD_SIZE / 2.0 + math.cos(angle) * radius   # CPU: orbit Z
    eye    = (cx, float(height), cz)
    target = (WORLD_SIZE / 2.0, 4.0, WORLD_SIZE / 2.0)
    rot    = make_look_at(eye, target, (0.0, 1.0, 0.0))
    return eye, rot

# ---------------------------------------------------------------------------
# Dynamic LUT Update
# ---------------------------------------------------------------------------

def update_color_lut(frame_idx: int) -> None:
    """
    CPU: Update BLOCK_GLOWING entry in the color LUT before each frame.
    HW: CPU writes configuration register / BRAM row before frame start.
         FPGA ray pipeline only reads — no branching on frame number inside pipeline.
    """
    pulse = 0.5 + 0.5 * math.sin(frame_idx * 2.0 * math.pi / NUM_FRAMES)  # CPU: sine oscillator
    r = int(200 + 55 * pulse)               # CPU: red channel modulation
    g = int(80  * pulse)                    # CPU: green channel modulation
    b = int(30  + 50 * (1.0 - pulse))       # CPU: blue channel modulation
    color_lut[BLOCK_GLOWING] = [r, g, b]   # CPU: register write to LUT BRAM

# ---------------------------------------------------------------------------
# SVO Traversal — THE CORE (FPGA Pipeline)
# ---------------------------------------------------------------------------

def svo_traverse(
    ray_ox: float, ray_oy: float, ray_oz: float,
    ray_dx: float, ray_dy: float, ray_dz: float,
    svo_nodes: List[SVONode],
    shadow_mode: bool = False
):
    """
    HW: Fixed-depth LIFO stack SVO traversal.
    No division, no append, no recursion, no dynamic allocation.
    Returns: (t, (hx,hy,hz), face_axis, face_sign, block_id) on hit,
             True on shadow hit (shadow_mode=True),
             None on miss.
    """
    WS = float(WORLD_SIZE)   # HW: constant register

    # HW: Pre-compute reciprocals once per ray — no division allowed in loop
    inv_dx = 1.0 / (ray_dx if abs(ray_dx) > 1e-9 else 1e-9)   # HW: reciprocal unit (ray setup stage)
    inv_dy = 1.0 / (ray_dy if abs(ray_dy) > 1e-9 else 1e-9)   # HW: reciprocal unit
    inv_dz = 1.0 / (ray_dz if abs(ray_dz) > 1e-9 else 1e-9)   # HW: reciprocal unit

    # HW: Sign bits — 1-bit registers used for child octant selection
    sign_x = 1 if ray_dx >= 0.0 else 0   # HW: sign bit of ray_dx
    sign_y = 1 if ray_dy >= 0.0 else 0   # HW: sign bit of ray_dy
    sign_z = 1 if ray_dz >= 0.0 else 0   # HW: sign bit of ray_dz

    # HW: Root AABB slab intersection test (using pre-computed reciprocals)
    if sign_x:                                          # HW: mux on sign_x
        tx_enter = (0.0  - ray_ox) * inv_dx            # HW: multiply (no division)
        tx_exit  = (WS   - ray_ox) * inv_dx            # HW: multiply
    else:
        tx_enter = (WS   - ray_ox) * inv_dx            # HW: multiply
        tx_exit  = (0.0  - ray_ox) * inv_dx            # HW: multiply

    if sign_y:                                          # HW: mux on sign_y
        ty_enter = (0.0  - ray_oy) * inv_dy            # HW: multiply
        ty_exit  = (WS   - ray_oy) * inv_dy            # HW: multiply
    else:
        ty_enter = (WS   - ray_oy) * inv_dy            # HW: multiply
        ty_exit  = (0.0  - ray_oy) * inv_dy            # HW: multiply

    if sign_z:                                          # HW: mux on sign_z
        tz_enter = (0.0  - ray_oz) * inv_dz            # HW: multiply
        tz_exit  = (WS   - ray_oz) * inv_dz            # HW: multiply
    else:
        tz_enter = (WS   - ray_oz) * inv_dz            # HW: multiply
        tz_exit  = (0.0  - ray_oz) * inv_dz            # HW: multiply

    # HW: t_enter = max of slab entries; t_exit = min of slab exits
    t_enter = max(tx_enter, ty_enter, tz_enter, 0.0)   # HW: 3-input max comparator
    t_exit  = min(tx_exit,  ty_exit,  tz_exit)         # HW: 3-input min comparator

    if t_enter >= t_exit:   # HW: comparator — miss check
        return None

    # HW: Determine entry face of root (which slab was entered last)
    if tx_enter >= ty_enter and tx_enter >= tz_enter:   # HW: comparators
        face_axis = 0                                   # HW: face axis register = X
        face_sign = 1 if ray_dx < 0.0 else -1          # HW: sign mux
    elif ty_enter >= tz_enter:
        face_axis = 1                                   # HW: face axis register = Y
        face_sign = 1 if ray_dy < 0.0 else -1          # HW: sign mux
    else:
        face_axis = 2                                   # HW: face axis register = Z
        face_sign = 1 if ray_dz < 0.0 else -1          # HW: sign mux

    # HW: Entry hit point (nudge slightly forward to select correct initial child)
    hx = ray_ox + ray_dx * (t_enter + 1e-7)   # HW: multiply-add (entry point X)
    hy = ray_oy + ray_dy * (t_enter + 1e-7)   # HW: multiply-add (entry point Y)
    hz = ray_oz + ray_dz * (t_enter + 1e-7)   # HW: multiply-add (entry point Z)

    # HW: Initial child selection from entry hit point vs root mid-planes
    cx = 1 if hx >= WS * 0.5 else 0   # HW: comparator + 1-bit register
    cy = 1 if hy >= WS * 0.5 else 0   # HW: comparator + 1-bit register
    cz = 1 if hz >= WS * 0.5 else 0   # HW: comparator + 1-bit register

    # HW: Root mid-plane t values (set to INF if already past)
    tx_mid = (WS * 0.5 - ray_ox) * inv_dx   # HW: multiply — root X mid-plane
    ty_mid = (WS * 0.5 - ray_oy) * inv_dy   # HW: multiply — root Y mid-plane
    tz_mid = (WS * 0.5 - ray_oz) * inv_dz   # HW: multiply — root Z mid-plane

    # HW: If mid-plane already behind entry t, sentinel to INF (crossed, no future step)
    tx0 = tx_mid if tx_mid > t_enter + 1e-9 else INF   # HW: comparator + mux → INF reg
    ty0 = ty_mid if ty_mid > t_enter + 1e-9 else INF   # HW: comparator + mux
    tz0 = tz_mid if tz_mid > t_enter + 1e-9 else INF   # HW: comparator + mux

    # ---------------------------------------------------------------------------
    # HW: Pre-allocated fixed-depth traversal stack — HARDWARE REGISTER FILE
    #     Never use append — each slot is a named set of registers.
    # ---------------------------------------------------------------------------
    stk_node       = [0]   * STACK_DEPTH   # HW: node-index register per slot
    stk_scale      = [0.0] * STACK_DEPTH   # HW: node-size register per slot
    stk_ox         = [0.0] * STACK_DEPTH   # HW: origin X register per slot
    stk_oy         = [0.0] * STACK_DEPTH   # HW: origin Y register per slot
    stk_oz         = [0.0] * STACK_DEPTH   # HW: origin Z register per slot
    stk_cx         = [0]   * STACK_DEPTH   # HW: current child X bit per slot
    stk_cy         = [0]   * STACK_DEPTH   # HW: current child Y bit per slot
    stk_cz         = [0]   * STACK_DEPTH   # HW: current child Z bit per slot
    stk_tx         = [0.0] * STACK_DEPTH   # HW: DDA boundary t X per slot
    stk_ty         = [0.0] * STACK_DEPTH   # HW: DDA boundary t Y per slot
    stk_tz         = [0.0] * STACK_DEPTH   # HW: DDA boundary t Z per slot
    stk_t_now      = [0.0] * STACK_DEPTH   # HW: current t at entry to child per slot
    stk_t_exit     = [0.0] * STACK_DEPTH   # HW: t at which ray exits whole node
    stk_face_axis  = [0]   * STACK_DEPTH   # HW: entry face axis per slot
    stk_face_sign  = [0]   * STACK_DEPTH   # HW: entry face sign per slot

    # HW: Push root node onto stack (stack pointer = integer register)
    stk_node[0]      = 0           # HW: root node index
    stk_scale[0]     = WS          # HW: root node scale = world size
    stk_ox[0]        = 0.0         # HW: root origin X
    stk_oy[0]        = 0.0         # HW: root origin Y
    stk_oz[0]        = 0.0         # HW: root origin Z
    stk_cx[0]        = cx          # HW: initial child X bit
    stk_cy[0]        = cy          # HW: initial child Y bit
    stk_cz[0]        = cz          # HW: initial child Z bit
    stk_tx[0]        = tx0         # HW: root X mid-plane t
    stk_ty[0]        = ty0         # HW: root Y mid-plane t
    stk_tz[0]        = tz0         # HW: root Z mid-plane t
    stk_t_now[0]     = t_enter     # HW: t at entry to root
    stk_t_exit[0]    = t_exit      # HW: t at exit from root
    stk_face_axis[0] = face_axis   # HW: root entry face axis
    stk_face_sign[0] = face_sign   # HW: root entry face sign
    stk_ptr = 1                    # HW: stack pointer register = 1

    # ---------------------------------------------------------------------------
    # HW: Main traversal loop — runs until stack empty or hit found
    # ---------------------------------------------------------------------------
    while stk_ptr > 0:   # HW: comparator on stack pointer register

        # HW: POP — decrement stack pointer (register decrement)
        stk_ptr -= 1   # HW: stack_ptr--

        # HW: Load all state registers from stack slot stk_ptr
        node_idx  = stk_node[stk_ptr]       # HW: load node index register
        scale     = stk_scale[stk_ptr]      # HW: load scale register
        ox        = stk_ox[stk_ptr]         # HW: load origin X
        oy        = stk_oy[stk_ptr]         # HW: load origin Y
        oz        = stk_oz[stk_ptr]         # HW: load origin Z
        cx        = stk_cx[stk_ptr]         # HW: load child X bit
        cy        = stk_cy[stk_ptr]         # HW: load child Y bit
        cz        = stk_cz[stk_ptr]         # HW: load child Z bit
        tx        = stk_tx[stk_ptr]         # HW: load DDA boundary t X
        ty        = stk_ty[stk_ptr]         # HW: load DDA boundary t Y
        tz        = stk_tz[stk_ptr]         # HW: load DDA boundary t Z
        t_now     = stk_t_now[stk_ptr]      # HW: load current t
        t_node_exit = stk_t_exit[stk_ptr]   # HW: load node exit t
        face_axis = stk_face_axis[stk_ptr]  # HW: load face axis
        face_sign = stk_face_sign[stk_ptr]  # HW: load face sign

        # HW: Fetch node from BRAM (addressed by node_idx)
        node = svo_nodes[node_idx]          # HW: BRAM read — 1 or 2 cycle latency
        metrics.nodes_visited += 1          # Observation: increment counter register

        # HW: Node half-size — single right-shift (power-of-2 scale)
        half = scale * 0.5   # HW: arithmetic right-shift by 1 (float: exponent decrement)

        # ---------------------------------------------------------------------------
        # HW: Inner DDA loop — enumerate children front-to-back within this node
        # ---------------------------------------------------------------------------
        while t_now < t_node_exit:   # HW: comparator on t registers

            # HW: Compute child index from child bit registers (combinational logic)
            child_idx = cx | (cy << 1) | (cz << 2)   # HW: 3-bit concatenation / OR + shift

            # HW: t_child_exit = min(tx, ty, tz, t_node_exit) — 4-input comparator tree
            t_child_exit = min(tx, ty, tz, t_node_exit)   # HW: min comparator tree

            # HW: Bitmask lookup — single clock: right-shift + 2-bit AND mask
            metrics.bitmask_checks += 1                          # Observation: counter
            state = (node.bitmask >> (child_idx * 2)) & 0b11    # HW: shift reg + AND gate

            # HW: State decode — 2-bit comparator
            if state == STATE_SOLID:   # HW: 2-bit equality comparator
                # HW: SOLID hit — terminate ray, return hit data
                if shadow_mode:                              # HW: mode register check
                    return True                              # HW: shadow hit signal
                # HW: Compute exact hit position from t_now (multiply-add)
                hit_x = ray_ox + ray_dx * t_now   # HW: multiply-add unit
                hit_y = ray_oy + ray_dy * t_now   # HW: multiply-add unit
                hit_z = ray_oz + ray_dz * t_now   # HW: multiply-add unit
                return (t_now, (hit_x, hit_y, hit_z), face_axis, face_sign, node.block_id[child_idx])

            elif state == STATE_MIXED:   # HW: 2-bit equality comparator
                # HW: MIXED — must descend into child node; push parent resume state first

                # HW: Compute next child state for parent resume (DDA advance on parent)
                next_cx        = cx                # HW: latch current child bits
                next_cy        = cy
                next_cz        = cz
                next_tx        = tx                # HW: latch current boundary t values
                next_ty        = ty
                next_tz        = tz
                next_face_axis = face_axis         # HW: latch current face
                next_face_sign = face_sign

                # HW: Determine which boundary was crossed to reach t_child_exit
                if abs(t_child_exit - tx) < 1e-9:                    # HW: comparator with epsilon
                    next_cx = 1 - cx                                  # HW: 1-bit XOR / toggle
                    next_tx = INF                                      # HW: write INF sentinel to t register
                    next_face_axis = 0                                 # HW: face axis = X
                    next_face_sign = 1 if ray_dx < 0.0 else -1        # HW: sign mux
                elif abs(t_child_exit - ty) < 1e-9:                   # HW: comparator with epsilon
                    next_cy = 1 - cy                                   # HW: 1-bit XOR
                    next_ty = INF                                       # HW: write INF sentinel
                    next_face_axis = 1                                  # HW: face axis = Y
                    next_face_sign = 1 if ray_dy < 0.0 else -1         # HW: sign mux
                else:
                    next_cz = 1 - cz                                   # HW: 1-bit XOR
                    next_tz = INF                                       # HW: write INF sentinel
                    next_face_axis = 2                                  # HW: face axis = Z
                    next_face_sign = 1 if ray_dz < 0.0 else -1         # HW: sign mux

                # HW: PUSH parent resume state — stack_ptr++ with register write
                if stk_ptr < STACK_DEPTH:   # HW: stack overflow guard (comparator)
                    stk_node[stk_ptr]      = node_idx        # HW: write node index to stack slot
                    stk_scale[stk_ptr]     = scale           # HW: write scale
                    stk_ox[stk_ptr]        = ox              # HW: write origin X
                    stk_oy[stk_ptr]        = oy              # HW: write origin Y
                    stk_oz[stk_ptr]        = oz              # HW: write origin Z
                    stk_cx[stk_ptr]        = next_cx         # HW: write next child X bit
                    stk_cy[stk_ptr]        = next_cy         # HW: write next child Y bit
                    stk_cz[stk_ptr]        = next_cz         # HW: write next child Z bit
                    stk_tx[stk_ptr]        = next_tx         # HW: write DDA boundary t X
                    stk_ty[stk_ptr]        = next_ty         # HW: write DDA boundary t Y
                    stk_tz[stk_ptr]        = next_tz         # HW: write DDA boundary t Z
                    stk_t_now[stk_ptr]     = t_child_exit    # HW: parent resumes at t_child_exit
                    stk_t_exit[stk_ptr]    = t_node_exit     # HW: parent node exit t unchanged
                    stk_face_axis[stk_ptr] = next_face_axis  # HW: write face axis
                    stk_face_sign[stk_ptr] = next_face_sign  # HW: write face sign
                    stk_ptr += 1                             # HW: stack_ptr++

                # HW: Compute child node geometry
                child_node_idx = node.children[child_idx]   # HW: BRAM read — child pointer

                # HW: Child origin = parent origin + child bit * half-size (multiply-add)
                child_ox = ox + cx * half   # HW: multiply-add
                child_oy = oy + cy * half   # HW: multiply-add
                child_oz = oz + cz * half   # HW: multiply-add

                child_half = half * 0.5     # HW: arithmetic right-shift (exponent decrement)

                # HW: Child node exit t (slab test on child AABB, using reciprocals)
                if sign_x:                                                          # HW: mux on sign_x
                    child_t_exit_x = (child_ox + half - ray_ox) * inv_dx           # HW: multiply
                else:
                    child_t_exit_x = (child_ox - ray_ox) * inv_dx                  # HW: multiply

                if sign_y:                                                          # HW: mux on sign_y
                    child_t_exit_y = (child_oy + half - ray_oy) * inv_dy           # HW: multiply
                else:
                    child_t_exit_y = (child_oy - ray_oy) * inv_dy                  # HW: multiply

                if sign_z:                                                          # HW: mux on sign_z
                    child_t_exit_z = (child_oz + half - ray_oz) * inv_dz           # HW: multiply
                else:
                    child_t_exit_z = (child_oz - ray_oz) * inv_dz                  # HW: multiply

                child_t_exit = min(child_t_exit_x, child_t_exit_y, child_t_exit_z) # HW: min comparator

                # HW: Child mid-plane t values (set INF if already passed)
                child_tx_mid = (child_ox + child_half - ray_ox) * inv_dx   # HW: multiply
                child_ty_mid = (child_oy + child_half - ray_oy) * inv_dy   # HW: multiply
                child_tz_mid = (child_oz + child_half - ray_oz) * inv_dz   # HW: multiply

                # HW: Comparator + mux — if mid-plane behind t_now, sentinel INF
                child_tx = child_tx_mid if child_tx_mid > t_now + 1e-9 else INF   # HW: comparator+mux
                child_ty = child_ty_mid if child_ty_mid > t_now + 1e-9 else INF   # HW: comparator+mux
                child_tz = child_tz_mid if child_tz_mid > t_now + 1e-9 else INF   # HW: comparator+mux

                # HW: Determine initial child-of-child from entry hit position (nudged t)
                ehx = ray_ox + ray_dx * (t_now + 1e-7)   # HW: multiply-add (entry point X)
                ehy = ray_oy + ray_dy * (t_now + 1e-7)   # HW: multiply-add (entry point Y)
                ehz = ray_oz + ray_dz * (t_now + 1e-7)   # HW: multiply-add (entry point Z)

                # HW: Comparator against child mid-planes to pick initial child bit
                child_cx = 1 if ehx >= child_ox + child_half else 0   # HW: comparator
                child_cy = 1 if ehy >= child_oy + child_half else 0   # HW: comparator
                child_cz = 1 if ehz >= child_oz + child_half else 0   # HW: comparator

                # HW: PUSH child node — stack_ptr++ with register write
                if stk_ptr < STACK_DEPTH:   # HW: stack overflow guard
                    stk_node[stk_ptr]      = child_node_idx   # HW: write child node index
                    stk_scale[stk_ptr]     = half             # HW: write child scale
                    stk_ox[stk_ptr]        = child_ox         # HW: write child origin X
                    stk_oy[stk_ptr]        = child_oy         # HW: write child origin Y
                    stk_oz[stk_ptr]        = child_oz         # HW: write child origin Z
                    stk_cx[stk_ptr]        = child_cx         # HW: write initial child X bit
                    stk_cy[stk_ptr]        = child_cy         # HW: write initial child Y bit
                    stk_cz[stk_ptr]        = child_cz         # HW: write initial child Z bit
                    stk_tx[stk_ptr]        = child_tx         # HW: write child DDA boundary t X
                    stk_ty[stk_ptr]        = child_ty         # HW: write child DDA boundary t Y
                    stk_tz[stk_ptr]        = child_tz         # HW: write child DDA boundary t Z
                    stk_t_now[stk_ptr]     = t_now            # HW: child starts at current t
                    stk_t_exit[stk_ptr]    = child_t_exit     # HW: child exits at child_t_exit
                    stk_face_axis[stk_ptr] = face_axis        # HW: inherit entry face axis
                    stk_face_sign[stk_ptr] = face_sign        # HW: inherit entry face sign
                    stk_ptr += 1                              # HW: stack_ptr++

                break   # HW: break inner DDA loop, outer loop processes child next iteration

            # HW: STATE_EMPTY — advance DDA to next child (no recursion, no hit)
            t_now = t_child_exit   # HW: t register update

            if t_now >= t_node_exit:   # HW: comparator — exited node?
                break

            # HW: DDA step — determine which boundary was crossed and update child bits
            if abs(t_child_exit - tx) < 1e-9:        # HW: comparator with epsilon
                cx = 1 - cx                          # HW: 1-bit XOR / toggle
                tx = INF                              # HW: set sentinel — X boundary consumed
                face_axis = 0                         # HW: face axis register = X
                face_sign = 1 if ray_dx < 0.0 else -1  # HW: sign mux
            elif abs(t_child_exit - ty) < 1e-9:       # HW: comparator
                cy = 1 - cy                           # HW: 1-bit XOR
                ty = INF                               # HW: set sentinel
                face_axis = 1                          # HW: face axis = Y
                face_sign = 1 if ray_dy < 0.0 else -1   # HW: sign mux
            else:
                cz = 1 - cz                            # HW: 1-bit XOR
                tz = INF                                # HW: set sentinel
                face_axis = 2                           # HW: face axis = Z
                face_sign = 1 if ray_dz < 0.0 else -1   # HW: sign mux

            # HW: Out-of-bounds check — if child bit went out of [0,1] range, exit node
            if cx < 0 or cx > 1 or cy < 0 or cy > 1 or cz < 0 or cz > 1:   # HW: 3 comparators
                break

    return None   # HW: stack exhausted — ray miss

# ---------------------------------------------------------------------------
# Shading Pipeline
# ---------------------------------------------------------------------------

def shade_hit(t, hit_pos, face_axis, face_sign, block_id, ray_d, svo_nodes):
    """
    HW: Shading pipeline — runs after traversal returns a hit.
    Implements hemisphere lighting, procedural texture, Phong specular,
    shadow ray, and distance fog.
    """
    hx, hy, hz = hit_pos

    # HW: Surface normal recovery from face_axis and face_sign registers
    normal = [0.0, 0.0, 0.0]
    normal[face_axis] = float(face_sign)   # HW: write to normal register at face_axis index

    # HW: Hemisphere lighting — LERP between ground and sky color (dot product weight)
    hemi_t     = (normal[1] + 1.0) * 0.5                          # HW: multiply-add (normalize Y normal)
    hemi_color = _lerp3(GROUND_COLOR, SKY_COLOR, hemi_t)           # HW: 3 parallel LERP units

    # HW: Procedural texture — XOR checkerboard (zero-cost in logic, single clock)
    ix = int(math.floor(hx))                            # HW: floor unit (truncate fractional bits)
    iy = int(math.floor(hy))                            # HW: floor unit
    iz = int(math.floor(hz))                            # HW: floor unit
    pattern = (ix ^ iy ^ iz) & 1                        # HW: 3-input XOR + AND mask — single gate
    base    = color_lut[block_id]                        # HW: LUT BRAM read (1 cycle)
    scale_p = 0.75 + 0.25 * pattern                     # HW: mux between 0.75 and 1.0
    tex     = [base[c] * scale_p for c in range(3)]     # HW: 3 multipliers

    # HW: Shadow ray — second traversal (time-multiplexed or dedicated unit)
    bias_pos = (
        hx + normal[0] * SHADOW_BIAS,   # HW: multiply-add (bias origin along normal)
        hy + normal[1] * SHADOW_BIAS,   # HW: multiply-add
        hz + normal[2] * SHADOW_BIAS,   # HW: multiply-add
    )
    shadow_hit = svo_traverse(
        bias_pos[0], bias_pos[1], bias_pos[2],
        LIGHT_DIR[0], LIGHT_DIR[1], LIGHT_DIR[2],
        svo_nodes, shadow_mode=True
    )
    metrics.shadow_rays += 1              # Observation: shadow ray counter
    shadow_mult = 0.3 if shadow_hit else 1.0   # HW: mux on shadow hit signal

    # HW: Diffuse term — dot product with light direction (clamp to [0,1])
    diff = max(0.0, _dot(normal, LIGHT_DIR))   # HW: dot product + max comparator

    # HW: Phong specular — reflect + dot + power via squarings
    refl = _norm(_reflect(LIGHT_DIR, tuple(normal)))   # HW: reflect unit + normalizer
    view = _norm(_neg(ray_d))                          # HW: negate + normalizer
    s    = max(0.0, _dot(refl, view))                  # HW: dot product + max clamp
    s = s*s; s = s*s; s = s*s; s = s*s; s = s*s       # HW: 5 squarings = ^32 (pipeline stages)
    spec = s * 60.0                                    # HW: scalar multiply

    # HW: Combine — hemisphere + texture + diffuse, multiplied by shadow, plus specular
    lit = [
        (hemi_color[c] * 0.45 + tex[c] * 0.55 + diff * 20.0) * shadow_mult + spec
        for c in range(3)
    ]   # HW: per-channel multiply-add tree

    # HW: Distance fog — LERP with t-based weight, saturated at MAX_T
    fog_t = _clamp((t - FOG_START) / (MAX_T - FOG_START), 0.0, 1.0)   # HW: subtract + multiply + clamp
    final = [_lerp(lit[c], FOG_COLOR[c], fog_t) for c in range(3)]     # HW: 3 LERP units

    return tuple(int(_clamp(final[c], 0.0, 255.0)) for c in range(3))  # HW: clamp + int conversion


def shade_miss(ray_d):
    """
    HW: Sky gradient for ray miss.
    Returns sky color based on ray Y direction.
    """
    sky_t   = max(0.0, ray_d[1])                              # HW: max comparator
    miss_c  = _lerp3(
        (SKY_COLOR[0]*0.7, SKY_COLOR[1]*0.7, SKY_COLOR[2]*0.7),
        SKY_COLOR,
        sky_t
    )                                                          # HW: 3 LERP units
    return tuple(int(_clamp(c, 0.0, 255.0)) for c in miss_c)  # HW: clamp + convert

# ---------------------------------------------------------------------------
# Primary Ray Casting
# ---------------------------------------------------------------------------

def cast_primary_ray(px: int, py: int, eye, rot_mat, svo_nodes: List[SVONode]):
    """
    CPU: Generate primary ray for pixel (px, py) and invoke traversal + shading.
    HW analog: ray-generation unit computes NDC → camera → world ray per pixel.
    """
    aspect = IMG_W / IMG_H                                      # CPU: precomputed aspect ratio
    tan_half_fov = math.tan(math.radians(FOV_DEG) * 0.5)       # CPU: constant per frame

    # CPU: Normalised device coordinates
    u = (px + 0.5) / IMG_W * 2.0 - 1.0    # CPU: pixel centre NDC X
    v = 1.0 - (py + 0.5) / IMG_H * 2.0    # CPU: pixel centre NDC Y (flipped)

    # CPU: Extract camera basis vectors from rotation matrix rows
    # make_look_at stores rot_mat = [right, up_, forward] as rows
    cam_right   = rot_mat[0]   # world-space right direction
    cam_up      = rot_mat[1]   # world-space up direction
    cam_forward = rot_mat[2]   # world-space forward (target - eye, normalised)

    # HW: Ray direction = forward + right*u*aspect*tan + up*v*tan
    #     This is the direct camera-to-world ray formula.
    #     In hardware: multiply-accumulate unit with pre-loaded basis registers.
    ray_d = _norm((
        cam_forward[0] + cam_right[0] * u * aspect * tan_half_fov + cam_up[0] * v * tan_half_fov,
        cam_forward[1] + cam_right[1] * u * aspect * tan_half_fov + cam_up[1] * v * tan_half_fov,
        cam_forward[2] + cam_right[2] * u * aspect * tan_half_fov + cam_up[2] * v * tan_half_fov,
    ))   # HW: 3-channel MAC + normaliser

    # HW: Ray origin = camera eye position (pre-loaded register)
    ray_o = eye

    metrics.primary_rays += 1   # Observation: primary ray counter

    result = svo_traverse(
        ray_o[0], ray_o[1], ray_o[2],
        ray_d[0], ray_d[1], ray_d[2],
        svo_nodes, shadow_mode=False
    )

    if result is None:
        return shade_miss(ray_d)
    else:
        t, hit_pos, face_axis, face_sign, block_id = result
        return shade_hit(t, hit_pos, face_axis, face_sign, block_id, ray_d, svo_nodes)

# ---------------------------------------------------------------------------
# PPM Writer
# ---------------------------------------------------------------------------

def write_ppm(path: str, pixels: np.ndarray, width: int, height: int) -> None:
    """
    CPU: Write ASCII PPM P3 format. No external library needed.
    HW: Analogous to frame-buffer DMA readout.
    P3 uses plain-text RGB triplets — universally supported by viewers.
    """
    with open(path, 'w') as f:
        f.write(f"P3\n{width} {height}\n255\n")            # CPU: PPM header
        flat = pixels.astype(np.uint8).reshape(-1, 3)
        for r, g, b in flat:
            f.write(f"{r} {g} {b}\n")                      # CPU: one RGB triplet per line

# ---------------------------------------------------------------------------
# GIF Stitcher
# ---------------------------------------------------------------------------

def stitch_gif(frame_dir: str, out_path: str, fps: int = 10) -> None:
    """CPU: Stitch rendered PPM frames into an animated GIF using Pillow."""
    try:
        from PIL import Image   # Soft dependency — fallback if missing
        paths = sorted(glob.glob(frame_dir))
        if not paths:
            print("No frames found for GIF stitching.")
            return
        frames = [Image.open(p).convert("RGB") for p in paths]
        frames[0].save(
            out_path, save_all=True, append_images=frames[1:],
            duration=int(1000 / fps), loop=0
        )
        print(f"GIF saved → {out_path}")
    except ImportError:
        print("Pillow not installed — skipping GIF creation.")
        print("  Install with: pip install Pillow")
        print(f"  Frames available in: {frame_dir}")

# ---------------------------------------------------------------------------
# Metrics Report
# ---------------------------------------------------------------------------

def print_metrics(total_frames: int, metrics_path: str = None) -> None:
    """CPU: Print hardware-accurate performance metrics report to terminal and optionally a txt file."""
    total_primary = metrics.primary_rays
    total_shadow  = metrics.shadow_rays
    total_nodes   = metrics.nodes_visited
    total_bitmask = metrics.bitmask_checks

    all_rays = total_primary + total_shadow
    avg_nodes   = total_nodes   / all_rays if all_rays > 0 else 0.0
    avg_bitmask = total_bitmask / all_rays if all_rays > 0 else 0.0

    lines = [
        "=" * 40,
        "  SVO Raytracer — Hardware Metrics Report",
        "=" * 40,
        f"  Total primary rays cast   : {total_primary:,}",
        f"  Total shadow rays cast    : {total_shadow:,}",
        f"  Total nodes visited       : {total_nodes:,}",
        f"  Total bitmask checks      : {total_bitmask:,}",
        f"  Avg nodes visited  / ray  : {avg_nodes:.2f}",
        f"  Avg bitmask checks / ray  : {avg_bitmask:.2f}",
        f"  Total frames rendered     : {total_frames}",
        f"  Resolution                : {IMG_W} x {IMG_H}",
        f"  SVO max depth             : {MAX_DEPTH}",
        f"  World size                : {WORLD_SIZE}^3 voxels",
        "=" * 40,
    ]

    report = "\n".join(lines)
    print(report)   # CPU: terminal output

    if metrics_path:
        with open(metrics_path, 'w') as f:
            f.write(report + "\n")
        print(f"  Metrics saved → {metrics_path}")

# ---------------------------------------------------------------------------
# Main Entry Point
# ---------------------------------------------------------------------------

def main() -> None:
    """CPU: Top-level control flow — world build, SVO build, render loop, GIF stitch."""
    sys.setrecursionlimit(10000)   # CPU: increase for deep SVO build recursion

    base_dir    = os.path.dirname(os.path.abspath(__file__))
    frame_dir   = os.path.join(base_dir, "frames")
    out_gif     = os.path.join(base_dir, "output_svo.gif")
    metrics_txt = os.path.join(base_dir, "hardware_metrics.txt")
    os.makedirs(frame_dir, exist_ok=True)   # CPU: create output directories

    # CPU: Build voxel world
    print("Building voxel world...")
    voxel_grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    build_world(voxel_grid)
    print(f"  World built. Non-air voxels: {np.sum(voxel_grid != BLOCK_AIR)}")

    # CPU: Build SVO from voxel grid
    print("Building SVO...")
    svo_nodes = build_svo(voxel_grid)
    print(f"  SVO built. Total nodes: {len(svo_nodes)}")
    print(f"  Root bitmask: 0b{svo_nodes[0].bitmask:016b}")

    # CPU: Render loop
    global metrics
    metrics = Metrics()   # CPU: reset metrics

    for frame_idx in range(NUM_FRAMES):
        # CPU: Update dynamic LUT (register write before frame pipeline starts)
        update_color_lut(frame_idx)

        # CPU: Compute camera matrices for this frame
        eye, rot_mat = make_orbit_camera(frame_idx, ORBIT_RADIUS, ORBIT_HEIGHT)

        # CPU: Allocate pixel buffer (HW: frame buffer BRAM)
        pixels = np.zeros((IMG_H, IMG_W, 3), dtype=np.uint8)

        # CPU/HW: Per-pixel ray generation & traversal
        for py in range(IMG_H):
            for px in range(IMG_W):
                color = cast_primary_ray(px, py, eye, rot_mat, svo_nodes)
                pixels[py, px] = color   # HW: write to frame buffer BRAM

        # CPU: Write frame PPM
        frame_path = os.path.join(frame_dir, f"frame_{frame_idx:03d}.ppm")
        write_ppm(frame_path, pixels, IMG_W, IMG_H)

        print(f"Frame {frame_idx + 1}/{NUM_FRAMES} complete — {frame_path}")

    # CPU: Stitch GIF
    stitch_gif(os.path.join(frame_dir, "*.ppm"), out_gif, fps=10)

    # CPU: Print metrics
    print_metrics(NUM_FRAMES, metrics_path=metrics_txt)


if __name__ == "__main__":
    main()
