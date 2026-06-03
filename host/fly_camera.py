# host/fly_camera.py — pure camera math for the keyboard fly-through (no hardware imports)
import math
from dataclasses import dataclass

def normalise(v):
    l = math.sqrt(sum(x*x for x in v));  return [x/l for x in v] if l > 1e-9 else list(v)
def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]

PITCH_LIMIT = math.radians(89)

def vectors(yaw, pitch):
    """Return (fwd, right, up) for a yaw/pitch (Y-up), matching display_frame's convention."""
    cp = math.cos(pitch)
    fwd   = [cp*math.sin(yaw), math.sin(pitch), cp*math.cos(yaw)]
    right = normalise(cross(fwd, [0, 1, 0]))
    up    = cross(right, fwd)
    return fwd, right, up

def yaw_pitch_from_fwd(fwd):
    f = normalise(fwd)
    pitch = math.asin(max(-1.0, min(1.0, f[1])))
    yaw   = math.atan2(f[0], f[2])
    return yaw, pitch

@dataclass
class Camera:
    pos:   list
    yaw:   float
    pitch: float
    scale: float = 0.0      # set by caller from the FOV

    @classmethod
    def looking_at(cls, pos, target, scale=0.0):
        y, p = yaw_pitch_from_fwd([target[i]-pos[i] for i in range(3)])
        return cls(pos=list(pos), yaw=y, pitch=p, scale=scale)

    def move(self, forward=0.0, strafe=0.0, vertical=0.0):
        fwd, right, _ = vectors(self.yaw, self.pitch)
        for i in range(3):
            self.pos[i] += fwd[i]*forward + right[i]*strafe + [0, 1, 0][i]*vertical

    def look(self, dyaw=0.0, dpitch=0.0):
        self.yaw  += dyaw
        self.pitch = max(-PITCH_LIMIT, min(PITCH_LIMIT, self.pitch + dpitch))

    def vectors(self):
        return vectors(self.yaw, self.pitch)
