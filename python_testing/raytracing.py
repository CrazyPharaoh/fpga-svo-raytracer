# raytracing.py — early prototype: minimal sphere raytracer, PPM output to stdout
import math

def normalize(v):
    """Scale to unit length."""
    length = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
    return (v[0] / length, v[1] / length, v[2] / length)

def dot(v1, v2):
    return v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2]

def sub(v1, v2):
    return (v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2])

def add(v1, v2):
    return (v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2])

def sphere_intersect(center, radius, ray_origin, ray_direction):
    """Returns t of nearest intersection, or None on miss."""
    b = 2 * dot(ray_direction, sub(ray_origin, center))
    c = abs(dot(sub(ray_origin, center), sub(ray_origin, center))) - radius**2
    delta = b**2 - 4 * c
    
    if delta > 0:
        t1 = (-b - math.sqrt(delta)) / 2
        t2 = (-b + math.sqrt(delta)) / 2
        if t1 > 0: return t1
        if t2 > 0: return t2
    return None

scene_objects = [
    {'center': (0, -1, 3),    'radius': 1,    'color': (255, 0, 0)},    # red
    {'center': (2, 0, 4),     'radius': 1,    'color': (0, 0, 255)},    # blue
    {'center': (-2, 0, 4),    'radius': 1,    'color': (0, 255, 0)},    # green
    {'center': (0, -5001, 0), 'radius': 5000, 'color': (255, 255, 0)},  # floor
]
light_pos = (5, 5, 5)

def get_ray_color(ray_origin, ray_direction):
    nearest_object = None
    min_dist = float('inf')

    for obj in scene_objects:
        dist = sphere_intersect(obj['center'], obj['radius'], ray_origin, ray_direction)
        if dist and dist < min_dist:
            min_dist = dist
            nearest_object = obj

    if nearest_object is None:
        return (0, 0, 0)

    hit_point = add(ray_origin, (ray_direction[0]*min_dist, ray_direction[1]*min_dist, ray_direction[2]*min_dist))
    normal    = normalize(sub(hit_point, nearest_object['center']))
    to_light  = normalize(sub(light_pos, hit_point))
    intensity = max(0, dot(normal, to_light))  # Lambertian
    obj_color = nearest_object['color']
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))

def render():
    width = 400
    height = 300
    fov = math.pi / 2

    print(f'P3\n{width} {height}\n255')

    for y in range(height):
        for x in range(width):
            px = (2 * (x + 0.5) / width - 1) * math.tan(fov / 2) * width / height
            py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)

            ray_direction = normalize((px, py, 1))

            color = get_ray_color((0, 0, 0), ray_direction)
            print(f'{color[0]} {color[1]} {color[2]}')

  