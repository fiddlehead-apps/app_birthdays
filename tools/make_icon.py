"""Erzeugt das App-Icon (1024 px) neu: python3 tools/make_icon.py

Torte mit drei Kerzen auf Himbeerrot, im flachen Stil der anderen Sola-Icons.
Gleiches Motiv wie CakeIllustration in der App. Braucht Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   'Birthdays', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')
SS = 4

BRAND = '#D63A5E'
CAKE = '#FFFFFF'
ICING = '#8E1C3A'
CANDLE = '#FFE1E8'
FLAME = '#FFC857'
PLATE = '#B32D4E'


def rrect(x0, y0, x1, y1, r, steps=12):
    pts = []
    for cx, cy, start in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(steps + 1):
            a = math.radians(start + 90 * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def quad(p0, c, p1, steps=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t ** 2 * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t ** 2 * p1[1])
            for t in (i / steps for i in range(1, steps + 1))]


def icing():
    # Rounded top of the cake, then drips along the bottom edge from right to left.
    corners = rrect(112, 236, 400, 404, 30)
    top_right, top_left = corners[:13], corners[39:]
    out = top_left + top_right + [(400, 290)]
    x = 400
    for nx, depth in ((352, 34), (300, 52), (256, 26), (206, 46), (160, 30), (112, 22)):
        out += quad((x, 290), ((x + nx) / 2, 290 + depth * 1.7), (nx, 290))
        x = nx
    return out


def flame(cx, top):
    left = quad((cx, top), (cx - 26, top + 44), (cx, top + 56))
    right = quad((cx, top + 56), (cx + 26, top + 44), (cx, top))
    return left + right


def scene(size):
    k = size / 512.0
    place = lambda pts: [(x * k, y * k) for x, y in pts]
    shapes = [
        (PLATE, rrect(84, 394, 428, 418, 12)),
        (CAKE, rrect(112, 236, 400, 404, 30)),
        (ICING, icing()),
    ]
    for cx in (186, 256, 326):
        shapes.append((CANDLE, rrect(cx - 13, 150, cx + 13, 240, 8)))
        shapes.append((FLAME, flame(cx, 84)))
    return [(c, place(p)) for c, p in shapes]


if __name__ == '__main__':
    size = 1024
    big = size * SS
    im = Image.new('RGB', (big, big), BRAND)  # iOS rundet selbst ab, kein Alpha erlaubt
    d = ImageDraw.Draw(im)
    for color, pts in scene(big):
        d.polygon(pts, fill=color)
    im.resize((size, size), Image.LANCZOS).save(OUT, optimize=True)
    print('Icon geschrieben nach', OUT)
