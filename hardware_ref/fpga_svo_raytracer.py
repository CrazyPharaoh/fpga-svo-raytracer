"""
fpga_svo_raytracer.py — Python golden reference for the SVO raytracer hardware.

Traversal mirrors the RTL register-file design: no dynamic allocation, no
division, no recursion inside the loop; fixed LIFO stack; DDA front-to-back
child ordering.
"""

import math
import os
import glob
import sys
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
WORLD_SIZE    = 64          # voxels per axis (must be power of 2)
MAX_DEPTH     = 6           # SVO depth = log2(64) = 6 levels
STACK_DEPTH   = 12          # fixed LIFO stack depth (register file size) — doubled for safety
IMG_W         = 320
IMG_H         = 240
NUM_FRAMES    = 30
FOV_DEG       = 60.0
MAX_T         = 200.0       # far-plane clipping distance
FOG_START     = 15.0        # distance at which fog begins
SHADOW_BIAS   = 0.01        # offset origin along normal to avoid self-intersection

# 3-state bitmask codes (2 bits per child slot)
STATE_EMPTY   = 0b00        # air — ray passes through
STATE_SOLID   = 0b11        # solid — terminates ray
STATE_MIXED   = 0b01        # internal — descend into child node

BLOCK_AIR     = 0
BLOCK_STONE   = 1
BLOCK_GRASS   = 2
BLOCK_GLOWING = 3           # pulsing emissive, updated each frame

SKY_COLOR     = (135, 206, 235)
GROUND_COLOR  = (80,  60,  40)
FOG_COLOR     = (180, 200, 220)

ORBIT_RADIUS  = 30
ORBIT_HEIGHT  = 20

INF = float('inf')  # sentinel: mid-plane already crossed, never step again

# ---------------------------------------------------------------------------
# Data Structures
# ---------------------------------------------------------------------------

@dataclass
class SVONode:
    """One octree node. bitmask[2i+1:2i] = child i state (EMPTY/SOLID/MIXED)."""
    bitmask:  int       = 0
    children: List      = field(default_factory=lambda: [None] * 8)
    block_id: List[int] = field(default_factory=lambda: [0] * 8)


@dataclass
class Metrics:
    """Traversal performance counters."""
    primary_rays:    int = 0
    shadow_rays:     int = 0
    nodes_visited:   int = 0
    bitmask_checks:  int = 0


metrics = Metrics()

# ---------------------------------------------------------------------------
# Color LUT
# ---------------------------------------------------------------------------
color_lut: List[List[int]] = [[0, 0, 0]] * 256
color_lut = [list(c) for c in color_lut]
color_lut[BLOCK_AIR]     = [0,   0,   0]
color_lut[BLOCK_STONE]   = [120, 120, 120]
color_lut[BLOCK_GRASS]   = [60,  160,  40]
color_lut[BLOCK_GLOWING] = [255,   0,   0]   # overwritten each frame by update_color_lut

# ---------------------------------------------------------------------------
# Vector helpers
# ---------------------------------------------------------------------------

def _norm(v):
    x, y, z = v
    mag = math.sqrt(x*x + y*y + z*z)
    if mag < 1e-12:
        return (0.0, 0.0, 1.0)
    im = 1.0 / mag
    return (x*im, y*im, z*im)

def _dot(a, b):
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]

def _cross(a, b):
    return (
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0],
    )

def _sub(a, b):
    return (a[0]-b[0], a[1]-b[1], a[2]-b[2])

def _add(a, b):
    return (a[0]+b[0], a[1]+b[1], a[2]+b[2])

def _scale(v, s):
    return (v[0]*s, v[1]*s, v[2]*s)

def _neg(v):
    return (-v[0], -v[1], -v[2])

def _lerp(a, b, t):
    return a + (b - a) * t

def _lerp3(a, b, t):
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )

def _clamp(x, lo, hi):
    return lo if x < lo else (hi if x > hi else x)

def _reflect(l, n):
    """2*(L.N)*N - L"""
    d = _dot(l, n)
    return (2.0*d*n[0] - l[0], 2.0*d*n[1] - l[1], 2.0*d*n[2] - l[2])

def _mat3_mul_vec(m, v):
    """Row-major 3×3 matrix times a 3-vector."""
    return (
        m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]*v[2],
        m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]*v[2],
        m[2][0]*v[0] + m[2][1]*v[1] + m[2][2]*v[2],
    )

