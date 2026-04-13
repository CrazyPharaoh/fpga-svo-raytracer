import math
import os
import time

light_pos = (5.0, 10.0, -5.0)
width = 640
height = 360

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

def cross(v1, v2):
    return (
        v1[1]*v2[2] - v1[2]*v2[1],
        v1[2]*v2[0] - v1[0]*v2[2],
        v1[0]*v2[1] - v1[1]*v2[0]
    )

def buildScene():
    """Build a scene of triangles with pre-computed normals.
    Scene: Floor (2 triangles) + box/cube (12 triangles) + pyramid (6 triangles) = 20 triangles.
    """
    triangles = []

    def make_tri(v0, v1, v2, color):
        # Pre-compute normal at scene setup time (no per-ray cross product needed for shading)
        edge1 = sub(v1, v0)
        edge2 = sub(v2, v0)
        n = cross(edge1, edge2)
        length = math.sqrt(n[0]*n[0] + n[1]*n[1] + n[2]*n[2])
        if length > 0:
            n = (n[0]/length, n[1]/length, n[2]/length)
        return {
            'v0': v0,
            'v1': v1,
            'v2': v2,
            'normal': n,
            'color': color
        }

    # --- Floor (2 triangles, y=0, spanning -5 to 5 in x and 3 to 13 in z) ---
    floor_color = (200, 200, 200)
    triangles.append(make_tri((-5, 0, 3), (5, 0, 3), (5, 0, 13), floor_color))
    triangles.append(make_tri((-5, 0, 3), (5, 0, 13), (-5, 0, 13), floor_color))

    # --- Box / cube (12 triangles, 6 faces × 2) centered at (0, 1.5, 8) size 2x3x2 ---
    bx0, by0, bz0 = -1.0, 0.0, 7.0
    bx1, by1, bz1 =  1.0, 3.0, 9.0
    box_color = (220, 50, 50)

    # Front face (z = bz0)
    triangles.append(make_tri((bx0, by0, bz0), (bx1, by0, bz0), (bx1, by1, bz0), box_color))
    triangles.append(make_tri((bx0, by0, bz0), (bx1, by1, bz0), (bx0, by1, bz0), box_color))
    # Back face (z = bz1)
    triangles.append(make_tri((bx1, by0, bz1), (bx0, by0, bz1), (bx0, by1, bz1), box_color))
    triangles.append(make_tri((bx1, by0, bz1), (bx0, by1, bz1), (bx1, by1, bz1), box_color))
    # Left face (x = bx0)
    triangles.append(make_tri((bx0, by0, bz1), (bx0, by0, bz0), (bx0, by1, bz0), box_color))
    triangles.append(make_tri((bx0, by0, bz1), (bx0, by1, bz0), (bx0, by1, bz1), box_color))
    # Right face (x = bx1)
    triangles.append(make_tri((bx1, by0, bz0), (bx1, by0, bz1), (bx1, by1, bz1), box_color))
    triangles.append(make_tri((bx1, by0, bz0), (bx1, by1, bz1), (bx1, by1, bz0), box_color))
    # Top face (y = by1)
    triangles.append(make_tri((bx0, by1, bz0), (bx1, by1, bz0), (bx1, by1, bz1), box_color))
    triangles.append(make_tri((bx0, by1, bz0), (bx1, by1, bz1), (bx0, by1, bz1), box_color))
    # Bottom face (y = by0)
    triangles.append(make_tri((bx0, by0, bz1), (bx1, by0, bz1), (bx1, by0, bz0), box_color))
    triangles.append(make_tri((bx0, by0, bz1), (bx1, by0, bz0), (bx0, by0, bz0), box_color))

    # --- Pyramid (4 side faces + 1 base = 4*1 + 2 = 6 triangles) ---
    # Base square: (-1.5, 0, 9.5) to (1.5, 0, 12.5), apex at (0, 3.5, 11)
    p_base = [(-1.5, 0, 9.5), (1.5, 0, 9.5), (1.5, 0, 12.5), (-1.5, 0, 12.5)]
    p_apex = (0.0, 3.5, 11.0)
    pyr_color = (50, 180, 50)

    # 4 side faces
    triangles.append(make_tri(p_base[0], p_base[1], p_apex, pyr_color))
    triangles.append(make_tri(p_base[1], p_base[2], p_apex, pyr_color))
    triangles.append(make_tri(p_base[2], p_base[3], p_apex, pyr_color))
    triangles.append(make_tri(p_base[3], p_base[0], p_apex, pyr_color))

    # Base (2 triangles)
    triangles.append(make_tri(p_base[0], p_base[2], p_base[1], pyr_color))
    triangles.append(make_tri(p_base[0], p_base[3], p_base[2], pyr_color))

    return triangles

