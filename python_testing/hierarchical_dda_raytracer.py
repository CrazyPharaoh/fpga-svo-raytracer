# hierarchical_dda_raytracer.py — early prototype: 2-level macro/micro DDA with op-count metrics
import math
import os
import time

light_pos = (31, 31, 5)
width = 640
height = 360
MACRO_SIZE = 4
MICRO_SIZE = 8
world_size = MACRO_SIZE * MICRO_SIZE  # 32

colour_list = [(0, 0, 0),       # Empty
               (255, 0, 0),     # Red
               (0, 255, 0),     # Green
               (0, 0, 255),     # Blue
               (255, 255, 255), # White
               (0, 0, 0),]      # Black

def normalize(v):
    length = math.sqrt((v[0]*v[0]) + (v[1]*v[1]) + (v[2]*v[2]))
    return (v[0]/length, v[1]/length, v[2]/length)

def floor(num):
    return math.floor(num)

def vectAbs(v):
    return math.sqrt((v[0]*v[0]) + (v[1]*v[1]) + (v[2]*v[2]))

def numAbs(num):
    if num < 0:
        return (num * -1)
    else:
        return num

def dot(v1, v2):
    return (v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2])

def scalarMult(x, v):
    return (v[0] * x, v[1] * x, v[2] * x)

def sub(v1, v2):
    return (v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2])

def add(v1, v2):
    return (v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2])

def generateWorld(size, default_val=0):
    print("generating world with size:", size)
    world = [[[default_val for z in range(size)] for y in range(size)] for x in range(size)]

    # Checkerboard floor
    for x in range(size):
        for z in range(size):
            if (x + z) % 2 == 0:
                world[x][0][z] = 4  # White
            else:
                world[x][0][z] = 5  # Black

    # Red cube (4x4x4) at roughly center
    for x in range(14, 18):
        for y in range(1, 10):
            for z in range(14, 18):
                world[x][y][z] = 1  # Red

    # Blue pillar
    for y in range(1, 14):
        world[8][y][8] = 3  # Blue

    return world

def buildMacroGridBitmask(world):
    """Build a 64-bit integer bitmask for macro-cell occupancy.
    Bit index = mx * 16 + my * 4 + mz
    A macro-cell is occupied if any voxel within its 8x8x8 region is non-zero.
    """
    bitmask = 0
    for mx in range(MACRO_SIZE):
        for my in range(MACRO_SIZE):
            for mz in range(MACRO_SIZE):
                occupied = False
                for lx in range(MICRO_SIZE):
                    if occupied:
                        break
                    for ly in range(MICRO_SIZE):
                        if occupied:
                            break
                        for lz in range(MICRO_SIZE):
                            wx = mx * MICRO_SIZE + lx
                            wy = my * MICRO_SIZE + ly
                            wz = mz * MICRO_SIZE + lz
                            if world[wx][wy][wz] != 0:
                                occupied = True
                                break
                if occupied:
                    bit_index = mx * 16 + my * 4 + mz
                    bitmask |= (1 << bit_index)
    return bitmask