LIGHT_DIR = _norm((1.0, 2.0, 1.5))

# ---------------------------------------------------------------------------
# World Generation
# ---------------------------------------------------------------------------

def build_world(grid: np.ndarray) -> None:
    """Sine/cosine heightmap terrain with a raised glowing cluster at centre."""
    WS = WORLD_SIZE
    for x in range(WS):
        for z in range(WS):
            h = 1 + int(2 * (math.sin(x * 0.4) + math.cos(z * 0.35) + 2))
            h = max(1, min(h, 6))
            grid[x, 0, z] = BLOCK_STONE
            for y in range(1, h + 1):
                grid[x, y, z] = BLOCK_GRASS

    # 4×5×4 glowing cluster, 3 voxels above the terrain peak
    GLOW_W, GLOW_H, GLOW_D = 4, 5, 4
    cx = WORLD_SIZE // 2 - GLOW_W // 2
    cz = WORLD_SIZE // 2 - GLOW_D // 2
    base_h = 0
    for dx2 in range(GLOW_W):
        for dz2 in range(GLOW_D):
            for y in range(WORLD_SIZE - 1, -1, -1):
                if grid[cx + dx2, y, cz + dz2] != BLOCK_AIR:
                    if y + 1 > base_h:
                        base_h = y + 1
                    break
    gy = base_h + 3
    for dx2 in range(GLOW_W):
        for dz2 in range(GLOW_D):
            for dy2 in range(GLOW_H):
                if gy + dy2 < WORLD_SIZE:
                    grid[cx + dx2, gy + dy2, cz + dz2] = BLOCK_GLOWING

# ---------------------------------------------------------------------------
# SVO Builder
# ---------------------------------------------------------------------------

def _set_child_state(node: SVONode, child_idx: int, state: int, blk: int) -> None:
    shift = child_idx * 2
    node.bitmask &= ~(0b11 << shift)
    node.bitmask |= (state << shift)
    node.block_id[child_idx] = blk

def _get_child_state(node: SVONode, child_idx: int) -> int:
    return (node.bitmask >> (child_idx * 2)) & 0b11

def build_svo(grid: np.ndarray) -> List[SVONode]:
    """Top-down recursive SVO build. Returns node list, index 0 = root."""
    nodes: List[SVONode] = []

    def alloc() -> int:
        idx = len(nodes)
        nodes.append(SVONode())
        return idx

    def build(nidx: int, depth: int, ox: int, oy: int, oz: int, size: int) -> None:
        half = size // 2
        for cz in range(2):
            for cy in range(2):
                for cx in range(2):
                    cidx = cx | (cy << 1) | (cz << 2)
                    bx = ox + cx * half
                    by = oy + cy * half
                    bz = oz + cz * half
                    x1 = min(bx + half, WORLD_SIZE)
                    y1 = min(by + half, WORLD_SIZE)
                    z1 = min(bz + half, WORLD_SIZE)

                    if bx >= WORLD_SIZE or by >= WORLD_SIZE or bz >= WORLD_SIZE:
                        _set_child_state(nodes[nidx], cidx, STATE_EMPTY, BLOCK_AIR)
                        continue

                    sub = grid[bx:x1, by:y1, bz:z1]

                    if sub.size == 0 or np.all(sub == BLOCK_AIR):
                        _set_child_state(nodes[nidx], cidx, STATE_EMPTY, BLOCK_AIR)
                    elif (depth + 1) == MAX_DEPTH:
                        # at max depth, any non-air sub-voxel becomes a solid leaf
                        dominant = int(sub.flat[0]) if sub.flat[0] != BLOCK_AIR else BLOCK_STONE
                        _set_child_state(nodes[nidx], cidx, STATE_SOLID, dominant)
                    elif np.all(sub == sub.flat[0]) and sub.flat[0] != BLOCK_AIR:
                        dominant = int(sub.flat[0])
                        _set_child_state(nodes[nidx], cidx, STATE_SOLID, dominant)
                    else:
                        _set_child_state(nodes[nidx], cidx, STATE_MIXED, BLOCK_AIR)
                        child_nidx = alloc()
                        nodes[nidx].children[cidx] = child_nidx
                        build(child_nidx, depth + 1, bx, by, bz, half)

    root = alloc()
    build(root, 0, 0, 0, 0, WORLD_SIZE)
    return nodes

