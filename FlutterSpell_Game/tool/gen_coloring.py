#!/usr/bin/env python3
"""Generates the detailed animal Color by Number pictures
(assets/coloring/{butterfly,peacock,lion,owl}.json).

Every region is a polygon (an SVG path of straight segments). Regions are
listed in paint order - later regions are drawn (and hit-tested) on top.

Usage: python3 tool/gen_coloring.py [--preview DIR]   (preview needs Pillow)
"""
import json, math, os, sys

W = H = 300


def path(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def pol(cx, cy, r, a):
    t = math.radians(a)
    return (cx + r * math.cos(t), cy + r * math.sin(t))


def ell(cx, cy, rx, ry, rot=0.0, n=36):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def circ(cx, cy, r, n=28):
    return ell(cx, cy, r, r, 0, n)


def ell_band(cx, cy, rx, ry, y0, y1, n=10):
    """The part of an ellipse between two horizontal lines."""
    ys = [y0 + (y1 - y0) * i / n for i in range(n + 1)]

    def half(y):
        k = max(0.0, 1 - ((y - cy) / ry) ** 2)
        return rx * math.sqrt(k)

    return [(cx - half(y), y) for y in ys] + [(cx + half(y), y) for y in reversed(ys)]


def mirror(pts):
    return [(W - x, y) for x, y in reversed(pts)]


def rot_about(pts, cx, cy, a):
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def interp(table, a):
    """Smooth (cosine) interpolation of (angle, value) control points."""
    if a <= table[0][0]:
        return table[0][1]
    for (a0, v0), (a1, v1) in zip(table, table[1:]):
        if a <= a1:
            t = (a - a0) / (a1 - a0)
            t = (1 - math.cos(math.pi * t)) / 2
            return v0 + (v1 - v0) * t
    return table[-1][1]


def sector(cx, cy, rf, f0, f1, a0, a1, n=6):
    """Cell between radius fractions f0..f1 of rf(angle), angles a0..a1."""
    angles = [a0 + (a1 - a0) * i / n for i in range(n + 1)]
    outer = [pol(cx, cy, rf(a) * f1, a) for a in angles]
    inner = [pol(cx, cy, rf(a) * f0, a) for a in reversed(angles)]
    return outer + inner


class Pic:
    def __init__(self, pid, title, palette):
        self.id, self.title, self.palette = pid, title, palette
        self.regions = []

    def add(self, color, pts):
        self.regions.append((color, pts))

    def add2(self, color, pts):
        """Add a shape and its mirror image."""
        self.add(color, pts)
        self.add(color, mirror(pts))

    def to_json(self):
        return {
            "id": self.id,
            "title": self.title,
            "width": W,
            "height": H,
            "palette": {str(k): v for k, v in self.palette.items()},
            "regions": [
                {"id": i + 1, "colorIndex": c, "path": path(p)}
                for i, (c, p) in enumerate(self.regions)
            ],
        }


def sky_and_ground(p, sky, ground=None, ground_y=262):
    p.add(sky, [(0, 0), (W, 0), (W, H), (0, H)])
    if ground:
        pts = [(0, ground_y + 6 * math.sin(i / 3)) for i in range(0)]
        pts = [(x, ground_y + 5 * math.sin(x / 28)) for x in range(0, W + 1, 15)]
        p.add(ground, pts + [(W, H), (0, H)])


# --------------------------------------------------------------- butterfly
def butterfly():
    p = Pic("butterfly", "Butterfly", {
        1: "#212121", 2: "#FFC107", 3: "#FF9800", 4: "#E65100", 5: "#FFFFFF",
        6: "#8D6E63", 7: "#B3E5FC", 8: "#81C784", 9: "#F8BBD0",
    })
    p.add(7, [(0, 0), (W, 0), (W, H), (0, H)])
    # meadow: leaves and little flowers around the edges
    p.add(8, [(0, 250), (60, 236), (120, 252), (180, 238), (240, 250), (300, 240), (300, 300), (0, 300)])
    for x, y in ((38, 262), (110, 270), (205, 268), (265, 262)):
        p.add(9, circ(x, y, 9))
        p.add(2, circ(x, y, 3.5, 14))

    fore = [(-90, 62), (-72, 112), (-52, 140), (-32, 130), (-14, 106), (4, 70)]
    hind = [(-2, 62), (18, 96), (44, 118), (70, 102), (90, 62)]
    for origin, table, sectors, a_lo, a_hi in (
        ((152, 142), fore, 5, -88, 4),
        ((152, 144), hind, 4, 0, 88),
    ):
        ox, oy = origin
        rf = lambda a, t=table: interp(t, a)
        step = (a_hi - a_lo) / sectors
        rings = [(0.0, 0.32), (0.32, 0.58), (0.58, 0.82), (0.82, 1.0)]
        for s in range(sectors):
            a0, a1 = a_lo + s * step, a_lo + (s + 1) * step
            for r, (f0, f1) in enumerate(rings):
                if r == 0:
                    color = 2
                elif r == 1:
                    color = 3 if s % 2 == 0 else 2
                elif r == 2:
                    color = 4 if s % 2 == 0 else 3
                else:
                    color = 1
                cell = sector(ox, oy, rf, f0, f1, a0, a1, n=5)
                p.add(color, cell)
                p.add(color, mirror(cell))
        # white spots on the dark border
        for s in range(sectors):
            am = a_lo + (s + 0.5) * step
            r = rf(am) * 0.92
            x, y = pol(ox, oy, r, am)
            p.add(5, circ(x, y, 3.8, 14))
            p.add(5, circ(W - x, y, 3.8, 14))
    # body
    p.add(1, circ(150, 98, 9))
    p.add(5, circ(146, 96, 2.6, 10))
    p.add(5, circ(154, 96, 2.6, 10))
    p.add(6, ell(150, 124, 8.5, 19))
    for i in range(6):
        p.add(1 if i % 2 == 0 else 6, ell(150, 152 + i * 12.5, 7 - i * 0.55, 7.2))
    # antennae
    for sgn in (-1, 1):
        stalk = [(150 + sgn * 3, 92), (150 + sgn * 22, 70), (150 + sgn * 26, 50),
                 (150 + sgn * 29, 50), (150 + sgn * 25, 72), (150 + sgn * 6, 94)]
        p.add(1, stalk)
        p.add(2, circ(150 + sgn * 28, 46, 5, 12))
    return p


# ----------------------------------------------------------------- peacock
def peacock():
    p = Pic("peacock", "Peacock", {
        1: "#212121", 2: "#2E7D32", 3: "#66BB6A", 4: "#FFC107", 5: "#1E88E5",
        6: "#00ACC1", 7: "#FFFFFF", 8: "#0D47A1", 9: "#FFE0B2", 10: "#81D4FA",
        11: "#8BC34A", 12: "#F48FB1",
    })
    sky_and_ground(p, 10, 11, 266)
    for x, y in ((30, 276), (270, 280)):
        p.add(12, circ(x, y, 8))
        p.add(4, circ(x, y, 3, 12))
    fx, fy = 150, 196
    feathers = []
    n = 13
    for i in range(n):
        a = -166 + i * (152 / (n - 1))
        L0, L1 = 40, 146
        outline_l, outline_r = [], []
        for k in range(15):
            t = k / 14
            r = L0 + (L1 - L0) * t
            hw = 13.5 * (math.sin(math.pi * min(1, t ** 0.75))) ** 0.65
            hw_deg = math.degrees(math.atan2(hw, r))
            outline_l.append(pol(fx, fy, r, a - hw_deg))
            outline_r.append(pol(fx, fy, r, a + hw_deg))
        pts = outline_l + list(reversed(outline_r))
        p.add(2 if i % 2 == 0 else 3, pts)
        feathers.append(a)
    # eyes on the feathers (outer gold, blue, teal, dark centre)
    for a in feathers:
        for rr, (rx, ry, col) in zip((108, 108, 108, 108), ((15, 11.5, 4), (10.5, 8, 5), (6.8, 5.2, 6), (3, 2.4, 8))):
            x, y = pol(fx, fy, rr, a)
            p.add(col, ell(x, y, rx, ry, a))
    # body: folded wings at the sides, scale rows on the breast
    p.add(8, ell(150, 240, 44, 32))
    for sgn in (-1, 1):
        p.add(2, ell(150 + sgn * 33, 242, 11, 24, sgn * -12))
    for ri, (y, count) in enumerate(((226, 3), (241, 4), (256, 3))):
        span = 17 * (count - 1)
        for k in range(count):
            p.add(5 if (k + ri) % 2 == 0 else 6, ell(150 - span / 2 + k * 17, y, 8, 7.4))
    # neck
    p.add(8, [(138, 216), (142, 172), (146, 152), (154, 152), (158, 172), (162, 216)])
    for i in range(4):
        p.add(5 if i % 2 == 0 else 6, ell(150, 172 + i * 12, 9.5 - i * 0.2, 5.4))
    # head
    p.add(8, circ(150, 142, 12))
    p.add(7, circ(155, 140, 3.4, 12))
    p.add(1, circ(156, 140, 1.6, 8))
    p.add(4, [(160, 140), (176, 146), (160, 150)])
    p.add(9, ell(144, 148, 4, 2.6))
    # crest
    for dx, h in ((-7, 20), (0, 25), (7, 20)):
        p.add(1, [(150 + dx - 1.3, 132), (150 + dx * 1.7 - 1.3, 132 - h), (150 + dx * 1.7 + 1.3, 132 - h), (150 + dx + 1.3, 132)])
        p.add(6, circ(150 + dx * 1.7, 132 - h - 3, 4.2, 12))
    # legs
    for dx in (-14, 14):
        p.add(4, [(150 + dx - 2.5, 266), (150 + dx + 2.5, 266), (150 + dx + 2.5, 281), (150 + dx - 2.5, 281)])
        p.add(4, [(150 + dx - 11, 287), (150 + dx, 279), (150 + dx + 11, 287)])
    return p


# -------------------------------------------------------------------- lion
def lion():
    p = Pic("lion", "Lion", {
        1: "#212121", 2: "#4E342E", 3: "#795548", 4: "#BF6A1C", 5: "#E39A2D",
        6: "#F2C46D", 7: "#FFF3E0", 8: "#8D5524", 9: "#FFFFFF", 10: "#DCEDC8",
        11: "#D9A441", 12: "#F48FB1",
    })
    p.add(10, [(0, 0), (W, 0), (W, H), (0, H)])
    cx, cy = 150, 156

    def tuft(a, r0, r1, half, curl):
        left, right = [], []
        for k in range(10):
            t = k / 9
            r = r0 + (r1 - r0) * t
            hw = half * (1 - t ** 1.7) ** 0.9
            c = curl * t ** 1.4
            left.append(pol(cx, cy, r, a + c - hw))
            right.append(pol(cx, cy, r, a + c + hw))
        return left + list(reversed(right))

    # three layers of mane tufts, longest and darkest at the back; lengths
    # vary so the outline looks windswept rather than like a flower
    n1, n2, n3 = 18, 16, 14
    for i in range(n1):
        r1 = 138 + 8 * math.sin(i * 2.3) - (10 if 4 < i < 9 else 0)
        p.add(2 if i % 3 else 3, tuft(i * 360 / n1 - 90, 50, min(r1, 144), 11.5, 6 if i % 2 else -6))
    for i in range(n2):
        r1 = 108 + 9 * math.sin(i * 1.7 + 1)
        p.add(8 if i % 2 else 4, tuft(i * 360 / n2 - 90 + 360 / n2 / 2, 46, r1, 12.5, 5 if i % 2 else -5))
    for i in range(n3):
        r1 = 86 + 6 * math.sin(i * 2.9)
        p.add(5 if i % 2 else 6, tuft(i * 360 / n3 - 90, 42, r1, 13.5, 4))
    # ears
    for sgn in (-1, 1):
        p.add(8, circ(150 + sgn * 44, 106, 15))
        p.add(2, circ(150 + sgn * 44, 107, 8.5, 18))
    # head (slightly taller than wide) with cheek fur
    p.add(11, ell(cx, cy + 4, 49, 56, 0, 44))
    for sgn in (-1, 1):
        p.add(6, [(150 + sgn * 44, 160), (150 + sgn * 58, 178), (150 + sgn * 40, 186), (150 + sgn * 36, 170)])
    p.add(6, [(150, 112), (136, 150), (150, 162), (164, 150)])  # nose bridge
    # brow and forehead markings
    for dx, rot in ((-10, -18), (0, 0), (10, 18)):
        p.add(8, ell(150 + dx, 124, 3.4, 9, rot))
    # muzzle
    for sgn in (-1, 1):
        p.add(7, ell(150 + sgn * 15, 180, 19, 15, sgn * -8))
    p.add(7, ell(150, 200, 17, 9))
    # eyes: dark almond, amber iris, pupil, highlight
    for sgn in (-1, 1):
        ex = 150 + sgn * 24
        p.add(2, ell(ex, 143, 15, 8, sgn * 10))
        p.add(5, circ(ex, 143, 6.6, 16))
        p.add(1, circ(ex, 143, 3.2, 12))
        p.add(9, circ(ex + 1.6, 141.4, 1.3, 8))
        p.add(8, ell(ex + sgn * 1, 130, 13, 3.2, sgn * 12))
    # nose, philtrum, mouth
    p.add(2, [(135, 160), (165, 160), (158, 174), (150, 180), (142, 174)])
    p.add(3, [(141, 162), (149, 162), (146, 168)])
    p.add(1, [(148.5, 180), (151.5, 180), (151.5, 192), (148.5, 192)])
    p.add(1, [(150, 191), (134, 199), (128, 194), (146, 188)])
    p.add(1, [(150, 191), (166, 199), (172, 194), (154, 188)])
    p.add(12, ell(150, 204, 7.5, 4.6))
    # whisker dots
    for sgn in (-1, 1):
        for dx, dy in ((20, 176), (29, 182), (18, 187)):
            p.add(8, circ(150 + sgn * dx, dy, 2.2, 10))
    return p


# --------------------------------------------------------------------- owl
def owl():
    p = Pic("owl", "Owl", {
        1: "#212121", 2: "#5D4037", 3: "#8D6E63", 4: "#BCAAA4", 5: "#FFF3E0",
        6: "#FFB300", 7: "#FF8F00", 8: "#FFFFFF", 9: "#1A237E", 10: "#FFF59D",
        11: "#66BB6A", 12: "#3949AB",
    })
    p.add(9, [(0, 0), (W, 0), (W, H), (0, H)])
    p.add(10, circ(238, 56, 27, 36))
    for x, y, r in ((230, 50, 5), (246, 64, 3.5), (236, 66, 2.5)):
        p.add(6, circ(x, y, r, 14))
    for x, y in ((40, 40), (80, 70), (36, 110), (264, 130), (270, 190)):
        s = 6
        p.add(10, [(x, y - s), (x + 1.8, y - 1.8), (x + s, y), (x + 1.8, y + 1.8),
                   (x, y + s), (x - 1.8, y + 1.8), (x - s, y), (x - 1.8, y - 1.8)])
    # branch
    p.add(2, [(0, 252), (80, 248), (220, 250), (300, 246), (300, 270), (220, 272), (80, 270), (0, 274)])
    p.add(3, ell(268, 258, 9, 7))
    for x, y, rot in ((24, 242, -30), (278, 238, 30), (60, 280, 10)):
        p.add(11, ell(x, y, 14, 6.5, rot))
    # tail feathers peeking below the body
    for dx in (-18, 0, 18):
        p.add(3, ell(150 + dx, 246, 8, 12))
    # body
    p.add(2, ell(150, 170, 72, 90))
    p.add(5, ell(150, 190, 50, 64))
    # chest feather scales
    rows = [(150, 4), (170, 5), (190, 4), (210, 5), (230, 4)]
    for ri, (y, count) in enumerate(rows):
        span = 20 * (count - 1)
        for i in range(count):
            x = 150 - span / 2 + i * 20
            p.add(3 if (i + ri) % 2 == 0 else 4, ell(x, y, 9.2, 8.5))
    # wings: overlapping feather leaves down each side
    for k in range(5):
        a = 12 + k * 7
        y0 = 120 + k * 22
        feather = ell(0, 0, 11, 34, 0)
        feather = [(x, y) for x, y in feather]
        placed = rot_about([(x + 86 - k * 1.5, y + y0 + 24) for x, y in feather], 86 - k * 1.5, y0 + 24, 14 - k * 3)
        p.add(2 if k % 2 == 0 else 3, placed)
        p.add(2 if k % 2 == 0 else 3, mirror(placed))
    # head with ear tufts
    for sgn in (-1, 1):
        x = 150 + sgn * 46
        p.add(2, [(x - sgn * 14, 70), (x + sgn * 4, 34), (x + sgn * 12, 76)])
    p.add(2, ell(150, 100, 64, 50))
    # facial discs and eyes
    for sgn in (-1, 1):
        ex = 150 + sgn * 27
        p.add(5, circ(ex, 102, 29, 40))
        p.add(3, ell(ex + sgn * 2, 74, 16, 5, sgn * 18))
        p.add(7, circ(ex, 102, 21, 32))
        p.add(6, circ(ex, 102, 15, 28))
        p.add(1, circ(ex, 102, 9, 22))
        p.add(8, circ(ex + 2.5, 98.5, 3, 10))
    p.add(7, [(141, 104), (159, 104), (150, 130)])
    p.add(6, [(144, 106), (156, 106), (150, 122)])
    # feet
    for dx in (-24, 24):
        for k in (-8, 0, 8):
            p.add(6, ell(150 + dx + k, 253, 3.6, 8))
    return p


PICTURES = [butterfly, peacock, lion, owl]


def preview(pic, outdir, scale=3):
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (W * scale, H * scale), "white")
    d = ImageDraw.Draw(img)
    for c, pts in pic.regions:
        d.polygon([(x * scale, y * scale) for x, y in pts], fill=pic.palette[c], outline="#2B2B2B", width=2)
    img.save(os.path.join(outdir, pic.id + ".png"))


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "coloring")
    prev = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for fn in PICTURES:
        pic = fn()
        with open(os.path.join(out, pic.id + ".json"), "w") as f:
            json.dump(pic.to_json(), f, ensure_ascii=False)
        print(pic.id, len(pic.regions), "regions")
        if prev:
            os.makedirs(prev, exist_ok=True)
            preview(pic, prev)