def intersect_voxel_hierarchical(ray_origin, ray_direction, world, bitmask, metrics):
    """2-level hierarchical DDA: macro 4×4×4 grid then micro 8×8×8 per occupied cell."""

    # Reciprocals shared by both DDA levels
    metrics['divisions'] += 3
    inv_dx = 1e30 if ray_direction[0] == 0 else 1.0 / ray_direction[0]
    inv_dy = 1e30 if ray_direction[1] == 0 else 1.0 / ray_direction[1]
    inv_dz = 1e30 if ray_direction[2] == 0 else 1.0 / ray_direction[2]
    inv_dir = (inv_dx, inv_dy, inv_dz)

    delta_dist_macro = (abs(inv_dx) * MICRO_SIZE, abs(inv_dy) * MICRO_SIZE, abs(inv_dz) * MICRO_SIZE)
    delta_dist_micro = (abs(inv_dx), abs(inv_dy), abs(inv_dz))

    # Macro DDA initialisation
    macro_pos = [floor(ray_origin[i] / MICRO_SIZE) for i in range(3)]
    step_macro = [0, 0, 0]
    side_dist_macro = [0.0, 0.0, 0.0]

    for i in range(3):
        metrics['comparisons'] += 1
        if ray_direction[i] < 0:
            step_macro[i] = -1
            metrics['adds_subs'] += 1
            metrics['multiplications'] += 1
            side_dist_macro[i] = (ray_origin[i] / MICRO_SIZE - macro_pos[i]) * delta_dist_macro[i]
        else:
            step_macro[i] = 1
            metrics['adds_subs'] += 2
            metrics['multiplications'] += 1
            side_dist_macro[i] = (macro_pos[i] + 1.0 - ray_origin[i] / MICRO_SIZE) * delta_dist_macro[i]

    # Macro DDA loop
    while True:
        metrics['iterations'] += 1

        out_of_bounds = False
        for i in range(3):
            metrics['comparisons'] += 2
            if macro_pos[i] < 0 or macro_pos[i] >= MACRO_SIZE:
                out_of_bounds = True
                break
        if out_of_bounds:
            return 0, (0, 0, 0), (0, 0, 0)

        # Bitmask occupancy check
        bit_index = macro_pos[0] * 16 + macro_pos[1] * 4 + macro_pos[2]
        metrics['comparisons'] += 1
        if (bitmask >> bit_index) & 1:
            cell_min = [macro_pos[i] * MICRO_SIZE for i in range(3)]
            cell_max = [(macro_pos[i] + 1) * MICRO_SIZE for i in range(3)]

            # Slab test to find macro-cell entry point
            t_enter = 0.0
            entry_axis = 0
            for i in range(3):
                metrics['adds_subs'] += 1
                metrics['multiplications'] += 1
                if ray_direction[i] != 0:
                    t_slab = (cell_min[i] - ray_origin[i]) * inv_dir[i] if ray_direction[i] > 0 else (cell_max[i] - ray_origin[i]) * inv_dir[i]
                    if t_slab > t_enter:
                        t_enter = t_slab
                        entry_axis = i

            metrics['multiplications'] += 3
            metrics['adds_subs'] += 3
            entry = add(ray_origin, scalarMult(max(0.0, t_enter - 1e-4), ray_direction))

            # Clamp entry to macro-cell bounds
            micro_origin = (
                max(float(cell_min[0]), min(float(cell_max[0]) - 1e-6, entry[0])),
                max(float(cell_min[1]), min(float(cell_max[1]) - 1e-6, entry[1])),
                max(float(cell_min[2]), min(float(cell_max[2]) - 1e-6, entry[2])),
            )

            micro_pos = [floor(micro_origin[i]) for i in range(3)]
            step_micro = [0, 0, 0]
            side_dist_micro = [0.0, 0.0, 0.0]

            for i in range(3):
                metrics['comparisons'] += 1
                if ray_direction[i] < 0:
                    step_micro[i] = -1
                    metrics['adds_subs'] += 1
                    metrics['multiplications'] += 1
                    side_dist_micro[i] = (micro_origin[i] - micro_pos[i]) * delta_dist_micro[i]
                else:
                    step_micro[i] = 1
                    metrics['adds_subs'] += 2
                    metrics['multiplications'] += 1
                    side_dist_micro[i] = (micro_pos[i] + 1.0 - micro_origin[i]) * delta_dist_micro[i]

            # Seed with entry_axis so the first voxel has a valid entry-face normal
            last_axis = entry_axis

            # Micro DDA loop
            while True:
                metrics['iterations'] += 1

                still_inside = True
                for i in range(3):
                    metrics['comparisons'] += 2
                    if micro_pos[i] < cell_min[i] or micro_pos[i] >= cell_max[i]:
                        still_inside = False
                        break
                if not still_inside:
                    break

                in_world = True
                for i in range(3):
                    metrics['comparisons'] += 2
                    if micro_pos[i] < 0 or micro_pos[i] >= world_size:
                        in_world = False
                        break
                if not in_world:
                    break

                metrics['mem_reads'] += 1
                metrics['comparisons'] += 1
                if world[micro_pos[0]][micro_pos[1]][micro_pos[2]] > 0:
                    block_value = world[micro_pos[0]][micro_pos[1]][micro_pos[2]]
                    # Use last_axis (face we entered through) for the normal.
                    # Reading min(side_dist_micro) after advancing is wrong — the
                    # stepped axis has already been incremented.
                    normal = [0, 0, 0]
                    normal[last_axis] = -step_micro[last_axis]
                    metrics['adds_subs'] += 4
                    metrics['multiplications'] += 3
                    t = max(0.0, side_dist_micro[last_axis] - delta_dist_micro[last_axis])
                    hit_point = add(micro_origin, scalarMult(t, ray_direction))
                    return block_value, tuple(normal), hit_point

                # Advance micro DDA
                min_sd = 2e30
                axis = 0
                for i in range(3):
                    metrics['comparisons'] += 1
                    if side_dist_micro[i] < min_sd:
                        axis = i
                        min_sd = side_dist_micro[i]

                last_axis = axis
                metrics['adds_subs'] += 1
                side_dist_micro[axis] += delta_dist_micro[axis]
                metrics['adds_subs'] += 1
                micro_pos[axis] += step_micro[axis]

        # Advance macro DDA
        min_sd = 2e30
        macro_axis = 0
        for i in range(3):
            metrics['comparisons'] += 1
            if side_dist_macro[i] < min_sd:
                macro_axis = i
                min_sd = side_dist_macro[i]

        metrics['adds_subs'] += 1
        side_dist_macro[macro_axis] += delta_dist_macro[macro_axis]
        metrics['adds_subs'] += 1
        macro_pos[macro_axis] += step_macro[macro_axis]