# ---------------------------------------------------------------------------
# Camera helpers
# ---------------------------------------------------------------------------

def make_look_at(eye, target, up):
    """Row-major 3×3 rotation [right, up, forward]."""
    forward = _norm(_sub(target, eye))
    right   = _norm(_cross(forward, up))
    up_     = _cross(right, forward)   # re-orthogonalised
    return [right, up_, forward]

def make_orbit_camera(frame_idx: int, radius: float, height: float):
    """Eye position and rotation for one frame of the orbit animation."""
    angle = frame_idx * (2.0 * math.pi / NUM_FRAMES)
    cx = WORLD_SIZE / 2.0 + math.sin(angle) * radius
    cz = WORLD_SIZE / 2.0 + math.cos(angle) * radius
    eye    = (cx, float(height), cz)
    target = (WORLD_SIZE / 2.0, 4.0, WORLD_SIZE / 2.0)
    rot    = make_look_at(eye, target, (0.0, 1.0, 0.0))
    return eye, rot

# ---------------------------------------------------------------------------
# Dynamic LUT Update
# ---------------------------------------------------------------------------

def update_color_lut(frame_idx: int) -> None:
    """Pulse the glowing block colour once per frame."""
    pulse = 0.5 + 0.5 * math.sin(frame_idx * 2.0 * math.pi / NUM_FRAMES)
    r = int(200 + 55 * pulse)
    g = int(80  * pulse)
    b = int(30  + 50 * (1.0 - pulse))
    color_lut[BLOCK_GLOWING] = [r, g, b]

# ---------------------------------------------------------------------------
# SVO Traversal
# ---------------------------------------------------------------------------

