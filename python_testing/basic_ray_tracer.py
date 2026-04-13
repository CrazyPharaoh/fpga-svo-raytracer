import math
import os

# --- Added tracking for square roots, a critical hardware bottleneck ---
def normalize(v):
    length = math.sqrt((v[0]*v[0]) + (v[1]*v[1]) + (v[2]*v[2]))
    return (v[0]/length, v[1]/length, v[2]/length)

def dot(v1, v2):
    return (v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2])

def scalarMult(x, v):
    return (v[0] * x, v[1] * x, v[2] * x)

def sub(v1, v2):
    return (v1[0] - v2[0], v1[1]- v2[1], v1[2] - v2[2])

def add(v1, v2):
    return (v1[0] + v2[0], v1[1] + v2[1], v1[2]+ v2[2])

# --- CHANGED: Added metrics dictionary ---
def checkIntersect(ray_origin, ray_dir, sphere_center, sphere_radius, metrics):
    # TRACKING: sub() uses 3 subtractions
    metrics['adds_subs'] += 3
    L = sub(ray_origin, sphere_center)
    
    # TRACKING: dot() uses 3 mults, 2 adds
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 2
    a = dot(ray_dir, ray_dir)
    
    # TRACKING: dot() uses 3 mults, 2 adds. The '2 *' adds 1 mult.
    metrics['multiplications'] += 4
    metrics['adds_subs'] += 2
    b = 2 * dot(L, ray_dir)
    
    # TRACKING: dot() = 3M/2A. Radius squared = 1M. Final minus = 1S. 
    metrics['multiplications'] += 4
    metrics['adds_subs'] += 3
    c = dot(L,L) - (sphere_radius * sphere_radius)

    # TRACKING: b*b (1M), 4*a*c (2M). Final minus (1S).
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 1
    discriminant = (b * b) - (4 * a * c)

    # TRACKING: 1 comparison
    metrics['comparisons'] += 1
    if discriminant > 0:
        # TRACKING: 1 SQRT! Plus 1 div, 1 mult (2*a), 1 sub (-b - ...)
        metrics['sqrts'] += 1
        metrics['divisions'] += 1
        metrics['multiplications'] += 1
        metrics['adds_subs'] += 1
        t1 = (-b - math.sqrt(discriminant)) / (2 * a)
        
        # TRACKING: 1 comparison
        metrics['comparisons'] += 1
        if t1 > 0:
            return t1
        
        # TRACKING: 1 SQRT! Plus 1 div, 1 mult, 1 sub/add
        metrics['sqrts'] += 1
        metrics['divisions'] += 1
        metrics['multiplications'] += 1
        metrics['adds_subs'] += 1
        t2 = (-b + math.sqrt(discriminant)) / (2 * a)
        
        # TRACKING: 1 comparison
        metrics['comparisons'] += 1
        if t2 > 0:
            return t2
        
    return None

scene_objects = [
    {'center': (0, -1, 3), 'radius': 1, 'color': (255, 0, 0)},   # Red Sphere
    {'center': (2, 0, 4), 'radius': 1, 'color': (0, 0, 255)},    # Blue Sphere
    {'center': (-2, 0, 4), 'radius': 1, 'color': (0, 255, 0)},   # Green Sphere
    {'center': (0, -5001, 0), 'radius': 5000, 'color': (255, 255, 0)} # Yellow Floor
]

light_pos = (5, 5, 5)
width = 400
height = 300

