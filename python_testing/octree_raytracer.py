import math
import os
import time

light_pos = (16.0, 20, 16.0)
width = 640
height = 360
world_size = 32

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

    # Red cube
    for x in range(14, 18):
        for y in range(1, 10):
            for z in range(14, 18):
                world[x][y][z] = 1  # Red

    # Blue pillar
    for y in range(1, 14):
        world[8][y][8] = 3  # Blue

    return world

def buildOctree(world, node_min, node_max, depth):
    """Recursively build an octree. Prunes empty subtrees to single empty leaf."""
    # Leaf node condition: 1x1x1 voxel cell
    size_x = node_max[0] - node_min[0]
    size_y = node_max[1] - node_min[1]
    size_z = node_max[2] - node_min[2]

    if size_x <= 1 and size_y <= 1 and size_z <= 1:
        # Leaf: read voxel
        wx = max(0, min(world_size - 1, node_min[0]))
        wy = max(0, min(world_size - 1, node_min[1]))
        wz = max(0, min(world_size - 1, node_min[2]))
        val = world[wx][wy][wz]
        return {'is_leaf': True, 'block_value': val, 'min': node_min, 'max': node_max}

    # Check if this entire region is empty (early pruning)
    all_empty = True
    for x in range(node_min[0], min(node_max[0], world_size)):
        if not all_empty:
            break
        for y in range(node_min[1], min(node_max[1], world_size)):
            if not all_empty:
                break
            for z in range(node_min[2], min(node_max[2], world_size)):
                if world[x][y][z] != 0:
                    all_empty = False
                    break

    if all_empty:
        return {'is_leaf': True, 'block_value': 0, 'min': node_min, 'max': node_max}

    # Internal node: split into 8 children
    mid_x = (node_min[0] + node_max[0]) // 2
    mid_y = (node_min[1] + node_max[1]) // 2
    mid_z = (node_min[2] + node_max[2]) // 2

    children = []
    for dx in range(2):
        for dy in range(2):
            for dz in range(2):
                cmin = (
                    node_min[0] if dx == 0 else mid_x,
                    node_min[1] if dy == 0 else mid_y,
                    node_min[2] if dz == 0 else mid_z,
                )
                cmax = (
                    mid_x if dx == 0 else node_max[0],
                    mid_y if dy == 0 else node_max[1],
                    mid_z if dz == 0 else node_max[2],
                )
                child = buildOctree(world, cmin, cmax, depth + 1)
                children.append(child)

    return {'is_leaf': False, 'children': children, 'min': node_min, 'max': node_max}

def intersect_aabb(ray_origin, ray_direction, node_min, node_max, metrics):
    """Slab AABB test. Returns (hit, t_near).
    Each axis: 1 division, 2 subtractions, 2 multiplications.
    """
    t_min = -1e30
    t_max = 1e30

    for i in range(3):
        # --- TRACKING: 1 division ---
        metrics['divisions'] += 1
        if ray_direction[i] != 0:
            inv_d = 1.0 / ray_direction[i]
        else:
            inv_d = 1e30

        # --- TRACKING: 2 subtractions, 2 multiplications ---
        metrics['adds_subs'] += 2
        metrics['multiplications'] += 2
        t1 = (node_min[i] - ray_origin[i]) * inv_d
        t2 = (node_max[i] - ray_origin[i]) * inv_d

        if t1 > t2:
            t1, t2 = t2, t1

        # --- TRACKING: 2 comparisons ---
        metrics['comparisons'] += 2
        if t1 > t_min:
            t_min = t1
        if t2 < t_max:
            t_max = t2

    # --- TRACKING: 2 comparisons ---
    metrics['comparisons'] += 2
    if t_max < t_min or t_max < 0:
        return False, 0.0

    t_hit = t_min if t_min >= 0 else t_max
    return True, t_hit

