import os
import numpy as np
import pytest
import vox_loader

VOX = os.path.join(os.path.dirname(__file__), "world.vox")


# ---- .vox parsing ----

def test_parse_world_vox_dims_and_count():
    vox = vox_loader.parse_vox(VOX)
    assert vox.size == (64, 64, 64)
    assert len(vox.voxels) == 49960          # (x,y,z,colorIndex) tuples
    assert len(vox.palette) == 256            # RGBA list, palette[i] is index i+1's colour


def test_palette_lookup_matches_known_indices():
    vox = vox_loader.parse_vox(VOX)
    # colorIndex i -> palette[i-1]; spot-check the lava-orange and water-cyan
    assert vox.rgb(24) == (255, 102, 0)       # lava orange
    assert vox.rgb(181) == (0, 255, 255)      # water cyan


# ---- colour extraction + block_id remap ----

def test_used_colours_remap():
    vox = vox_loader.parse_vox(VOX)
    remap = vox_loader.build_colour_remap(vox)     # {colorIndex: block_id}
    used = sorted(remap.keys())
    assert used == [4, 24, 60, 95, 167, 181, 199, 228, 231, 246, 251, 252, 253]
    # block_ids are 1..N, contiguous, in ascending colour-index order
    assert [remap[c] for c in used] == list(range(1, len(used) + 1))
    assert max(remap.values()) <= 15


def test_too_many_colours_errors():
    fake = vox_loader.Vox(size=(64, 64, 64),
                          voxels=[(i, 0, 0, i + 1) for i in range(16)],  # 16 distinct
                          palette=[(0, 0, 0, 255)] * 256)
    with pytest.raises(vox_loader.TooManyColoursError):
        vox_loader.build_colour_remap(fake)


# ---- material designation ----

def test_material_flags_default_rules():
    vox = vox_loader.parse_vox(VOX)
    remap = vox_loader.build_colour_remap(vox)
    flags = vox_loader.build_material_flags(vox, remap)
    assert flags[remap[24]] == vox_loader.MAT_LAVA    # orange (255,102,0)
    assert flags[remap[181]] == vox_loader.MAT_WATER   # cyan (0,255,255)
    assert flags[remap[199]] == vox_loader.MAT_WATER   # blue (0,102,255)
    assert flags[remap[4]] == vox_loader.MAT_STATIC    # pale yellow = sand, not glow
    assert flags[remap[251]] == vox_loader.MAT_STATIC


# ---- load_world() -> grid + LUT words ----

def test_load_world_grid_and_lut():
    grid, lut_words = vox_loader.load_world(VOX)
    assert grid.shape == (64, 64, 64) and grid.dtype == np.uint8
    assert grid.max() <= 15 and grid.min() == 0
    assert len(lut_words) == 16
    assert lut_words[0] == 0                          # air slot
    # every used block_id has a non-zero RGB and flags packed in the top byte
    nonzero = [w for w in lut_words[1:] if w != 0]
    assert len(nonzero) == 13
    flags = {(w >> 24) & 0xFF for w in lut_words}  # material flags in [31:24]
    assert vox_loader.MAT_WATER in flags and vox_loader.MAT_LAVA in flags


def test_load_world_fits_node_budget():
    grid, _ = vox_loader.load_world(VOX)
    import svo_builder
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
    assert len(nodes) <= 4096


# ---- smaller-world embedding ----

def _mk_vox(size, voxels):
    pal = [(0, 0, 0, 255)] * 256
    pal[6] = (10, 20, 30, 255)   # colorIndex 7 → palette[6]
    return vox_loader.Vox(size=size, voxels=voxels, palette=pal)

def test_embed_small_world_centred_and_floor_aligned():
    vox = _mk_vox((16, 16, 16), [(0, 0, 0, 7)])
    remap = vox_loader.build_colour_remap(vox)
    grid = vox_loader.embed_grid(vox, remap)
    assert grid.shape == (64, 64, 64)
    off = (64 - 16) // 2   # X/Z centring offset = 24
    assert grid[off, 0, off] == remap[7]   # Y floor-aligned at 0
    assert int(grid.sum() > 0) == 1 and int((grid != 0).sum()) == 1

def test_embed_64_world_unchanged():
    # 64^3 model: offset = 0, grid coords unchanged
    vox = _mk_vox((64, 64, 64), [(1, 2, 3, 7)])
    remap = vox_loader.build_colour_remap(vox)
    grid = vox_loader.embed_grid(vox, remap)
    assert grid[1, 3, 2] == remap[7]   # (vx,vy,vz)->[vx, vz, vy]

def test_world_larger_than_64_errors():
    vox = _mk_vox((96, 16, 16), [(0, 0, 0, 7)])
    remap = vox_loader.build_colour_remap(vox)
    with pytest.raises(ValueError):
        vox_loader.embed_grid(vox, remap)


# ---- depth-cap representative block ----

def test_dom_block_serialised_in_word7():
    import svo_builder
    grid, _ = vox_loader.load_world(VOX)
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
    words = svo_builder.serialise_nodes(nodes)
    assert len(words) == len(nodes) * 8
    w7 = [words[k * 8 + 7] for k in range(len(nodes))]
    assert all(v != 0 for v in w7), "some node has dom_block=0"
    assert len(set(w7)) > 3, "dom_block should span multiple terrain colours"