def svo_traverse(
    ray_ox: float, ray_oy: float, ray_oz: float,
    ray_dx: float, ray_dy: float, ray_dz: float,
    svo_nodes: List[SVONode],
    shadow_mode: bool = False
):
    """Fixed-depth LIFO-stack DDA traversal. No division, recursion, or dynamic allocation.

    Returns (t, hit_pos, face_axis, face_sign, block_id) on hit,
            True on shadow-mode hit, or None on miss.
    """
    WS = float(WORLD_SIZE)

    # Pre-compute reciprocals; no division inside the traversal loop
    inv_dx = 1.0 / (ray_dx if abs(ray_dx) > 1e-9 else 1e-9)
    inv_dy = 1.0 / (ray_dy if abs(ray_dy) > 1e-9 else 1e-9)
    inv_dz = 1.0 / (ray_dz if abs(ray_dz) > 1e-9 else 1e-9)

    # Sign bits for child octant selection
    sign_x = 1 if ray_dx >= 0.0 else 0
    sign_y = 1 if ray_dy >= 0.0 else 0
    sign_z = 1 if ray_dz >= 0.0 else 0

    # Root AABB slab test
    if sign_x:
        tx_enter = (0.0  - ray_ox) * inv_dx
        tx_exit  = (WS   - ray_ox) * inv_dx
    else:
        tx_enter = (WS   - ray_ox) * inv_dx
        tx_exit  = (0.0  - ray_ox) * inv_dx

    if sign_y:
        ty_enter = (0.0  - ray_oy) * inv_dy
        ty_exit  = (WS   - ray_oy) * inv_dy
    else:
        ty_enter = (WS   - ray_oy) * inv_dy
        ty_exit  = (0.0  - ray_oy) * inv_dy

    if sign_z:
        tz_enter = (0.0  - ray_oz) * inv_dz
        tz_exit  = (WS   - ray_oz) * inv_dz
    else:
        tz_enter = (WS   - ray_oz) * inv_dz
        tz_exit  = (0.0  - ray_oz) * inv_dz

    # t_enter = max of slab entries, t_exit = min of slab exits
    t_enter = max(tx_enter, ty_enter, tz_enter, 0.0)
    t_exit  = min(tx_exit,  ty_exit,  tz_exit)

    if t_enter >= t_exit:
        return None

    # Entry face = the slab entered last
    if tx_enter >= ty_enter and tx_enter >= tz_enter:
        face_axis = 0
        face_sign = 1 if ray_dx < 0.0 else -1
    elif ty_enter >= tz_enter:
        face_axis = 1
        face_sign = 1 if ray_dy < 0.0 else -1
    else:
        face_axis = 2
        face_sign = 1 if ray_dz < 0.0 else -1

    # Entry point, nudged into the first child
    hx = ray_ox + ray_dx * (t_enter + 1e-7)
    hy = ray_oy + ray_dy * (t_enter + 1e-7)
    hz = ray_oz + ray_dz * (t_enter + 1e-7)

    cx = 1 if hx >= WS * 0.5 else 0
    cy = 1 if hy >= WS * 0.5 else 0
    cz = 1 if hz >= WS * 0.5 else 0

    # Root mid-plane t values; INF if already behind us
    tx_mid = (WS * 0.5 - ray_ox) * inv_dx
    ty_mid = (WS * 0.5 - ray_oy) * inv_dy
    tz_mid = (WS * 0.5 - ray_oz) * inv_dz

    tx0 = tx_mid if tx_mid > t_enter + 1e-9 else INF
    ty0 = ty_mid if ty_mid > t_enter + 1e-9 else INF
    tz0 = tz_mid if tz_mid > t_enter + 1e-9 else INF

    # Fixed-depth traversal stack — one slot per register file entry in hardware
    stk_node       = [0]   * STACK_DEPTH
    stk_scale      = [0.0] * STACK_DEPTH
    stk_ox         = [0.0] * STACK_DEPTH
    stk_oy         = [0.0] * STACK_DEPTH
    stk_oz         = [0.0] * STACK_DEPTH
    stk_cx         = [0]   * STACK_DEPTH
    stk_cy         = [0]   * STACK_DEPTH
    stk_cz         = [0]   * STACK_DEPTH
    stk_tx         = [0.0] * STACK_DEPTH
    stk_ty         = [0.0] * STACK_DEPTH
    stk_tz         = [0.0] * STACK_DEPTH
    stk_t_now      = [0.0] * STACK_DEPTH
    stk_t_exit     = [0.0] * STACK_DEPTH
    stk_face_axis  = [0]   * STACK_DEPTH
    stk_face_sign  = [0]   * STACK_DEPTH

    # Push root
    stk_node[0]      = 0
    stk_scale[0]     = WS
    stk_ox[0]        = 0.0
    stk_oy[0]        = 0.0
    stk_oz[0]        = 0.0
    stk_cx[0]        = cx
    stk_cy[0]        = cy
    stk_cz[0]        = cz
    stk_tx[0]        = tx0
    stk_ty[0]        = ty0
    stk_tz[0]        = tz0
    stk_t_now[0]     = t_enter
    stk_t_exit[0]    = t_exit
    stk_face_axis[0] = face_axis
    stk_face_sign[0] = face_sign
    stk_ptr = 1

    while stk_ptr > 0:

        stk_ptr -= 1

        node_idx    = stk_node[stk_ptr]
        scale       = stk_scale[stk_ptr]
        ox          = stk_ox[stk_ptr]
        oy          = stk_oy[stk_ptr]
        oz          = stk_oz[stk_ptr]
        cx          = stk_cx[stk_ptr]
        cy          = stk_cy[stk_ptr]
        cz          = stk_cz[stk_ptr]
        tx          = stk_tx[stk_ptr]
        ty          = stk_ty[stk_ptr]
        tz          = stk_tz[stk_ptr]
        t_now       = stk_t_now[stk_ptr]
        t_node_exit = stk_t_exit[stk_ptr]
        face_axis   = stk_face_axis[stk_ptr]
        face_sign   = stk_face_sign[stk_ptr]

        node = svo_nodes[node_idx]
        metrics.nodes_visited += 1

        half = scale * 0.5

        # Inner DDA loop — enumerate children front-to-back
        while t_now < t_node_exit:

            child_idx = cx | (cy << 1) | (cz << 2)

            t_child_exit = min(tx, ty, tz, t_node_exit)

            metrics.bitmask_checks += 1
            state = (node.bitmask >> (child_idx * 2)) & 0b11

            if state == STATE_SOLID:
                if shadow_mode:
                    return True
                hit_x = ray_ox + ray_dx * t_now
                hit_y = ray_oy + ray_dy * t_now
                hit_z = ray_oz + ray_dz * t_now
                return (t_now, (hit_x, hit_y, hit_z), face_axis, face_sign, node.block_id[child_idx])

            elif state == STATE_MIXED:
                # Push parent resume state, then descend

                # Advance parent DDA past the boundary we are crossing
                next_cx        = cx
                next_cy        = cy
                next_cz        = cz
                next_tx        = tx
                next_ty        = ty
                next_tz        = tz
                next_face_axis = face_axis
                next_face_sign = face_sign

                if abs(t_child_exit - tx) < 1e-9:
                    next_cx = 1 - cx
                    next_tx = INF
                    next_face_axis = 0
                    next_face_sign = 1 if ray_dx < 0.0 else -1
                elif abs(t_child_exit - ty) < 1e-9:
                    next_cy = 1 - cy
                    next_ty = INF
                    next_face_axis = 1
                    next_face_sign = 1 if ray_dy < 0.0 else -1
                else:
                    next_cz = 1 - cz
                    next_tz = INF
                    next_face_axis = 2
                    next_face_sign = 1 if ray_dz < 0.0 else -1

                if stk_ptr < STACK_DEPTH:
                    stk_node[stk_ptr]      = node_idx
                    stk_scale[stk_ptr]     = scale
                    stk_ox[stk_ptr]        = ox
                    stk_oy[stk_ptr]        = oy
                    stk_oz[stk_ptr]        = oz
                    stk_cx[stk_ptr]        = next_cx
                    stk_cy[stk_ptr]        = next_cy
                    stk_cz[stk_ptr]        = next_cz
                    stk_tx[stk_ptr]        = next_tx
                    stk_ty[stk_ptr]        = next_ty
                    stk_tz[stk_ptr]        = next_tz
                    stk_t_now[stk_ptr]     = t_child_exit
                    stk_t_exit[stk_ptr]    = t_node_exit
                    stk_face_axis[stk_ptr] = next_face_axis
                    stk_face_sign[stk_ptr] = next_face_sign
                    stk_ptr += 1

                child_node_idx = node.children[child_idx]

                child_ox = ox + cx * half
                child_oy = oy + cy * half
                child_oz = oz + cz * half

                child_half = half * 0.5

                # Child exit t via slab test with pre-computed reciprocals
                if sign_x:
                    child_t_exit_x = (child_ox + half - ray_ox) * inv_dx
                else:
                    child_t_exit_x = (child_ox - ray_ox) * inv_dx

                if sign_y:
                    child_t_exit_y = (child_oy + half - ray_oy) * inv_dy
                else:
                    child_t_exit_y = (child_oy - ray_oy) * inv_dy

                if sign_z:
                    child_t_exit_z = (child_oz + half - ray_oz) * inv_dz
                else:
                    child_t_exit_z = (child_oz - ray_oz) * inv_dz

                child_t_exit = min(child_t_exit_x, child_t_exit_y, child_t_exit_z)

                # Child mid-plane t values; INF if already behind us
                child_tx_mid = (child_ox + child_half - ray_ox) * inv_dx
                child_ty_mid = (child_oy + child_half - ray_oy) * inv_dy
                child_tz_mid = (child_oz + child_half - ray_oz) * inv_dz

                child_tx = child_tx_mid if child_tx_mid > t_now + 1e-9 else INF
                child_ty = child_ty_mid if child_ty_mid > t_now + 1e-9 else INF
                child_tz = child_tz_mid if child_tz_mid > t_now + 1e-9 else INF

                # Initial child-of-child selection from the nudged entry point
                ehx = ray_ox + ray_dx * (t_now + 1e-7)
                ehy = ray_oy + ray_dy * (t_now + 1e-7)
                ehz = ray_oz + ray_dz * (t_now + 1e-7)

                child_cx = 1 if ehx >= child_ox + child_half else 0
                child_cy = 1 if ehy >= child_oy + child_half else 0
                child_cz = 1 if ehz >= child_oz + child_half else 0

                if stk_ptr < STACK_DEPTH:
                    stk_node[stk_ptr]      = child_node_idx
                    stk_scale[stk_ptr]     = half
                    stk_ox[stk_ptr]        = child_ox
                    stk_oy[stk_ptr]        = child_oy
                    stk_oz[stk_ptr]        = child_oz
                    stk_cx[stk_ptr]        = child_cx
                    stk_cy[stk_ptr]        = child_cy
                    stk_cz[stk_ptr]        = child_cz
                    stk_tx[stk_ptr]        = child_tx
                    stk_ty[stk_ptr]        = child_ty
                    stk_tz[stk_ptr]        = child_tz
                    stk_t_now[stk_ptr]     = t_now
                    stk_t_exit[stk_ptr]    = child_t_exit
                    stk_face_axis[stk_ptr] = face_axis
                    stk_face_sign[stk_ptr] = face_sign
                    stk_ptr += 1

                break

            # EMPTY — advance DDA to next child
            t_now = t_child_exit

            if t_now >= t_node_exit:
                break

            # Determine which boundary was crossed and flip the child bit
            if abs(t_child_exit - tx) < 1e-9:
                cx = 1 - cx
                tx = INF
                face_axis = 0
                face_sign = 1 if ray_dx < 0.0 else -1
            elif abs(t_child_exit - ty) < 1e-9:
                cy = 1 - cy
                ty = INF
                face_axis = 1
                face_sign = 1 if ray_dy < 0.0 else -1
            else:
                cz = 1 - cz
                tz = INF
                face_axis = 2
                face_sign = 1 if ray_dz < 0.0 else -1

            if cx < 0 or cx > 1 or cy < 0 or cy > 1 or cz < 0 or cz > 1:
                break

    return None  # stack exhausted — ray miss