def computeAABBNormal(hit_point, node_min, node_max):
    """Find which face of the AABB the hit_point is closest to, return that normal."""
    cx = (node_min[0] + node_max[0]) * 0.5
    cy = (node_min[1] + node_max[1]) * 0.5
    cz = (node_min[2] + node_max[2]) * 0.5
    hx = (node_max[0] - node_min[0]) * 0.5
    hy = (node_max[1] - node_min[1]) * 0.5
    hz = (node_max[2] - node_min[2]) * 0.5

    dx = (hit_point[0] - cx) / hx if hx != 0 else 0
    dy = (hit_point[1] - cy) / hy if hy != 0 else 0
    dz = (hit_point[2] - cz) / hz if hz != 0 else 0

    ax, ay, az = abs(dx), abs(dy), abs(dz)
    if ax >= ay and ax >= az:
        return (1.0 if dx > 0 else -1.0, 0.0, 0.0)
    elif ay >= ax and ay >= az:
        return (0.0, 1.0 if dy > 0 else -1.0, 0.0)
    else:
        return (0.0, 0.0, 1.0 if dz > 0 else -1.0)

def intersect_octree(ray_origin, ray_direction, octree, metrics):
    """Stack-based octree traversal (no recursion, FPGA-realistic).
    Returns (block_value, normal, hit_point).
    """
    # Explicit stack — bounded by tree depth (<=5 for 32^3 world)
    stack = [octree]

    best_t = 1e30
    best_node = None

    while stack:
        node = stack.pop()

        # --- TRACKING: 1 iteration ---
        metrics['iterations'] += 1

        hit, t = intersect_aabb(ray_origin, ray_direction, node['min'], node['max'], metrics)
        # --- TRACKING: 1 comparison ---
        metrics['comparisons'] += 1
        if not hit:
            continue

        # --- TRACKING: 1 comparison ---
        metrics['comparisons'] += 1
        if t >= best_t:
            continue

        if node['is_leaf']:
            # --- TRACKING: 1 comparison ---
            metrics['comparisons'] += 1
            if node['block_value'] > 0:
                # --- TRACKING: 1 comparison ---
                metrics['comparisons'] += 1
                if t < best_t:
                    best_t = t
                    best_node = node
            # --- TRACKING: 1 mem read ---
            metrics['mem_reads'] += 1
        else:
            # Push children — closest first heuristic not used (FPGA: simple LIFO)
            for child in node['children']:
                stack.append(child)

    if best_node is None:
        return 0, (0, 0, 0), (0, 0, 0)

    # --- TRACKING: 3 mults, 3 adds ---
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 3
    hit_point = add(ray_origin, scalarMult(best_t, ray_direction))
    normal = computeAABBNormal(hit_point, best_node['min'], best_node['max'])
    return best_node['block_value'], normal, hit_point

def createPPM(pixel_list):
    os.makedirs("ppm_outputs", exist_ok=True)
    with open("ppm_outputs/octree.ppm", "w") as f:
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
    octree = buildOctree(world, (0, 0, 0), (world_size, world_size, world_size), 0)
    after_gen = time.time()

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

            block_value, normal, hit_point = intersect_octree(camera_pos, normalize(mapped_ray_dir), octree, ray_metrics)

            for key in total_metrics:
                total_metrics[key] += ray_metrics[key]

            pixel_colour = get_colour(block_value, normal, hit_point)
            pixel_list.append(pixel_colour)

    after_rays = time.time()
    createPPM(pixel_list)

    total_rays = width * height
    print("\n--- HARDWARE PERFORMANCE METRICS (Octree) ---")
    print(f"Total Rays Cast: {total_rays}")
    print(f"Avg Iterations (Nodes Visited) per ray:  {total_metrics['iterations'] / total_rays:.2f}")
    print(f"Avg Memory Reads per ray:                {total_metrics['mem_reads'] / total_rays:.2f}")
    print(f"Avg Divisions per ray:                   {total_metrics['divisions'] / total_rays:.2f}")
    print(f"Avg Multiplications per ray:             {total_metrics['multiplications'] / total_rays:.2f}")
    print(f"Avg Adds/Subs per ray:                   {total_metrics['adds_subs'] / total_rays:.2f}")
    print(f"Avg Comparisons per ray:                 {total_metrics['comparisons'] / total_rays:.2f}")
    print("---------------------------------------------\n")

    print("\n--- Time Metrics ---")
    print(f"World Gen + Octree Build time: {after_gen - start}")
    print(f"Ray Calculation time: {after_rays - after_gen}")
    print(f"Total Time: {after_rays - start}")

if __name__ == "__main__":
    create_image()
