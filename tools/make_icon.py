"""Erzeugt das App-Icon (1024 px) neu: python3 tools/make_icon.py

Luftballon; die Schnur endet in der Spirale.
Sola-Iconstil: weiße, schlanke Linie auf der Leitfarbe der App; genau eine Linie
läuft in eine Farnspirale (Fiddlehead) aus. Braucht Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTS = [
    os.path.join(ROOT, 'SolaBirthdays/Assets.xcassets/AppIcon.appiconset/icon-1024.png'),
]
BRAND = '#D63A5E'

SS = 4
SW = 30  # Strichstärke auf der 1024er-Fläche
INK = '#FFFFFF'


class Pen:
    """Sammelt Linienzüge; Kurven werden beim Zeichnen in Punkte aufgelöst."""

    def __init__(self):
        self.lines = []

    def move(self, x, y):
        self.lines.append([(x, y)])
        return self

    def line(self, *pts):
        for i in range(0, len(pts), 2):
            self.lines[-1].append((pts[i], pts[i + 1]))
        return self

    def curve(self, x1, y1, x2, y2, x, y, steps=40):
        (x0, y0) = self.lines[-1][-1]
        for i in range(1, steps + 1):
            t = i / steps
            a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
            self.lines[-1].append((a * x0 + b * x1 + c * x2 + d * x, a * y0 + b * y1 + c * y2 + d * y))
        return self

    def quad(self, cx, cy, x, y, steps=20):
        (x0, y0) = self.lines[-1][-1]
        for i in range(1, steps + 1):
            t = i / steps
            a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t ** 2
            self.lines[-1].append((a * x0 + b * cx + c * x, a * y0 + b * cy + c * y))
        return self

    def close(self):
        self.lines[-1].append(self.lines[-1][0])
        return self

    def spiral(self, x, y, heading, r, turns=3, left=False, steps=60):
        """Farnspirale ab (x, y); heading in Grad, 0 = nach oben, im Uhrzeigersinn."""
        h = math.radians(heading)
        sx = -1 if left else 1
        place = lambda px, py: (x + sx * px * math.cos(h) - py * math.sin(h),
                                y + sx * px * math.sin(h) + py * math.cos(h))
        pts, start = [place(0, 0)], 0.0
        for i, f in enumerate((1, 0.64, 0.33, 0.12)[:turns]):
            rr = r * f
            cx, a0 = (start + rr, math.pi) if i % 2 == 0 else (start - rr, 0.0)
            for k in range(1, steps + 1):
                a = a0 + math.pi * k / steps
                pts.append(place(cx + rr * math.cos(a), rr * math.sin(a)))
            start = cx + rr * math.cos(a0 + math.pi)
        self.lines.append(pts)
        return self


def heading(dx, dy):
    return math.degrees(math.atan2(dx, -dy))


def render(motif, background, out, size=1024):
    big = size * SS
    k = big / 1024.0
    w = SW * k
    im = Image.new('RGB', (big, big), background)  # iOS rundet selbst ab, kein Alpha erlaubt
    d = ImageDraw.Draw(im)
    pen = Pen()
    motif(pen)
    for pts in pen.lines:
        pts = [(x * k, y * k) for x, y in pts]
        # Segment für Segment mit runden Gelenken; joint='curve' franst bei dicken Linien aus
        for a, b in zip(pts, pts[1:]):
            d.line((a, b), fill=INK, width=round(w))
        for x, y in pts:
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)
    im.resize((size, size), Image.LANCZOS).save(out, optimize=True)
    print('Icon geschrieben nach', out)


def motif(p):
    p.move(512, 176).curve(632, 176, 708, 268, 708, 378).curve(708, 500, 600, 592, 512, 606)
    p.curve(424, 592, 316, 500, 316, 378).curve(316, 268, 392, 176, 512, 176).close()
    p.move(490, 640).line(512, 606, 534, 640).close()  # Knoten
    p.move(512, 640).curve(474, 690, 550, 730, 512, 776)  # Schnur
    p.spiral(512, 776, 200, r=70, left=True)
    p.move(404, 300).curve(422, 266, 452, 248, 486, 242)  # Glanzlicht


if __name__ == '__main__':
    for out in OUTS:
        render(motif, BRAND, out)
