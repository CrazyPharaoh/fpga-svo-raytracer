# host/test_fly_camera.py — off-board unit tests for the fly-through camera math.
# Run: cd host && python3 -m pytest test_fly_camera.py -q   (no PYNQ needed)
import math
from fly_camera import Camera, vectors, yaw_pitch_from_fwd, normalise, cross

def approx(a, b, t=1e-4): return all(abs(x-y) < t for x, y in zip(a, b))

def test_zero_yaw_pitch_faces_plus_z():
    fwd, right, up = vectors(0.0, 0.0)
    assert approx(fwd, [0, 0, 1])

def test_vectors_match_notebook_convention():
    fwd, right, up = vectors(0.7, -0.3)
    assert approx(right, normalise(cross(fwd, [0, 1, 0])))
    assert approx(up,    cross(right, fwd))

def test_round_trip_yaw_pitch():
    for y, p in [(0.0, 0.0), (1.2, -0.5), (-2.0, 0.8)]:
        fwd, _, _ = vectors(y, p)
        y2, p2 = yaw_pitch_from_fwd(fwd)
        f2, _, _ = vectors(y2, p2)
        assert approx(fwd, f2)

def test_initial_camera_matches_demo_fwd():
    pos, tgt = [32, 40, -20], [32, 4, 32]
    fwd_demo = normalise([tgt[i]-pos[i] for i in range(3)])
    cam = Camera.looking_at(pos, tgt)
    f, _, _ = vectors(cam.yaw, cam.pitch)
    assert approx(f, fwd_demo)

def test_move_forward_steps_along_fwd():
    cam = Camera(pos=[0, 0, 0], yaw=0.0, pitch=0.0)
    f, _, _ = vectors(cam.yaw, cam.pitch)
    cam.move(forward=2.0)
    assert approx(cam.pos, [f[i]*2.0 for i in range(3)])

def test_pitch_clamped():
    cam = Camera(pos=[0, 0, 0], yaw=0.0, pitch=0.0)
    cam.look(dpitch=10.0)
    assert cam.pitch <= math.radians(89) + 1e-6
