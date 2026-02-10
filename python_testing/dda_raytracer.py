import math

def normalize(v):
    length = math.sqrt((v[0]*v[0]) * (v[1]*v[1]) * (v[2]*v[2]))

    return (v[0]/length, v[1]/length, v[2]/length)

def floor(num):
    return math.floor(num)

def vectAbs(v):
    return math.sqrt((v[0]*v[0]) * (v[1]*v[1]) * (v[2]*v[2]))

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

def generateWorld(height, rows, cols, default_val=0):
    # Create a 3D grid: [Height][Rows/Z][Cols/X]
    # Initialize everything to 'default_val' (0 = Air)
    world = [[[default_val for _ in range(cols)] for _ in range(rows)] for _ in range(height)]

    # --- 1. Add the Floor ---
    # We use the bottom-most layer (index 0) as the floor.
    for z in range(rows):
        for x in range(cols):
            world[0][z][x] = 1  # Block ID 1 = Floor

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

        # Check map_pos if we are out of bounds, return 0 on block_id and 
        for i in range(3):
            if map_pos[i] >= 16 or map_pos[i] < 0:
                print("out of bounds")
                return 0, (0, 0, 0)

        if world[map_pos[0]][map_pos[1]][map_pos[2]] > 0:
            block_value = world[map_pos[0]][map_pos[1]][map_pos[2]]

    return block_value, normal


def main():
    world = generateWorld(16,16,16)
    print(world[0][1][1])

    print(floor(10.1))
    print(floor(-12.3))
    print(numAbs(-123))

    block_value, normal = intersect_voxel((8.5, 10.5, 8.5), (0, -1, 0), world)
    print(block_value, normal)


if __name__ == main():
    main()