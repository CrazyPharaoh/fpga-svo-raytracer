# host/camera.py
# First-person camera state and keyboard event handler (WASD/arrows/Space/Shift).

import math


class Camera:
    MOVE_SPEED = 0.5   # voxels per keypress
    TURN_SPEED = 2.0   # degrees per keypress

    def __init__(self, pos=(32.0, 15.0, -5.0), yaw=0.0, pitch=-15.0):
        self.pos   = list(pos)
        self.yaw   = yaw         # horizontal, degrees (0 = +Z axis)
        self.pitch = pitch       # vertical tilt, degrees (positive = look up)

    def _basis(self):
        """Return (fwd, right, up) unit vectors from current yaw/pitch."""
        y = math.radians(self.yaw)
        p = math.radians(self.pitch)
        fwd = [
            math.cos(p) * math.sin(y),
            math.sin(p),
            math.cos(p) * math.cos(y),
        ]
        right = self._norm([fwd[2], 0.0, -fwd[0]])
        up    = self._cross(right, fwd)
        return fwd, right, up

    @staticmethod
    def _norm(v):
        l = math.sqrt(sum(x * x for x in v))
        return [x / l for x in v] if l > 1e-9 else list(v)

    @staticmethod
    def _cross(a, b):
        return [
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
        ]

    def handle_key(self, key_name: str) -> bool:
        """Update camera state for one key-down event. Returns True if a new render is needed."""
        fwd, right, _ = self._basis()
        moved = True
        if   key_name == 'KEY_W':         self.pos = [self.pos[i] + fwd[i]   * self.MOVE_SPEED for i in range(3)]
        elif key_name == 'KEY_S':         self.pos = [self.pos[i] - fwd[i]   * self.MOVE_SPEED for i in range(3)]
        elif key_name == 'KEY_A':         self.pos = [self.pos[i] - right[i] * self.MOVE_SPEED for i in range(3)]
        elif key_name == 'KEY_D':         self.pos = [self.pos[i] + right[i] * self.MOVE_SPEED for i in range(3)]
        elif key_name == 'KEY_SPACE':     self.pos[1] += self.MOVE_SPEED
        elif key_name == 'KEY_LEFTSHIFT': self.pos[1] -= self.MOVE_SPEED
        elif key_name == 'KEY_LEFT':      self.yaw   -= self.TURN_SPEED
        elif key_name == 'KEY_RIGHT':     self.yaw   += self.TURN_SPEED
        elif key_name == 'KEY_UP':        self.pitch  = min( 89.0, self.pitch + self.TURN_SPEED)
        elif key_name == 'KEY_DOWN':      self.pitch  = max(-89.0, self.pitch - self.TURN_SPEED)
        else:                             moved = False
        return moved

    def registers(self, fov_deg: float = 60.0, img_w: int = 320) -> dict:
        """Return pos/right/up/fwd/scale as floats ready for Q16.16 conversion and AXI write
        (0x08–0x34 for vectors, 0x38 for scale)."""
        fwd, right, up = self._basis()
        scale = math.tan(math.radians(fov_deg) / 2) / (img_w / 2)
        return {
            'pos':   self.pos,
            'right': right,
            'up':    up,
            'fwd':   fwd,
            'scale': scale,
        }
