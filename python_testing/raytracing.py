import math

# --- 1. Vector Operations ---
def normalize(v):
    """ Scales a vector to have a length of 1. """
    length = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
    return (v[0] / length, v[1] / length, v[2] / length)

def dot(v1, v2):
    """ Calculates the dot product (angle relationship) of two vectors. """
    return v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2]

def sub(v1, v2):
    """ Subtracts vector v2 from v1. """
    return (v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2])

def add(v1, v2):
    """ Adds two vectors. """
    return (v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2])

# --- 2. Ray-Sphere Intersection ---
def sphere_intersect(center, radius, ray_origin, ray_direction):
    """ 
    Returns the distance to the intersection point if the ray hits the sphere.
    Returns None if the ray misses.
    """
    b = 2 * dot(ray_direction, sub(ray_origin, center))
    c = abs(dot(sub(ray_origin, center), sub(ray_origin, center))) - radius**2
    delta = b**2 - 4 * c
    
    if delta > 0:
        t1 = (-b - math.sqrt(delta)) / 2
        t2 = (-b + math.sqrt(delta)) / 2
        if t1 > 0: return t1
        if t2 > 0: return t2
    return None

# --- 3. The Scene ---
# A sphere is defined by: {'center': (x,y,z), 'radius': r, 'color': (r,g,b)}
scene_objects = [
    {'center': (0, -1, 3), 'radius': 1, 'color': (255, 0, 0)},   # Red Sphere
    {'center': (2, 0, 4), 'radius': 1, 'color': (0, 0, 255)},    # Blue Sphere
    {'center': (-2, 0, 4), 'radius': 1, 'color': (0, 255, 0)},   # Green Sphere
    {'center': (0, -5001, 0), 'radius': 5000, 'color': (255, 255, 0)} # Yellow Floor
]
light_pos = (5, 5, 5)

# --- 4. Determining Color ---
def get_ray_color(ray_origin, ray_direction):
    nearest_object = None
    min_dist = float('inf')

    # Find the nearest object the ray hits
    for obj in scene_objects:
        dist = sphere_intersect(obj['center'], obj['radius'], ray_origin, ray_direction)
        if dist and dist < min_dist:
            min_dist = dist
            nearest_object = obj

    if nearest_object is None:
        return (0, 0, 0) # Background color (Black)

    # Intersection point
    hit_point = add(ray_origin, (ray_direction[0]*min_dist, ray_direction[1]*min_dist, ray_direction[2]*min_dist))
    
    # Normal vector (surface direction) at the hit point
    normal = normalize(sub(hit_point, nearest_object['center']))
    
    # Direction to the light
    to_light = normalize(sub(light_pos, hit_point))
    
    # Simple Diffuse Shading (Lambertian)
    # How directly is the light hitting this point?
    intensity = max(0, dot(normal, to_light))
    
    # Calculate final color
    obj_color = nearest_object['color']
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))

# --- 5. Main Render Loop ---
def render():
    width = 400
    height = 300
    fov = math.pi / 2 # 90 degrees field of view
    
    # PPM Header
    print(f'P3\n{width} {height}\n255')

    for y in range(height):
        for x in range(width):
            # Transform pixel coordinate (x,y) to normalized 3D coordinates
            # This maps the screen from -1 to 1 range
            px = (2 * (x + 0.5) / width - 1) * math.tan(fov / 2) * width / height
            py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)
            
            ray_direction = normalize((px, py, 1))
            
            color = get_ray_color((0, 0, 0), ray_direction)
            print(f'{color[0]} {color[1]} {color[2]}')

  