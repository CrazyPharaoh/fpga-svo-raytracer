import os
import numpy as np
import pytest
import vox_loader

VOX = os.path.join(os.path.dirname(__file__), "world.vox")


# ---- Task 1: parse the .vox container ----

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


# ---- Task 2: used-colour extraction + remap to block_ids ----

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


# ---- Task 3: material designation by palette colour ----

def test_material_flags_default_rules():
    vox = vox_loader.parse_vox(VOX)
    remap = vox_loader.build_colour_remap(vox)
    flags = vox_loader.build_material_flags(vox, remap)
    # idx24 orange -> lava(2); idx181 cyan & idx199 blue -> water(1)
    assert flags[remap[24]] == vox_loader.MAT_LAVA
    assert flags[remap[181]] == vox_loader.MAT_WATER
    assert flags[remap[199]] == vox_loader.MAT_WATER
    # idx4 (255,255,102) is SAND -> static (not glow); a terrain grey is also static
    assert flags[remap[4]] == vox_loader.MAT_STATIC
    assert flags[remap[251]] == vox_loader.MAT_STATIC


# ---- Task 4: load_world() -> grid + LUT-words ----

def test_load_world_grid_and_lut():
    grid, lut_words = vox_loader.load_world(VOX)
    assert grid.shape == (64, 64, 64) and grid.dtype == np.uint8
    assert grid.max() <= 15 and grid.min() == 0
    assert len(lut_words) == 16
    assert lut_words[0] == 0                          # air slot
    # every used block_id has a non-zero RGB and flags packed in the top byte
    nonzero = [w for w in lut_words[1:] if w != 0]
    assert len(nonzero) == 13
    # at least one lava (flag 2) and one water (flag 1) packed in [31:24]
    flags = {(w >> 24) & 0xFF for w in lut_words}
    assert vox_loader.MAT_WATER in flags and vox_loader.MAT_LAVA in flags


def test_load_world_fits_node_budget():
    # load_world raises NodeBudgetError if build_svo exceeds 4096 nodes
    grid, _ = vox_loader.load_world(VOX)   # world.vox is known to fit
    import svo_builder
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
    assert len(nodes) <= 4096


# ---- smaller-world embedding (no rebuild; hardware stays 64^3) ----

def _mk_vox(size, voxels):
    pal = [(0, 0, 0, 255)] * 256
    pal[6] = (10, 20, 30, 255)   # colourIndex 7 -> palette[6]
    return vox_loader.Vox(size=size, voxels=voxels, palette=pal)

def test_embed_small_world_centred_and_floor_aligned():
    # a single voxel at MagicaVoxel origin (0,0,0) in a 16^3 model
    vox = _mk_vox((16, 16, 16), [(0, 0, 0, 7)])
    remap = vox_loader.build_colour_remap(vox)
    grid = vox_loader.embed_grid(vox, remap)
    assert grid.shape == (64, 64, 64)
    off = (64 - 16) // 2   # 24
    # X,Z centred by `off`; Y (height) floor-aligned at 0
    assert grid[off, 0, off] == remap[7]
    assert int(grid.sum() > 0) == 1 and int((grid != 0).sum()) == 1

def test_embed_64_world_unchanged():
    # a 64^3 model must still land at the origin (offset 0) — backward compatible
    vox = _mk_vox((64, 64, 64), [(1, 2, 3, 7)])
    remap = vox_loader.build_colour_remap(vox)
    grid = vox_loader.embed_grid(vox, remap)
    assert grid[1, 3, 2] == remap[7]   # (vx,vy,vz)->[vx, vz, vy]

def test_world_larger_than_64_errors():
    vox = _mk_vox((96, 16, 16), [(0, 0, 0, 7)])
    remap = vox_loader.build_colour_remap(vox)
    with pytest.raises(ValueError):
        vox_loader.embed_grid(vox, remap)


# ---- depth-cap representative block (word 7) ----

def test_dom_block_serialised_in_word7():
    import svo_builder
    grid, _ = vox_loader.load_world(VOX)
    nodes = svo_builder.flatten_svo(svo_builder.build_svo(grid))
    words = svo_builder.serialise_nodes(nodes)
    assert len(words) == len(nodes) * 8
    # word 7 of every node must now carry a REAL block (1..15), never 0 or the
    # plain block_id-1 fallback for the whole tree (that was the all-yellow bug).
    w7 = [words[k * 8 + 7] for k in range(len(nodes))]
    assert all(v != 0 for v in w7), "some node has dom_block=0 (would fall back to yellow)"
    assert len(set(w7)) > 3, "dom_block should span multiple terrain colours, not all one"