# ---------------------------------------------------------------------------
# Shading
# ---------------------------------------------------------------------------

def shade_hit(t, hit_pos, face_axis, face_sign, block_id, ray_d, svo_nodes):
    """Hemisphere + Lambert + Phong specular + shadow + fog."""
    hx, hy, hz = hit_pos

    normal = [0.0, 0.0, 0.0]
    normal[face_axis] = float(face_sign)

    hemi_t     = (normal[1] + 1.0) * 0.5
    hemi_color = _lerp3(GROUND_COLOR, SKY_COLOR, hemi_t)

    # World-space XOR checkerboard texture
    ix = int(math.floor(hx))
    iy = int(math.floor(hy))
    iz = int(math.floor(hz))
    pattern = (ix ^ iy ^ iz) & 1
    base    = color_lut[block_id]
    scale_p = 0.75 + 0.25 * pattern
    tex     = [base[c] * scale_p for c in range(3)]

    # Shadow ray: bias origin along normal to avoid self-intersection
    bias_pos = (
        hx + normal[0] * SHADOW_BIAS,
        hy + normal[1] * SHADOW_BIAS,
        hz + normal[2] * SHADOW_BIAS,
    )
    shadow_hit = svo_traverse(
        bias_pos[0], bias_pos[1], bias_pos[2],
        LIGHT_DIR[0], LIGHT_DIR[1], LIGHT_DIR[2],
        svo_nodes, shadow_mode=True
    )
    metrics.shadow_rays += 1
    shadow_mult = 0.3 if shadow_hit else 1.0

    diff = max(0.0, _dot(normal, LIGHT_DIR))

    # Phong specular ^32 via repeated squarings
    refl = _norm(_reflect(LIGHT_DIR, tuple(normal)))
    view = _norm(_neg(ray_d))
    s    = max(0.0, _dot(refl, view))
    s = s*s; s = s*s; s = s*s; s = s*s; s = s*s
    spec = s * 60.0

    lit = [
        (hemi_color[c] * 0.45 + tex[c] * 0.55 + diff * 20.0) * shadow_mult + spec
        for c in range(3)
    ]

    fog_t = _clamp((t - FOG_START) / (MAX_T - FOG_START), 0.0, 1.0)
    final = [_lerp(lit[c], FOG_COLOR[c], fog_t) for c in range(3)]

    return tuple(int(_clamp(final[c], 0.0, 255.0)) for c in range(3))