def check_triangle_intersect(ray_origin, ray_dir, tri, metrics):
    """Möller-Trumbore algorithm. Returns t or None.

    Operation count per triangle:
      adds_subs:     12  (edges, s-vector, cross products)
      multiplications: 30 (2 cross products + 4 dot products + 3 final)
      divisions:      1  (inv_a = 1.0 / det)
      comparisons:    6  (barycentric bounds + t > 0)
      sqrts:          0
    """
    EPSILON = 1e-7

    v0 = tri['v0']
    v1 = tri['v1']
    v2 = tri['v2']

    # edge1 = v1 - v0, edge2 = v2 - v0
    # --- TRACKING: 3 subs, 3 subs = 6 adds_subs ---
    metrics['adds_subs'] += 6
    edge1 = sub(v1, v0)
    edge2 = sub(v2, v0)

    # h = cross(ray_dir, edge2): 6 mults, 3 subs
    # --- TRACKING: 6 mults, 3 adds_subs ---
    metrics['multiplications'] += 6
    metrics['adds_subs'] += 3
    h = cross(ray_dir, edge2)

    # a = dot(edge1, h): 3 mults, 2 adds
    # --- TRACKING: 3 mults, 2 adds_subs ---
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 2
    a = dot(edge1, h)

    # --- TRACKING: 1 comparison (near-parallel check) ---
    metrics['comparisons'] += 1
    if abs(a) < EPSILON:
        return None

    # inv_a = 1.0 / a
    # --- TRACKING: 1 division ---
    metrics['divisions'] += 1
    inv_a = 1.0 / a

    # s = ray_origin - v0: 3 subs
    # --- TRACKING: 3 adds_subs ---
    metrics['adds_subs'] += 3
    s = sub(ray_origin, v0)

    # u = dot(s, h) * inv_a: 3 mults, 2 adds, 1 mult
    # --- TRACKING: 4 mults, 2 adds_subs ---
    metrics['multiplications'] += 4
    metrics['adds_subs'] += 2
    u = dot(s, h) * inv_a

    # --- TRACKING: 2 comparisons (barycentric u bounds) ---
    metrics['comparisons'] += 2
    if u < 0.0 or u > 1.0:
        return None

    # q = cross(s, edge1): 6 mults, 3 subs
    # --- TRACKING: 6 mults, 3 adds_subs ---
    metrics['multiplications'] += 6
    metrics['adds_subs'] += 3
    q = cross(s, edge1)

    # v = dot(ray_dir, q) * inv_a: 3 mults, 2 adds, 1 mult
    # --- TRACKING: 4 mults, 2 adds_subs ---
    metrics['multiplications'] += 4
    metrics['adds_subs'] += 2
    v = dot(ray_dir, q) * inv_a

    # --- TRACKING: 2 comparisons (barycentric v bounds) ---
    metrics['comparisons'] += 2
    if v < 0.0 or u + v > 1.0:
        return None

    # t = dot(edge2, q) * inv_a: 3 mults, 2 adds, 1 mult
    # --- TRACKING: 4 mults, 2 adds_subs ---
    metrics['multiplications'] += 4
    metrics['adds_subs'] += 2
    t = dot(edge2, q) * inv_a

    # --- TRACKING: 1 comparison (t > 0) ---
    metrics['comparisons'] += 1
    if t > EPSILON:
        return t

    return None

