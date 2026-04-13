# DDA and Hierarchical DDA Ray Traversal

## What problem are we solving?

A ray tracer fires a ray from a camera position through each pixel on screen and asks: *which voxel (grid cell) does this ray hit first, and where?*

The brute-force approach — check every voxel in the world — is far too slow. We need an algorithm that only checks voxels the ray actually passes through, in order, and stops as soon as it hits a solid one. That is exactly what the **DDA (Digital Differential Analyser)** algorithm does.

---

## Part 1 — The Flat DDA (`dda_raytracer.py`)

### Core idea

Imagine the world as a 3D grid of cubes. A ray travels through this grid, crossing vertical (YZ), horizontal (XZ), or depth (XY) planes each time it moves to a new cell. The DDA algorithm always steps to the *next* cell boundary — whichever axis has the closest one — and checks the new cell.

### The mathematics

A ray is defined as:

```
P(t) = origin + t * direction
```

where `t` is a scalar distance along the ray and `P` is a 3D point.

#### Step direction

For each axis `i`, we work out which direction the ray is travelling:

```
step[i] = +1   if direction[i] >= 0
step[i] = -1   if direction[i] <  0
```

#### delta_dist — how far along the ray between grid-line crossings

If the ray direction along axis `i` is `d`, then the spacing between consecutive grid lines on that axis (all 1 unit apart) represents a travel of `1/|d|` in `t`:

```
delta_dist[i] = |1 / direction[i]|
```

This is the key quantity: it tells you how much `t` increases each time the ray crosses a boundary on axis `i`.

*Special case*: if `direction[i] == 0` the ray never crosses that axis's planes, so we set `delta_dist[i] = ∞` (a large number).

#### side_dist — distance to the *first* crossing on each axis

At the start, the ray sits somewhere inside its starting cell. We compute `t` to the nearest boundary on each axis:

```
# Ray going in positive direction (step = +1):
side_dist[i] = (floor(origin[i]) + 1.0 - origin[i]) * delta_dist[i]

# Ray going in negative direction (step = -1):
side_dist[i] = (origin[i] - floor(origin[i])) * delta_dist[i]
```

This gives the `t` value at which the ray first exits the starting cell on each axis.

#### The loop

Each iteration:

1. Find `axis = argmin(side_dist)` — the axis with the nearest boundary.
2. Advance: `side_dist[axis] += delta_dist[axis]` (prepare for the *next* crossing of that axis).
3. Advance: `map_pos[axis] += step[axis]` (we are now in the adjacent cell).
4. Check if the new `map_pos` is out of bounds → return miss.
5. Read `world[map_pos]` → if solid, return a hit.

```
side_dist before step:   [2.3, 0.8, 1.5]
                                ^^^  smallest → step along Y

side_dist after step:    [2.3, 0.8+delta_y, 1.5]
map_pos[Y] += step[Y]
```

#### Computing the hit point and surface normal

Once we step into a solid voxel, the ray crossed the face on `axis` just before this step. The `t` value of that crossing is:

```
t = side_dist[axis] - delta_dist[axis]   # undo the last increment
hit_point = origin + t * direction
```

The surface normal is simply the axis we stepped along, pointing back toward where we came from:

```
normal[axis] = -step[axis]    # all other components are 0
```

#### Lighting

Once we have a hit point and normal, we compute simple diffuse (Lambertian) lighting:

```
light_dir = normalize(light_pos - hit_point)
intensity  = max(0, dot(normal, light_dir))
colour     = block_colour * intensity
```

`dot(normal, light_dir)` measures how directly the light strikes the surface (1 = head-on, 0 = grazing, negative = back-lit → clamped to 0).

---

## Part 2 — Hierarchical DDA (`hierarchical_dda_raytracer.py`)

### The motivation

In the flat DDA, every single voxel the ray passes through is checked — even large stretches of empty space. In a sparse world (mostly empty), the ray wastes many steps just traversing air.

The Hierarchical DDA solves this by using **two levels of grid**:

| Level | Grid size | Cell covers |
|---|---|---|
| Macro | 4 × 4 × 4 | 8 × 8 × 8 voxels each (an 8³ block) |
| Micro | 8 × 8 × 8 | 1 voxel each (the actual content) |

The world is 32 × 32 × 32 voxels (`MACRO_SIZE × MICRO_SIZE = 4 × 8`).

The ray first traverses the coarse macro grid, skipping entire 8³ blocks that contain no geometry. Only when it enters an *occupied* macro cell does it drop down and traverse voxel-by-voxel inside that cell.

### The bitmask

Before rendering, we precompute a 64-bit integer where each bit represents one macro cell:

```
bit_index = mx * 16 + my * 4 + mz
```

Bit = 1 means "at least one solid voxel exists somewhere in this 8³ block."  
Bit = 0 means "entirely empty — skip it."

Checking occupancy is then a single bitwise operation:

```python
if (bitmask >> bit_index) & 1:   # occupied
```

On hardware (e.g. an FPGA), this is a single clock-cycle shift and AND — extremely fast.

### The two-level traversal

#### Level 1 — Macro DDA