# Added metrics dictionary ---
def getPixelColor(scene, light_position, ray_origin, ray_dir, metrics):
    nearest_object = None
    min_dist = float('inf')

    # For every oject in scene, check if it has a lower t (distance) from origin
    for obj in scene:
        # TRACKING: 1 Memory read to fetch object data
        metrics['mem_reads'] += 1
        dist = checkIntersect(ray_origin, ray_dir, obj['center'], obj['radius'], metrics)
        
        # TRACKING: up to 2 comparisons
        metrics['comparisons'] += 2
        if dist and dist < min_dist:
            min_dist = dist
            nearest_object = obj

    # TRACKING: 1 comparison
    metrics['comparisons'] += 1
    if nearest_object == None:
        return (0,0,0) 
    
    # Diffuse Shading Calculation # 
    # TRACKING: scalarMult (3M) + add (3A)
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 3
    hit_point = add(ray_origin, scalarMult(min_dist, ray_dir))
    
    # TRACKING: sub (3S) + normalize (3M, 2A, 1 SQRT, 3D)
    metrics['adds_subs'] += 5
    metrics['multiplications'] += 3
    metrics['sqrts'] += 1
    metrics['divisions'] += 3
    hit_normal = normalize(sub(hit_point, nearest_object['center']))
    
    # TRACKING: sub (3S) + normalize (3M, 2A, 1 SQRT, 3D)
    metrics['adds_subs'] += 5
    metrics['multiplications'] += 3
    metrics['sqrts'] += 1
    metrics['divisions'] += 3
    light_dir = normalize(sub(light_position, hit_point))
    
    # TRACKING: dot (3M, 2A) + max (1C)
    metrics['multiplications'] += 3
    metrics['adds_subs'] += 2
    metrics['comparisons'] += 1
    intensity = max(0,dot(hit_normal, light_dir))
    
    obj_color = nearest_object['color']
    
    # TRACKING: 3 multiplications for color scaling
    metrics['multiplications'] += 3
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))
    
def createPPM(pixel_list):
    os.makedirs("ppm_outputs", exist_ok=True)
    with open("ppm_outputs/basic.ppm", "w") as f:
        f.write(f'P3\n{width} {height}\n255')
        for color in pixel_list:
            f.write(f'\n{color[0]} {color[1]} {color[2]}')

def main():
    fov = math.pi / 2
    aspect_ratio = width / height
    pixel_list = []

    # --- CHANGED: Master metrics dictionary ---
    total_metrics = {
        'mem_reads': 0,
        'sqrts': 0,
        'adds_subs': 0,
        'multiplications': 0,
        'divisions': 0,
        'comparisons': 0
    }

    for y in range(height):
        for x in range(width):

            Px = (2* (x + 0.5) / width  - 1) * aspect_ratio * math.tan(fov / 2)
            Py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)

            mapped_ray_dir = (Px, Py, 1)
            camera_pos = (0, 0, 0)

            # --- CHANGED: Ray metrics dictionary ---
            ray_metrics = {
                'mem_reads': 0,
                'sqrts': 0,         # Track square roots!
                'adds_subs': 0,
                'multiplications': 0,
                'divisions': 0,
                'comparisons': 0
            }

            # TRACKING: Initial normalize() of the ray direction (3M, 2A, 1 SQRT, 3D)
            ray_metrics['multiplications'] += 3
            ray_metrics['adds_subs'] += 2
            ray_metrics['sqrts'] += 1
            ray_metrics['divisions'] += 3

            pixel_color = getPixelColor(scene_objects, light_pos, camera_pos, normalize(mapped_ray_dir), ray_metrics)
            pixel_list.append(pixel_color)

            # --- CHANGED: Accumulate totals ---
            for key in total_metrics:
                total_metrics[key] += ray_metrics[key]
    
    createPPM(pixel_list)
    
    # --- CHANGED: Print analytics ---
    total_rays = width * height
    print("\n--- SPHERE TRACER HARDWARE METRICS ---")
    print(f"Total Rays Cast: {total_rays}")
    print(f"Avg Memory Reads per ray:    {total_metrics['mem_reads'] / total_rays:.2f}")
    print(f"Avg Square Roots per ray:    {total_metrics['sqrts'] / total_rays:.2f} ")
    print(f"Avg Divisions per ray:       {total_metrics['divisions'] / total_rays:.2f}")
    print(f"Avg Multiplications per ray: {total_metrics['multiplications'] / total_rays:.2f}")
    print(f"Avg Adds/Subs per ray:       {total_metrics['adds_subs'] / total_rays:.2f}")
    print(f"Avg Comparisons per ray:     {total_metrics['comparisons'] / total_rays:.2f}")
    print("--------------------------------------\n")
    

if __name__ == "__main__":
    main()