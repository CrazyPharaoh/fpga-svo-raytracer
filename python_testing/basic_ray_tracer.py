import math

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

def checkIntersect(ray_origin, ray_dir, sphere_center, sphere_radius):
    L = sub(ray_origin, sphere_center)
    
    a = dot(ray_dir, ray_dir)
    b = 2 * dot(L, ray_dir)
    c = dot(L,L) - (sphere_radius * sphere_radius)

    discriminant = (b * b) - (4 * a * c)

    #t1 will always be the first intersection and > t2
    if discriminant > 0:
        t1 = (-b - math.sqrt(discriminant)) / (2 * a)
        # If t1 < 0, then it is behind camera
        if t1 > 0:
            return t1
        
        # If t1 < 0 and t2 > 0 then the camera is inside a sphere
        t2 = (-b + math.sqrt(discriminant)) / (2 * a)
        if t2 > 0:
            return t2
        
    # Return None if both are negative or no intersection
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

def getPixelColor(scene, light_position, ray_origin, ray_dir):
    # Ray direction must be normalized
    # Check which object is closest to ray origin (for every object which t is less)
    nearest_object = None
    min_dist = float('inf')

    # For every oject in scene, check if it has a lower t (distance) from origin
    for obj in scene:
        dist = checkIntersect(ray_origin, ray_dir, obj['center'], obj['radius'])
        if dist and dist < min_dist:
            min_dist = dist
            nearest_object = obj

    if nearest_object == None:
        return (0,0,0) # return black
    
    # Diffuse Shading Calculation # 
    hit_point = add(ray_origin, scalarMult(min_dist, ray_dir))
    hit_normal = normalize(sub(hit_point, nearest_object['center']))
    light_dir = normalize(sub(light_position, hit_point))
    intensity = max(0,dot(hit_normal, light_dir))
    obj_color = nearest_object['color']
    
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))
    
def createPPM(pixel_list):
    with open("output2.ppm", "w") as f:
        f.write(f'P3\n{width} {height}\n255')
        for color in pixel_list:
            f.write(f'\n{color[0]} {color[1]} {color[2]}')

def main():
    fov = math.pi / 2
    aspect_ratio = width / height
    pixel_list = []

    for y in range(height):
        for x in range(width):

            Px = (2* (x + 0.5) / width  - 1) * aspect_ratio * math.tan(fov / 2)
            Py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)

            mapped_ray_dir = (Px, Py, 1)
            camera_pos = (0, 0, 0)

            pixel_color = getPixelColor(scene_objects, light_pos,camera_pos, normalize(mapped_ray_dir))
            pixel_list.append(pixel_color)
    
    createPPM(pixel_list)
    

if __name__ == "__main__":
    main()