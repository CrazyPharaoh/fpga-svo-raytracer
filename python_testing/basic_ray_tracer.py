import math

def normalize(v):
    length = math.sqrt((v[0]*v[0]) * (v[1]*v[1]) * (v[2]*v[2]))

    return (v[0]/length, v[1]/length, v[2]/length)

def dot(v1, v2):
    return (v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2])

def scalarMult(x, v):
    return (v[0] * x, v[1]/length, v[2]/length)

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
        t1 = (-b - discriminant) / (2 * a)
        # If t1 < 0, then it is behind camera
        if t1 > 0:
            return t1
        
        # If t1 < 0 and t2 > 0 then the camera is inside a sphere
        t2 = (-b + discriminant) / (2 * a)
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

def getPixelColour(scene, light_position, ray_origin, ray_dir):
    # Check which object is closest to ray origin (for every object which t is less)
    nearest_object = None
    min_dist = math.inf()

    for obj in scene:
        dist = checkIntersect(ray_origin, ray_dir, obj['center'], obj['radius'])
        if dist < min_dist:
            min_dist = dist
            nearest_object = obj

    if nearest_object == None:
        return (0,0,0) # return black
    
    # Diffuse Shading Calculation # 
    hit_point = ray_origin +






def main():
    v = (1,2,3)
    v2 = (4,5,6)
    # print(normalize(v))
    # print(sub(v,v2))
    print(dot(v,v2))
    # print(add(v,v2))

    test = 2 * v
    print(test)
    print(math.sqrt(1))

if __name__ == main():
    main()