def get_nearest_triangle(scene, ray_origin, ray_dir, metrics):
    """Test all triangles, return (nearest_t, nearest_tri) or (None, None)."""
    nearest_t = None
    nearest_tri = None

    for tri in scene:
        # --- TRACKING: 1 mem read (fetch triangle data) ---
        metrics['mem_reads'] += 1
        t = check_triangle_intersect(ray_origin, ray_dir, tri, metrics)
        # --- TRACKING: 2 comparisons ---
        metrics['comparisons'] += 2
        if t is not None and (nearest_t is None or t < nearest_t):
            nearest_t = t
            nearest_tri = tri

    return nearest_t, nearest_tri

def createPPM(pixel_list):
    os.makedirs("ppm_outputs", exist_ok=True)
    with open("ppm_outputs/triangle.ppm", "w") as f:
        f.write(f'P3\n{width} {height}\n255')
        for color in pixel_list:
            f.write(f'\n{color[0]} {color[1]} {color[2]}')

def get_colour(nearest_t, nearest_tri, ray_origin, ray_dir):
    if nearest_tri is None:
        return (0, 0, 0)

    # --- TRACKING: 3 mults, 3 adds ---
    hit_point = add(ray_origin, scalarMult(nearest_t, ray_dir))
    normal = nearest_tri['normal']

    light_dir = normalize(sub(light_pos, hit_point))
    intensity = max(0, dot(normal, light_dir))
    obj_color = nearest_tri['color']
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))

def create_image():
    print("create image")
    fov = math.pi / 2
    aspect_ratio = width / height
    pixel_list = []
    start = time.time()

    scene = buildScene()
    after_gen = time.time()
    print(f"Scene built: {len(scene)} triangles")

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
            camera_pos = (0, 2, 0)

            ray_metrics = {
                'mem_reads': 0,
                'iterations': 0,
                'adds_subs': 0,
                'multiplications': 0,
                'divisions': 0,
                'comparisons': 0
            }

            ray_dir = normalize(mapped_ray_dir)
            nearest_t, nearest_tri = get_nearest_triangle(scene, camera_pos, ray_dir, ray_metrics)

            for key in total_metrics:
                total_metrics[key] += ray_metrics[key]

            pixel_colour = get_colour(nearest_t, nearest_tri, camera_pos, ray_dir)
            pixel_list.append(pixel_colour)

    after_rays = time.time()
    createPPM(pixel_list)

    total_rays = width * height
    print("\n--- HARDWARE PERFORMANCE METRICS (Möller-Trumbore Triangle) ---")
    print(f"Total Rays Cast: {total_rays}")
    print(f"Total Triangles in Scene: {len(scene)}")
    print(f"Avg Iterations per ray:          {total_metrics['iterations'] / total_rays:.2f}")
    print(f"Avg Memory Reads per ray:        {total_metrics['mem_reads'] / total_rays:.2f}")
    print(f"Avg Divisions per ray:           {total_metrics['divisions'] / total_rays:.2f}")
    print(f"Avg Multiplications per ray:     {total_metrics['multiplications'] / total_rays:.2f}")
    print(f"Avg Adds/Subs per ray:           {total_metrics['adds_subs'] / total_rays:.2f}")
    print(f"Avg Comparisons per ray:         {total_metrics['comparisons'] / total_rays:.2f}")
    print("----------------------------------------------------------------\n")

    print("\n--- Time Metrics ---")
    print(f"Scene Build time: {after_gen - start}")
    print(f"Ray Calculation time: {after_rays - after_gen}")
    print(f"Total Time: {after_rays - start}")

if __name__ == "__main__":
    create_image()