Identical maths to the flat DDA, but the grid spacing is `MICRO_SIZE = 8` world units rather than 1. So `delta_dist_macro[i] = |1/direction[i]| × MICRO_SIZE`.

The macro DDA steps through 8³ blocks:
- Empty block (bitmask bit = 0) → advance to next block immediately.
- Occupied block → enter micro DDA.

#### Level 2 — Micro DDA (inside an occupied macro cell)

When the macro DDA enters an occupied block, we need to find the ray's *entry point* into that block. We use a **slab test**:

For each axis, compute the `t` at which the ray enters the block face:

```
# Positive direction:
t_slab[i] = (cell_min[i] - origin[i]) * inv_direction[i]

# Negative direction:
t_slab[i] = (cell_max[i] - origin[i]) * inv_direction[i]
```

The actual entry `t` is `max(t_slab[x], t_slab[y], t_slab[z])` — the last axis the ray enters (all three slabs must overlap for the ray to be inside). The axis that gives this maximum is the **entry face** (`entry_axis`).

We step back slightly along the ray (`t_enter - 1e-4`) to avoid floating point landing exactly on the boundary, then clamp the resulting entry point to the macro cell bounds. This gives `micro_origin` — the starting point for the micro DDA.

The micro DDA then runs exactly like a flat DDA, but confined to the 8×8×8 region of the macro cell:

1. Initialise `micro_pos`, `side_dist_micro`, `step_micro` from `micro_origin` (same maths as flat DDA).
2. Each iteration: check occupancy of current voxel → if solid, return hit. Otherwise advance to next voxel.
3. Exit when we leave the macro cell bounds.

### The normal bug and its fix

The flat DDA computes the normal **after** stepping (advance-then-check), so `axis` is always the face we just crossed:

```python
side_dist[axis] += delta_dist[axis]   # step
map_pos[axis]   += step[axis]
# ... check occupancy ...
normal[axis] = -step[axis]            # correct: this is the face we crossed
```

The HDDA micro loop uses **check-then-advance** ordering. When a hit is found, `side_dist_micro` has NOT yet been updated for this step. But after any previous advance, `side_dist_micro[last_axis]` was incremented (making it large), so `min(side_dist_micro)` returns a *different* axis — not the one we entered through. This gives a completely wrong normal and therefore wrong lighting.

**Fix**: track `last_axis` — the axis used in the most recent advance — and use it when a hit is found. Initialise it from `entry_axis` (determined by the slab test) so the first voxel in the cell (checked before any advance) also gets a correct normal.

```python
last_axis = entry_axis          # initialised from the macro-cell slab test

while True:
    if world[...] > 0:
        normal[last_axis] = -step_micro[last_axis]   # correct face
        t = max(0.0, side_dist_micro[last_axis] - delta_dist_micro[last_axis])
        hit_point = micro_origin + t * direction
        return hit

    last_axis = argmin(side_dist_micro)  # record BEFORE incrementing
    side_dist_micro[last_axis] += delta_dist_micro[last_axis]
    micro_pos[last_axis]       += step_micro[last_axis]
```

---

## Summary: DDA vs HDDA

| | Flat DDA | Hierarchical DDA |
|---|---|---|
| Grid levels | 1 (voxel-by-voxel) | 2 (macro blocks + voxels) |
| Empty space | Stepped through one voxel at a time | Skipped an entire 8³ block per step |
| Occupancy check | World array lookup each step | Bitmask lookup (1 bit op) + array lookup only inside occupied block |
| Setup cost | None | Bitmask precomputation (`O(world_size³)`, done once) |
| Benefit | Simple, low overhead | Much fewer steps in sparse worlds |
| Memory | World array only | World array + 64-bit bitmask |
| Entry point calculation | Not needed | Slab test per occupied macro cell |

### When does HDDA win?

The more empty space in the scene, the larger the speedup. A ray crossing 10 empty macro blocks takes 10 macro steps (bitmask checks) instead of up to 80 micro steps (8 per block × 10 blocks). With a dense scene (every block occupied), HDDA adds overhead without benefit.

---

## Worked example — single ray step

Suppose:
- `origin = (8.5, 5.2, 3.1)`, `direction = (0.0, -0.6, 0.8)` (normalised)
- World is 1-unit voxels

**Setup:**
```
delta_dist = [inf, 1/0.6 = 1.667, 1/0.8 = 1.25]
map_pos    = [8,   5,              3            ]
step       = [0,  -1,             +1            ]

side_dist (negative Y): (5.2 - 5) * 1.667 = 0.333
side_dist (positive Z): (3 + 1 - 3.1) * 1.25 = 1.125
side_dist (zero X):     inf
```

**Iteration 1:** min is Y (0.333)
```
side_dist[Y] = 0.333 + 1.667 = 2.0
map_pos[Y]   = 5 - 1 = 4
t = 2.0 - 1.667 = 0.333
hit_point = (8.5, 5.2 + 0.333*(-0.6), 3.1 + 0.333*0.8) = (8.5, 5.0, 3.37)
normal = (0, +1, 0)   ← top face of voxel [8][4][3]
```

Check `world[8][4][3]` — if solid, return this hit. Otherwise continue.