def shade_miss(ray_d):
    """Sky gradient based on ray Y component."""
    sky_t  = max(0.0, ray_d[1])
    miss_c = _lerp3(
        (SKY_COLOR[0]*0.7, SKY_COLOR[1]*0.7, SKY_COLOR[2]*0.7),
        SKY_COLOR,
        sky_t
    )
    return tuple(int(_clamp(c, 0.0, 255.0)) for c in miss_c)

# ---------------------------------------------------------------------------
# Primary Ray Casting
# ---------------------------------------------------------------------------

def cast_primary_ray(px: int, py: int, eye, rot_mat, svo_nodes: List[SVONode]):
    """Generate and trace the primary ray for pixel (px, py)."""
    aspect = IMG_W / IMG_H
    tan_half_fov = math.tan(math.radians(FOV_DEG) * 0.5)

    # NDC pixel centre (Y flipped to screen space)
    u = (px + 0.5) / IMG_W * 2.0 - 1.0
    v = 1.0 - (py + 0.5) / IMG_H * 2.0

    # rot_mat rows = [right, up, forward]
    cam_right   = rot_mat[0]
    cam_up      = rot_mat[1]
    cam_forward = rot_mat[2]

    ray_d = _norm((
        cam_forward[0] + cam_right[0] * u * aspect * tan_half_fov + cam_up[0] * v * tan_half_fov,
        cam_forward[1] + cam_right[1] * u * aspect * tan_half_fov + cam_up[1] * v * tan_half_fov,
        cam_forward[2] + cam_right[2] * u * aspect * tan_half_fov + cam_up[2] * v * tan_half_fov,
    ))

    ray_o = eye

    metrics.primary_rays += 1

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
# Output helpers
# ---------------------------------------------------------------------------

