# triangle_raytracer.py — early prototype: Möller-Trumbore triangle raytracer with op-count metrics
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
    """Floor (2) + box (12) + pyramid (6) = 20 triangles. Normals pre-computed."""
    triangles = []

    def make_tri(v0, v1, v2, color):
        # Normal pre-computed; no per-ray cross product needed
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

    # Floor (y=0, x∈[-5,5], z∈[3,13])
    floor_color = (200, 200, 200)
    triangles.append(make_tri((-5, 0, 3), (5, 0, 3), (5, 0, 13), floor_color))
    triangles.append(make_tri((-5, 0, 3), (5, 0, 13), (-5, 0, 13), floor_color))

    # Box (12 triangles, 6 faces × 2), centred at (0, 1.5, 8), size 2×3×2
    bx0, by0, bz0 = -1.0, 0.0, 7.0
    bx1, by1, bz1 =  1.0, 3.0, 9.0
    box_color = (220, 50, 50)

    triangles.append(make_tri((bx0, by0, bz0), (bx1, by0, bz0), (bx1, by1, bz0), box_color))  # front
    triangles.append(make_tri((bx0, by0, bz0), (bx1, by1, bz0), (bx0, by1, bz0), box_color))
    triangles.append(make_tri((bx1, by0, bz1), (bx0, by0, bz1), (bx0, by1, bz1), box_color))  # back
    triangles.append(make_tri((bx1, by0, bz1), (bx0, by1, bz1), (bx1, by1, bz1), box_color))
    triangles.append(make_tri((bx0, by0, bz1), (bx0, by0, bz0), (bx0, by1, bz0), box_color))  # left
    triangles.append(make_tri((bx0, by0, bz1), (bx0, by1, bz0), (bx0, by1, bz1), box_color))
    triangles.append(make_tri((bx1, by0, bz0), (bx1, by0, bz1), (bx1, by1, bz1), box_color))  # right
    triangles.append(make_tri((bx1, by0, bz0), (bx1, by1, bz1), (bx1, by1, bz0), box_color))
    triangles.append(make_tri((bx0, by1, bz0), (bx1, by1, bz0), (bx1, by1, bz1), box_color))  # top
    triangles.append(make_tri((bx0, by1, bz0), (bx1, by1, bz1), (bx0, by1, bz1), box_color))
    triangles.append(make_tri((bx0, by0, bz1), (bx1, by0, bz1), (bx1, by0, bz0), box_color))  # bottom
    triangles.append(make_tri((bx0, by0, bz1), (bx1, by0, bz0), (bx0, by0, bz0), box_color))

    # Pyramid: base (-1.5,0,9.5)→(1.5,0,12.5), apex (0,3.5,11)
    p_base = [(-1.5, 0, 9.5), (1.5, 0, 9.5), (1.5, 0, 12.5), (-1.5, 0, 12.5)]
    p_apex = (0.0, 3.5, 11.0)
    pyr_color = (50, 180, 50)

    triangles.append(make_tri(p_base[0], p_base[1], p_apex, pyr_color))  # sides
    triangles.append(make_tri(p_base[1], p_base[2], p_apex, pyr_color))
    triangles.append(make_tri(p_base[2], p_base[3], p_apex, pyr_color))
    triangles.append(make_tri(p_base[3], p_base[0], p_apex, pyr_color))
    triangles.append(make_tri(p_base[0], p_base[2], p_base[1], pyr_color))  # base
    triangles.append(make_tri(p_base[0], p_base[3], p_base[2], pyr_color))

    return triangles

def check_triangle_intersect(ray_origin, ray_dir, tri, metrics):
    """Möller-Trumbore. Returns t or None.
    Cost: 12A, 30M, 1D, 6C, 0 sqrt per triangle.
    """
    EPSILON = 1e-7

    v0 = tri['v0']
    v1 = tri['v1']
    v2 = tri['v2']

    metrics['adds_subs'] += 6  # edge1, edge2
    edge1 = sub(v1, v0)
    edge2 = sub(v2, v0)

    metrics['multiplications'] += 6  # h = cross(rd, e2)
    metrics['adds_subs'] += 3
    h = cross(ray_dir, edge2)

    metrics['multiplications'] += 3  # a = dot(e1, h)
    metrics['adds_subs'] += 2
    a = dot(edge1, h)

    metrics['comparisons'] += 1  # near-parallel
    if abs(a) < EPSILON:
        return None

    metrics['divisions'] += 1
    inv_a = 1.0 / a

    metrics['adds_subs'] += 3  # s = ro - v0
    s = sub(ray_origin, v0)

    metrics['multiplications'] += 4  # u
    metrics['adds_subs'] += 2
    u = dot(s, h) * inv_a

    metrics['comparisons'] += 2  # u bounds
    if u < 0.0 or u > 1.0:
        return None

    metrics['multiplications'] += 6  # q = cross(s, e1)
    metrics['adds_subs'] += 3
    q = cross(s, edge1)

    metrics['multiplications'] += 4  # v
    metrics['adds_subs'] += 2
    v = dot(ray_dir, q) * inv_a

    metrics['comparisons'] += 2  # v bounds
    if v < 0.0 or u + v > 1.0:
        return None

    metrics['multiplications'] += 4  # t
    metrics['adds_subs'] += 2
    t = dot(edge2, q) * inv_a

    metrics['comparisons'] += 1  # t > 0
    if t > EPSILON:
        return t

    return None

def get_nearest_triangle(scene, ray_origin, ray_dir, metrics):
    """Linear scan; returns (nearest_t, nearest_tri) or (None, None)."""
    nearest_t = None
    nearest_tri = None

    for tri in scene:
        metrics['mem_reads'] += 1
        t = check_triangle_intersect(ray_origin, ray_dir, tri, metrics)
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
