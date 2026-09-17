#!/usr/bin/env python3
"""pngtool — the PNG half of the live kit (stdlib only: zlib + struct).

  pngtool.py crop IN.png OUT.png X Y W H [SCALE]      cut a region (nearest-neighbour zoom by SCALE)
  pngtool.py vshift A.png B.png X0 X1 Y0 Y1           the vertical shift d (B's row y == A's row y-d) that best
                                                      matches the region — how far a scroll moved the content
  pngtool.py pixel IN.png X Y                         print one pixel as rrggbb

Reads the 8-bit RGB / RGBA PNGs wlkit.py writes (all five filter types); writes 8-bit RGB.
"""
import struct
import sys
import zlib


def write_png(path, w, h, rows):
    """rows: h bytes objects of w*3 RGB bytes."""
    raw = b"".join(b"\0" + r for r in rows)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def read_png(path):
    """-> (w, h, rows) with rows as RGB bytes (an alpha channel is dropped)."""
    d = open(path, "rb").read()
    if d[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(path + ": not a PNG")
    off = 8
    idat = b""
    w = h = 0
    ch = 3
    while off < len(d):
        n = struct.unpack(">I", d[off:off + 4])[0]
        t = d[off + 4:off + 8]
        c = d[off + 8:off + 8 + n]
        off += 12 + n
        if t == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", c[:10])
            if depth != 8 or ctype not in (2, 6):
                raise ValueError(path + ": only 8-bit RGB/RGBA is read")
            ch = 3 if ctype == 2 else 4
        elif t == b"IDAT":
            idat += c
    raw = zlib.decompress(idat)
    rows = []
    prev = bytearray(w * ch)
    i = 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + w * ch])
        i += 1 + w * ch
        for x in range(len(line)):
            a = line[x - ch] if x >= ch else 0
            b = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        if ch == 4:
            rgb = bytearray(w * 3)
            rgb[0::3] = line[0::4]
            rgb[1::3] = line[1::4]
            rgb[2::3] = line[2::4]
            rows.append(bytes(rgb))
        else:
            rows.append(bytes(line))
    return w, h, rows


def crop(src, dst, x, y, cw, chh, scale=1):
    w, h, rows = read_png(src)
    if x < 0 or y < 0 or x + cw > w or y + chh > h:
        raise ValueError("region %d,%d %dx%d is outside the %dx%d image" % (x, y, cw, chh, w, h))
    out = []
    for yy in range(y, y + chh):
        r = rows[yy][x * 3:(x + cw) * 3]
        rr = b"".join(r[i:i + 3] * scale for i in range(0, len(r), 3))
        out.extend([rr] * scale)
    write_png(dst, cw * scale, chh * scale, out)


def vshift(a, b, x0, x1, y0, y1, reach=400):
    _, _, ra = read_png(a)
    _, _, rb = read_png(b)
    best = None
    for d in range(-reach, reach + 1):
        cost = n = 0
        for y in range(y0, y1, 2):
            ya = y - d
            if ya < y0 or ya >= y1:
                continue
            if rb[y][x0 * 3:x1 * 3] != ra[ya][x0 * 3:x1 * 3]:
                cost += 1
            n += 1
        if n > (y1 - y0) // 4:
            score = cost / n
            if best is None or score < best[0]:
                best = (score, d)
    return best


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 2
    cmd = argv[1]
    if cmd == "crop" and len(argv) >= 8:
        crop(argv[2], argv[3], *map(int, argv[4:8]), scale=int(argv[8]) if len(argv) > 8 else 1)
        print(argv[3])
        return 0
    if cmd == "vshift" and len(argv) == 8:
        best = vshift(argv[2], argv[3], *map(int, argv[4:8]))
        if best is None:
            print("vshift: the region is too small to compare")
            return 1
        print("shift %d mismatch %.3f" % (best[1], best[0]))
        return 0
    if cmd == "pixel" and len(argv) == 5:
        _, _, rows = read_png(argv[2])
        x, y = int(argv[3]), int(argv[4])
        print("%02x%02x%02x" % tuple(rows[y][x * 3:x * 3 + 3]))
        return 0
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