def createPPM(pixel_list):
    os.makedirs("ppm_outputs", exist_ok=True)
    with open("ppm_outputs/hierarchical_dda.ppm", "w") as f:
        f.write(f'P3\n{width} {height}\n255')
        for color in pixel_list:
            f.write(f'\n{color[0]} {color[1]} {color[2]}')

def get_colour(block_id, normal_vect, hit_point):
    if block_id == 0:
        return (0, 0, 0)
    light_dir = normalize(sub(light_pos, hit_point))
    intensity = max(0, dot(normal_vect, light_dir))
    obj_color = colour_list[block_id]
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))

def create_image():
    print("create image")
    fov = math.pi / 2
    aspect_ratio = width / height
    pixel_list = []
    start = time.time()

    world = generateWorld(world_size)
    bitmask = buildMacroGridBitmask(world)
    after_gen = time.time()
    print(f"Bitmask: {bin(bitmask)}")

    total_metrics = {
        'mem_reads': 0,
        'iterations': 0,
        'adds_subs': 0,
        'multiplications': 0,
        'divisions': 0,
        'comparisons': 0
    }

    for y in range(height):
        for x in range(width):
            Px = (2 * (x + 0.5) / width - 1) * aspect_ratio * math.tan(fov / 2)
            Py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)

            mapped_ray_dir = (Px, Py, 1)
            camera_pos = (16, 10, 4)

            ray_metrics = {
                'mem_reads': 0,
                'iterations': 0,
                'adds_subs': 0,
                'multiplications': 0,
                'divisions': 0,
                'comparisons': 0
            }

            result = intersect_voxel_hierarchical(camera_pos, normalize(mapped_ray_dir), world, bitmask, ray_metrics)
            block_value, normal, hit_point = result

            for key in total_metrics:
                total_metrics[key] += ray_metrics[key]

            pixel_colour = get_colour(block_value, normal, hit_point)
            pixel_list.append(pixel_colour)

    after_rays = time.time()
    createPPM(pixel_list)

    total_rays = width * height
    print("\n--- HARDWARE PERFORMANCE METRICS (Hierarchical DDA) ---")
    print(f"Total Rays Cast: {total_rays}")
    print(f"Avg Iterations (Steps) per ray:  {total_metrics['iterations'] / total_rays:.2f}")
    print(f"Avg Memory Reads per ray:        {total_metrics['mem_reads'] / total_rays:.2f}")
    print(f"Avg Divisions per ray:           {total_metrics['divisions'] / total_rays:.2f}")
    print(f"Avg Multiplications per ray:     {total_metrics['multiplications'] / total_rays:.2f}")
    print(f"Avg Adds/Subs per ray:           {total_metrics['adds_subs'] / total_rays:.2f}")
    print(f"Avg Comparisons per ray:         {total_metrics['comparisons'] / total_rays:.2f}")
    print("-------------------------------------------------------\n")

    print("\n--- Time Metrics ---")
    print(f"World Gen + Bitmask time: {after_gen - start}")
    print(f"Ray Calculation time: {after_rays - after_gen}")
    print(f"Total Time: {after_rays - start}")

if __name__ == "__main__":
    create_image()