def write_ppm(path: str, pixels: np.ndarray, width: int, height: int) -> None:
    """Write ASCII PPM (P3)."""
    with open(path, 'w') as f:
        f.write(f"P3\n{width} {height}\n255\n")
        flat = pixels.astype(np.uint8).reshape(-1, 3)
        for r, g, b in flat:
            f.write(f"{r} {g} {b}\n")

def stitch_gif(frame_dir: str, out_path: str, fps: int = 10) -> None:
    """Stitch PPM frames into an animated GIF (requires Pillow)."""
    try:
        from PIL import Image   # soft dependency
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

def print_metrics(total_frames: int, metrics_path: str = None) -> None:
    """Print traversal metrics; optionally write to file."""
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
    print(report)

    if metrics_path:
        with open(metrics_path, 'w') as f:
            f.write(report + "\n")
        print(f"  Metrics saved → {metrics_path}")

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    sys.setrecursionlimit(10000)   # needed for the recursive SVO build

    base_dir    = os.path.dirname(os.path.abspath(__file__))
    frame_dir   = os.path.join(base_dir, "frames")
    out_gif     = os.path.join(base_dir, "output_svo.gif")
    metrics_txt = os.path.join(base_dir, "hardware_metrics.txt")
    os.makedirs(frame_dir, exist_ok=True)

    print("Building voxel world...")
    voxel_grid = np.zeros((WORLD_SIZE, WORLD_SIZE, WORLD_SIZE), dtype=np.uint8)
    build_world(voxel_grid)
    print(f"  World built. Non-air voxels: {np.sum(voxel_grid != BLOCK_AIR)}")

    print("Building SVO...")
    svo_nodes = build_svo(voxel_grid)
    print(f"  SVO built. Total nodes: {len(svo_nodes)}")
    print(f"  Root bitmask: 0b{svo_nodes[0].bitmask:016b}")

    global metrics
    metrics = Metrics()

    for frame_idx in range(NUM_FRAMES):
        update_color_lut(frame_idx)

        eye, rot_mat = make_orbit_camera(frame_idx, ORBIT_RADIUS, ORBIT_HEIGHT)

        pixels = np.zeros((IMG_H, IMG_W, 3), dtype=np.uint8)

        for py in range(IMG_H):
            for px in range(IMG_W):
                pixels[py, px] = cast_primary_ray(px, py, eye, rot_mat, svo_nodes)

        frame_path = os.path.join(frame_dir, f"frame_{frame_idx:03d}.ppm")
        write_ppm(frame_path, pixels, IMG_W, IMG_H)

        print(f"Frame {frame_idx + 1}/{NUM_FRAMES} complete — {frame_path}")

    stitch_gif(os.path.join(frame_dir, "*.ppm"), out_gif, fps=10)
    print_metrics(NUM_FRAMES, metrics_path=metrics_txt)


if __name__ == "__main__":
    main()
