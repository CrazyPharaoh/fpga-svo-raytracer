import math

light_pos = (8.5, 10, 8.5)
width = 640
height = 360
world_size = 20

colour_list = [(0, 0, 0),
               (255, 0, 0),
               (0, 255, 0),
               (0, 0, 255),
               (255, 255, 255),
               (0, 0, 0)]

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
    return (v1[0] - v2[0], v1[1]- v2[1], v1[2] - v2[2])

def add(v1, v2):
    return (v1[0] + v2[0], v1[1] + v2[1], v1[2]+ v2[2])

def generateWorld(width_x, height_y, depth_z, default_val=0):
    # Create [X][Y][Z] structure
    # Note the order of loops: 
    #   Outer: range(width_x)
    #   Middle: range(height_y)
    #   Inner: range(depth_z)
    print("generating world with size:", width_x)
    world = [[[default_val for z in range(depth_z)] for y in range(height_y)] for x in range(width_x)]

    # # --- Add the Floor
    # # Now we can loop naturally using x and z
    # for x in range(width_x):
    #     for z in range(depth_z):
    #         # Access strictly as [x][y][z]
    #             world[x][0][z] = 1

    check_size = 1

    for x in range(width_x):
        for z in range(depth_z):
            # 1. Scale the coordinates down by the size
            scaled_x = x // check_size
            scaled_z = z // check_size
            
            # 2. Check if the sum is even or odd (standard checkerboard math)
            if (scaled_x + scaled_z) % 2 == 0:
                 world[x][0][z] = 4  # White
            else:
                 world[x][0][z] = 5  # Black

    return world


def intersect_voxel(ray_origin, ray_direction, world):
    # Initialize the algorithm:
    # Check which box we are starting in:
    map_pos = [floor(ray_origin[i]) for i in range(3)]

    # Work out distance moved along ray for 1 unit in each direction
    delta_dist = [1e30 if d == 0 else abs(1/d) for d in ray_direction]

    # Work out what direciton we are moving in for each axis and the 
    # distance to the closest boundary
    step = [0, 0, 0]
    side_dist = [0.0, 0.0, 0.0]

    for i in range(3):
        if ray_direction[i] < 0:
            step[i] = -1
            side_dist[i] = (ray_origin[i] - map_pos[i]) * delta_dist[i]
        else:
            step[i] = 1
            side_dist[i] = (map_pos[i] + 1.0 - ray_origin[i]) * delta_dist[i]
    
    # DDA Loop
    # Check smallest side_dist and pick that axis
    block_value = 0

    while(block_value == 0):
        min_dist = 2e11
        axis = 1
        for i in range(3):
            if side_dist[i] < min_dist:
                axis = i
                min_dist = side_dist[i]
        
        # Increment side dist in the min axis
        side_dist[axis] = side_dist [axis] + delta_dist [axis]

        # Move map coordinates
        map_pos[axis] = map_pos[axis] + step[axis]

        # Record Normal to axis
        normal = [0, 0, 0]
        normal[axis] = -step[axis]

        # Work out hit point
        t = side_dist[axis] - delta_dist[axis]
        hit_point = add(ray_origin , scalarMult(t, ray_direction))

        # Check map_pos if we are out of bounds
        for i in range(3):
            if map_pos[i] >= world_size or map_pos[i] < 0:
                return 0, (0, 0, 0), (0, 0, 0)

        if world[map_pos[0]][map_pos[1]][map_pos[2]] > 0:
            block_value = world[map_pos[0]][map_pos[1]][map_pos[2]]

    return block_value, normal, hit_point

def createPPM(pixel_list):
    with open("output_dda.ppm", "w") as f:
        f.write(f'P3\n{width} {height}\n255')
        for color in pixel_list:
            f.write(f'\n{color[0]} {color[1]} {color[2]}')


def get_colour(block_id, normal_vect, hit_point):
    # If out of bounds return black
    if block_id == 0:
        return (0, 0, 0)
    
    light_dir = normalize(sub(light_pos, hit_point))
    intensity = max(0,dot(normal_vect, light_dir))
    obj_color = colour_list[block_id]
    return (int(obj_color[0] * intensity), int(obj_color[1] * intensity), int(obj_color[2] * intensity))


def main():
    print(floor(10.1))
    print(floor(-12.3))
    print(numAbs(-123))

    block_value, normal, hit_point = intersect_voxel((8.5, 10.5, 8.5), (0, -1, 0), world)
    print(block_value, normal, hit_point)

def create_image():
    print("create image")
    fov = math.pi / 2
    aspect_ratio = width / height
    pixel_list = []
    world = generateWorld(world_size, world_size, world_size)

    for y in range(height):
        for x in range(width):
            
            # Map Screen and camera to rays and coordinates
            Px = (2* (x + 0.5) / width  - 1) * aspect_ratio * math.tan(fov / 2)
            Py = -(2 * (y + 0.5) / height - 1) * math.tan(fov / 2)

            mapped_ray_dir = (Px, Py, 1)
            camera_pos = (8.5, 2, 8.5)

            block_value, normal, hit_point = intersect_voxel(camera_pos, normalize(mapped_ray_dir), world)
            pixel_colour = get_colour(block_value, normal, hit_point)
            pixel_list.append(pixel_colour)
    
    createPPM(pixel_list)

if __name__ == "__main__":
    create_image()