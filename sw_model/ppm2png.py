#!/usr/bin/env python3
# ppm2png.py — convert a binary P6 PPM to PNG using only the Python standard
# library (struct + zlib). No PIL/numpy, so it also runs on the PYNQ.
#
# Usage:  python3 ppm2png.py [in.ppm] [out.png]   (defaults: frame.ppm frame.png)

import sys
import struct
import zlib


def read_ppm(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:2] != b'P6':
        raise ValueError(f"{path}: not a binary P6 PPM")
    idx = 2
    vals = []
    while len(vals) < 3:                      # width, height, maxval
        while idx < len(data) and data[idx:idx+1].isspace():
            idx += 1
        if data[idx:idx+1] == b'#':           # comment line
            while idx < len(data) and data[idx:idx+1] not in (b'\n', b'\r'):
                idx += 1
            continue
        start = idx
        while idx < len(data) and not data[idx:idx+1].isspace():
            idx += 1
        vals.append(int(data[start:idx]))
    w, h, _maxval = vals
    idx += 1                                   # single whitespace byte after maxval
    pix = data[idx:idx + w*h*3]
    if len(pix) != w*h*3:
        raise ValueError(f"{path}: truncated pixel data ({len(pix)} != {w*h*3})")
    return w, h, pix


def write_png(path, w, h, rgb):
    def chunk(typ, d):
        return (struct.pack('>I', len(d)) + typ + d
                + struct.pack('>I', zlib.crc32(typ + d) & 0xffffffff))
    raw = bytearray()
    for y in range(h):                         # filter byte 0 per scanline
        raw.append(0)
        raw += rgb[y*w*3:(y+1)*w*3]
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)   # 8-bit RGB
    idat = zlib.compress(bytes(raw), 9)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', idat))
        f.write(chunk(b'IEND', b''))


def main():
    inp = sys.argv[1] if len(sys.argv) > 1 else 'frame.ppm'
    out = sys.argv[2] if len(sys.argv) > 2 else 'frame.png'
    w, h, pix = read_ppm(inp)
    write_png(out, w, h, pix)
    print(f"wrote {out} ({w}x{h})")


if __name__ == '__main__':
    main()
