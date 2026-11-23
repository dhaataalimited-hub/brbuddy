"""Draws BRBuddy's own gallery companions: six originals in the spirit of old games and cartoons, but nobody's
character. Each becomes a normal pack (pet.json and both spritesheets) to the spec in docs/making-a-companion.md.

  python3 Tools/gallery/originals/draw.py <out dir> [--preview]

Then add each to the gallery: python3 Tools/gallery/gallery.py add <out dir>/<id> --creator BRBuddy --made ai
Needs Pillow (python3 -m pip install --user Pillow).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 192, 208           # one cell
S = 4                     # supersampling
COLS, ROWS = 8, 9
MOODS = ["idle", "running", "running", "waving", "jumping", "failed", "waiting", "running", "idle"]
FONT = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 15 * S)
try:
    FONT.set_variation_by_name("Heavy")
except Exception:
    pass
INK = (42, 30, 51)
ORANGE = (255, 159, 67)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + tuple(c[3:])


class Pen:
    """Draws in cell coordinates on a supersampled canvas."""

    def __init__(self):
        self.img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img, "RGBA")   # blends, so see-through colours mix

    def e(self, cx, cy, rx, ry, fill, line=None, w=3):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill,
                       outline=line, width=int(w * S) if line else 0)

    def rr(self, x0, y0, x1, y1, r, fill, line=None, w=3):
        self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill,
                                 outline=line, width=int(w * S) if line else 0)

    def poly(self, pts, fill, line=None, w=3):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)
        if line:
            self.lines(pts + [pts[0]], line, w)

    def lines(self, pts, fill, w):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill, width=int(w * S), joint="curve")
        for x, y in (pts[0], pts[-1]):
            self.e(x, y, w / 2, w / 2, fill)

    def arc(self, cx, cy, rx, ry, start, end, fill, w):
        self.d.arc([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], start, end, fill=fill, width=int(w * S))
        for a in (start, end):
            t = math.radians(a)
            self.e(cx + (rx - w / 2) * math.cos(t), cy + (ry - w / 2) * math.sin(t), w / 2 - .2, w / 2 - .2, fill)

    def chord(self, cx, cy, rx, ry, start, end, fill):
        self.d.chord([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], start, end, fill=fill)

    def text(self, x, y, s, fill):
        self.d.text((x * S, y * S), s, font=FONT, fill=fill, anchor="mm")

    def limb(self, x, y, angle, length, colour, w, hand=None, hand_r=0, side=1):
        """A limb from (x, y). angle 0 points down, 90 points sideways (outwards, by side), 180 up."""
        t = math.radians(angle)
        hx, hy = x + side * length * math.sin(t), y + length * math.cos(t)
        self.lines([(x, y), (hx, hy)], colour, w)
        if hand:
            self.e(hx, hy, hand_r, hand_r, hand)
        return hx, hy

    def done(self):
        return self.img.resize((W, H), Image.LANCZOS)


class Pose:
    """Where the body is and what the face does, for one mood at one phase of its loop."""

    def __init__(self, mood, phase, still):
        self.mood, self.phase, self.still = mood, phase, still
        s = math.sin(2 * math.pi * phase)
        self.dx = self.dy = 0.0
        self.breath = 1.0
        self.arms = (18, 18)           # (left, right) in degrees from straight down
        self.legs = (0.0, 0.0)         # lift in px
        self.glance = 0.0              # pupils, -1 left .. 1 right
        self.blink = False
        self.mouth_w = 1.0
        if still:
            if mood != "idle":
                self.glance = math.sin(2 * math.pi * phase)
                self.blink = round(phase * 8) == 5
            else:
                self.mouth_w = 1 + .35 * s
            return
        if mood == "idle":
            self.breath = 1 + .015 * s
        elif mood == "running":
            self.dy = -4 * abs(math.sin(2 * math.pi * phase * 2))
            self.arms = (18 + 28 * s, 18 - 28 * s)
            self.legs = (5 * max(0, s), 5 * max(0, -s))
            self.glance = math.sin(2 * math.pi * phase)
        elif mood == "waving":
            self.dx = 2 * s
            self.arms = (18, 140 + 22 * math.sin(4 * math.pi * phase))
        elif mood == "jumping":
            self.dy = -24 * math.sin(math.pi * phase)
            self.arms = (150, 150) if 0.05 < phase < 0.95 else (40, 40)
            self.legs = (3, 3) if 0.05 < phase < 0.95 else (0, 0)
        elif mood == "failed":
            self.dx = 5 * math.sin(6 * math.pi * phase)
            self.arms = (35, 35)
        elif mood == "waiting":
            self.dy = -8 * abs(s)
            self.arms = (55 + 15 * s, 55 + 15 * s)


# Faces ---------------------------------------------------------------------------------------------------------------

def face(p, pose, fx, fy, spread, r, ink=INK, blush=(255, 128, 150, 110), mouth_dy=None, pie=False, eye_white=None):
    """Two eyes centred on (fx, fy), `spread` apart from the middle, and a mouth below."""
    m = pose.mood
    my = fy + (mouth_dy if mouth_dy is not None else r * 2.4)
    w = max(2.2, r * .55)
    if blush:
        for side in (-1, 1):
            p.e(fx + side * (spread + r * 1.2), fy + r * 1.6, r * 1.1, r * .62, blush)
    for side in (-1, 1):
        ex = fx + side * spread
        if m == "idle":
            p.arc(ex, fy - r * .3, r, r * .8, 20, 160, ink, w)
        elif m == "jumping":
            p.arc(ex, fy + r * .4, r, r, 200, 340, ink, w)
        elif m == "failed":
            k = r * .8
            p.lines([(ex - k, fy - k), (ex + k, fy + k)], ink, w)
            p.lines([(ex - k, fy + k), (ex + k, fy - k)], ink, w)
        elif pose.blink:
            p.lines([(ex - r, fy), (ex + r, fy)], ink, w)
        else:
            big = 1.25 if m == "waiting" else 1.0
            gx = pose.glance * r * .45
            if pie or eye_white:
                p.e(ex, fy, r * big, r * 1.35 * big, eye_white or (255, 255, 255), ink, w * .7)
                p.e(ex + gx, fy + r * .25, r * .55 * big, r * .8 * big, ink)
                if pie:   # a pie-cut notch in each pupil
                    cx, cy = ex + gx, fy + r * .25
                    p.poly([(cx + r * .12, cy - r * .1), (cx + r * .6, cy - r * .5), (cx + r * .6, cy - r * .15)], eye_white or (255, 255, 255))
            else:
                p.e(ex + gx, fy, r * .82 * big, r * big, ink)
                p.e(ex + gx + r * .28, fy - r * .38, r * .3, r * .3, (255, 255, 255))
    mw = r * 1.1
    if m == "idle":
        k = mw * .45 * pose.mouth_w
        p.lines([(fx - k, my), (fx + k, my)], ink, w * .8)
    elif m == "running":
        p.lines([(fx - mw * .5, my), (fx + mw * .5, my)], ink, w * .8)
    elif m == "waving":
        p.arc(fx, my - mw * .45, mw * .8, mw * .7, 25, 155, ink, w * .85)
    elif m == "jumping":
        p.chord(fx, my - mw * .5, mw, mw * 1.05, 0, 180, ink)
        p.e(fx, my + mw * .3, mw * .45, mw * .25, (255, 120, 140))
    elif m == "failed":
        pts = [(fx - mw + i * mw / 4, my + (2 if i % 2 else -2) * (r / 6)) for i in range(9)]
        p.lines(pts, ink, w * .7)
    elif m == "waiting":
        p.e(fx, my, mw * .32, mw * .42, ink)


# Effects (top-left; BRBuddy draws its own bubbles top-right) ---------------------------------------------------------

def bubble(p, text, colour, phase, dots=None):
    x0, y0, x1, y1 = 8, 12, 58, 38
    p.rr(x0, y0, x1, y1, 12, colour)
    p.poly([(x1 - 16, y1 - 2), (x1 - 4, y1 + 9), (x1 - 6, y1 - 2)], colour)
    if dots:
        for i in range(dots):
            p.e(20 + i * 13, (y0 + y1) / 2, 3.2, 3.2, INK)
    else:
        p.text((x0 + x1) / 2, (y0 + y1) / 2 + 1, text, INK)


def star(p, cx, cy, r, colour):
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * .45
        pts.append((cx + rr * math.cos(a), cy - rr * math.sin(a)))
    p.poly(pts, colour)


def effects(p, pose, head_x, head_top):
    m, t = pose.mood, pose.phase
    if m == "idle":
        for i in range(3):
            k = (t + i / 3) % 1
            a = int(255 * (1 - k) * min(1, k * 4))
            size = 13 + i * 4
            x, y = 24 + i * 14, 50 - k * 22 - i * 6
            p.d.text((x * S, y * S), "z", font=ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", size * S),
                     fill=(232, 224, 255, a), anchor="mm")
    elif m == "waving":
        bubble(p, "hi!", (255, 255, 255), t)
    elif m == "failed":
        bubble(p, "?!", ORANGE, t)
    elif m == "waiting":
        bubble(p, "!", ORANGE, t)
    elif m == "running":
        bubble(p, "", (255, 255, 255), t, dots=1 + min(2, int(t * 3)))
    elif m == "jumping":
        for i in range(3):
            a = 2 * math.pi * (t + i / 3)
            x, y = head_x - 18 + 44 * math.cos(a), head_top - 4 + 9 * math.sin(a)
            if x > 116 and y < 62:
                continue
            star(p, x, y, 6, (255, 214, 102))


# Characters ----------------------------------------------------------------------------------------------------------
# Each draws itself standing on (x, base) and returns where its head's top-middle is (for the jump stars).

def pip(p, pose, x, base):
    """A tiny 8-bit knight with an open helmet, a red plume and a wooden sword."""
    steel, steel_d = (205, 214, 230), (120, 132, 158)
    tunic, tunic_d = (70, 118, 230), (40, 70, 160)
    skin = (255, 214, 176)
    b = pose.breath
    for i, lift in enumerate(pose.legs):
        lx = x - 15 + i * 16
        p.rr(lx, base - 16 - lift, lx + 13, base - lift, 3, (88, 64, 52))
    top = base - 14 - 42 * b
    al, ar = pose.arms
    hx, hy = p.limb(x - 24, top + 12, al, 22, tunic_d, 9, steel, 6, side=-1)
    # The sword, held in the left hand, points away from the body.
    t = math.radians(al)
    p.lines([(hx, hy), (hx - 22 * math.sin(t + .5), hy + 22 * math.cos(t + .5) - 2)], (196, 150, 96), 5)
    p.rr(x - 27, top, x + 27, base - 12, 8, tunic, tunic_d, 3)
    p.e(x - 4, top + 18, 5, 5, (240, 70, 90))
    p.e(x + 4, top + 18, 5, 5, (240, 70, 90))
    p.poly([(x - 9, top + 19), (x + 9, top + 19), (x, top + 29)], (240, 70, 90))
    p.limb(x + 24, top + 12, ar, 22, tunic_d, 9, steel, 6, side=1)
    ht = top - 58
    for i in range(4):   # plume, sweeping back to the left
        p.e(x - 8 - i * 9, ht - 2 + i * 5, 10 - i, 7 - i * .8, (232, 64, 84))
    p.rr(x - 32, ht, x + 32, top + 4, 14, steel, steel_d, 3)
    p.rr(x - 23, ht + 15, x + 23, top - 4, 9, skin)
    face(p, pose, x, ht + 33, 11, 5.2, mouth_dy=12, blush=(255, 140, 150, 140))
    return x, ht - 6


def glorp(p, pose, x, base):
    """A see-through slime that swallowed a key."""
    b = pose.breath
    green = (110, 232, 140, 225)
    rim = (46, 160, 90)
    h, w = 104 * b, 58
    top = base - h
    al, ar = pose.arms
    for side, a in ((-1, al), (1, ar)):
        p.limb(x + side * (w - 8), base - 44, a, 16, (90, 210, 120), 12, (110, 232, 140), 7, side=side)
    pts = []
    for i in range(41):
        a = math.pi * i / 40
        wob = 1 + .03 * math.sin(3 * a + 2 * math.pi * pose.phase) * (0 if pose.still else 1)
        pts.append((x - w * math.cos(a) * wob, base - 8 - (h - 8) * math.sin(a) ** .8))
    pts += [(x + w, base - 4), (x + w * .6, base), (x - w * .6, base), (x - w, base - 4)]
    overlay = Pen()
    overlay.poly(pts, green, rim, 3)
    p.img.alpha_composite(overlay.img)
    # The key, seen through the jelly.
    k = (255, 214, 96, 200)
    p.e(x - 18, base - 30, 9, 9, None, k, 4)
    p.lines([(x - 9, base - 30), (x + 14, base - 30)], k, 4)
    p.lines([(x + 7, base - 30), (x + 7, base - 23)], k, 3.5)
    p.lines([(x + 13, base - 30), (x + 13, base - 24)], k, 3.5)
    p.e(x - 30, top + 30, 8, 14, (214, 255, 226))
    p.e(x - 21, top + 13, 4, 4, (236, 255, 242))
    for dx in (-36, 30):
        p.e(x + dx, base - 1, 7, 4, (90, 210, 120, 220))
    face(p, pose, x + 4, top + 46, 15, 6.2, ink=(24, 64, 40), blush=(255, 140, 170, 100))
    return x, top


def nova(p, pose, x, base):
    """A little arcade spaceship with a face on its hull and a flickering thruster."""
    hull, hull_d = (236, 241, 255), (130, 146, 190)
    red = (236, 80, 96)
    flick = 1 + .25 * math.sin(2 * math.pi * pose.phase * 3) if not pose.still else 1
    bottom = base - 26
    fl = 22 * flick
    p.poly([(x - 12, bottom - 2), (x + 12, bottom - 2), (x, bottom + fl)], (255, 159, 67))
    p.poly([(x - 6, bottom - 2), (x + 6, bottom - 2), (x, bottom + fl * .6)], (255, 230, 120))
    b = pose.breath
    top = bottom - 98 * b
    for side in (-1, 1):   # fins
        p.poly([(x + side * 26, bottom - 34), (x + side * 44, bottom + 2), (x + side * 26, bottom - 4)], red, shade(red, .7), 2.5)
    al, ar = pose.arms
    p.limb(x - 30, bottom - 52, al, 18, hull_d, 8, hull, 6, side=-1)
    p.limb(x + 30, bottom - 52, ar, 18, hull_d, 8, hull, 6, side=1)
    p.rr(x - 32, top + 26, x + 32, bottom, 22, hull, hull_d, 3)
    p.chord(x, top + 44, 32, 44, 180, 360, red)
    p.arc(x, top + 44, 32, 44, 180, 360, shade(red, .7), 3)
    p.rr(x - 32, bottom - 22, x + 32, bottom - 14, 2, (96, 170, 255))
    p.rr(x - 14, bottom - 6, x + 14, bottom + 2, 3, hull_d)
    face(p, pose, x, top + 64, 12, 5.6, blush=(255, 140, 160, 120))
    return x, top


def dot(p, pose, x, base):
    """A 1930s rubber-hose bean: ink body, cream face, pie-cut eyes, white gloves and a bow tie."""
    ink = (28, 24, 34)
    rim = (150, 136, 190)     # a soft light edge so the ink reads on the dark away screen
    cream = (255, 236, 205)
    shoes = (236, 110, 60)
    b = pose.breath

    def hose(pts, w):
        p.lines(pts, rim, w + 3)
        p.lines(pts, ink, w)

    for i, lift in enumerate(pose.legs):
        side = -1 if i == 0 else 1
        lx = x + side * 10
        hose([(lx, base - 32), (lx + side * 2, base - 10 - lift)], 4.5)
        p.e(lx + side * 6, base - 7 - lift, 12, 7, shoes, shade(shoes, .7), 2)
    body_top = base - 32 - 36 * b
    al, ar = pose.arms
    arm_pts = []
    for side, a in ((-1, al), (1, ar)):
        t = math.radians(a)
        sx, sy = x + side * 17, body_top + 12
        arm_pts.append((side, [(sx, sy), (sx + side * 24 * math.sin(t), sy + 24 * math.cos(t))]))
    for side, pts in arm_pts:
        hose(pts, 4)
    p.e(x, base - 34 - 16 * b, 23, 20 * b, ink, rim, 1.8)
    for side, pts in arm_pts:
        hx, hy = pts[-1]
        p.e(hx, hy, 7.5, 7.5, (255, 255, 255), rim, 1.5)
    head_cy = body_top - 22
    p.arc(x - 10, head_cy - 34, 9, 9, 160, 340, rim, 6.5)
    p.arc(x - 10, head_cy - 34, 9, 9, 160, 340, ink, 3.5)
    p.e(x, head_cy, 32, 30, ink, rim, 2)
    p.e(x, head_cy + 9, 26, 20, cream)
    p.e(x - 10, head_cy - 5, 11, 14, cream)
    p.e(x + 10, head_cy - 5, 11, 14, cream)
    p.poly([(x - 12, body_top - 2), (x, body_top + 3), (x - 12, body_top + 9)], (255, 206, 72))
    p.poly([(x + 12, body_top - 2), (x, body_top + 3), (x + 12, body_top + 9)], (255, 206, 72))
    p.e(x, body_top + 3, 3, 3, (230, 170, 40))
    face(p, pose, x, head_cy - 5, 10, 6.2, ink=ink, pie=True, mouth_dy=18, eye_white=(255, 255, 255),
         blush=(255, 120, 120, 110))
    return x, head_cy - 44


def scoot(p, pose, x, base):
    """A scrappy orange alley cat with a bandaged tail."""
    x -= 5   # its ears are tall; keep them out of the top-right corner
    fur, fur_d = (245, 154, 58), (190, 100, 30)
    white = (255, 244, 230)
    b = pose.breath
    # Tail curling up on the left, with a bandage.
    sway = 0 if pose.still else 4 * math.sin(2 * math.pi * pose.phase)
    tail = [(x - 26, base - 20), (x - 46, base - 30), (x - 54 + sway, base - 54), (x - 46 + sway, base - 74)]
    p.lines(tail, fur_d, 13)
    p.lines(tail, fur, 9)
    p.lines([(x - 56 + sway, base - 50), (x - 44 + sway, base - 56)], white, 6)
    for i, lift in enumerate(pose.legs):
        lx = x - 16 + i * 20
        p.rr(lx - 6, base - 18 - lift, lx + 8, base - lift, 6, fur, fur_d, 2.5)
    body_top = base - 12 - 44 * b
    p.e(x, base - 14 - 22 * b, 30, 24 * b, fur, fur_d, 2.5)
    p.e(x, base - 14 - 18 * b, 16, 16 * b, white)
    al, ar = pose.arms
    p.limb(x - 24, body_top + 16, al, 18, fur_d, 10, fur, 6, side=-1)
    p.limb(x + 24, body_top + 16, ar, 18, fur_d, 10, fur, 6, side=1)
    hy = body_top - 22
    for side in (-1, 1):
        ex = x + side * 22
        p.poly([(ex - 14, hy - 18), (ex + side * 3, hy - 44), (ex + 14, hy - 18)], fur, fur_d, 2.5)
        p.poly([(ex - 7, hy - 22), (ex + side * 2, hy - 36), (ex + 7, hy - 22)], (255, 170, 180))
    p.e(x, hy, 40, 32, fur, fur_d, 2.5)
    for i in (-1, 0, 1):   # stripes
        p.lines([(x + i * 10, hy - 33), (x + i * 9, hy - 22)], fur_d, 4)
    p.e(x, hy + 14, 18, 12, white)
    p.poly([(x - 4, hy + 6), (x + 4, hy + 6), (x, hy + 10)], (240, 110, 130))
    for side in (-1, 1):
        for k in (-1, 1):
            p.lines([(x + side * 20, hy + 12 + k * 3), (x + side * 38, hy + 9 + k * 7)], (120, 70, 40), 1.4)
    face(p, pose, x, hy - 6, 16, 6.4, mouth_dy=19, blush=(255, 120, 130, 110))
    return x, hy - 48


def momo(p, pose, x, base):
    """A round rice-ball creature in a seaweed wrap."""
    rice, rice_d = (251, 249, 243), (196, 190, 200)
    nori = (34, 58, 46)
    b = pose.breath
    for i, lift in enumerate(pose.legs):
        lx = x - 16 + i * 20
        p.e(lx + 4, base - 6 - lift, 9, 7, rice, rice_d, 2.5)
    h = 112 * b
    top = base - 8 - h
    al, ar = pose.arms
    p.limb(x - 44, base - 52, al, 16, rice_d, 10, rice, 7, side=-1)
    p.limb(x + 44, base - 52, ar, 16, rice_d, 10, rice, 7, side=1)
    pts = [(x, top + 22), (x + 36, base - 34), (x - 36, base - 34)]

    def rounded_triangle(pen, colour, r):
        pen.d.polygon([(a * S, c * S) for a, c in pts], fill=colour)
        pen.d.line([(a * S, c * S) for a, c in pts + [pts[0]]], fill=colour, width=int(r * 2 * S))
        for a, c in pts:
            pen.e(a, c, r, r, colour)

    rounded_triangle(p, rice_d, 24.5)
    shape = Pen()
    rounded_triangle(shape, rice, 22)
    p.img.alpha_composite(shape.img)
    band = Pen()
    band.rr(x - 30, base - 52, x + 30, base + 20, 6, nori)
    mask = shape.img.getchannel("A")
    p.img.alpha_composite(Image.composite(band.img, Image.new("RGBA", band.img.size), mask))
    for sx, sy in ((x - 12, top + 24), (x + 8, top + 18), (x + 2, top + 32)):
        p.e(sx, sy, 2, 1.2, (60, 50, 40))
    face(p, pose, x, top + 56, 14, 5.8, blush=(255, 140, 160, 150))
    return x, top - 10


CHARACTERS = {
    "pip": (pip, "Pip", "A tiny 8-bit knight who's been grinding XP since 1986.", "bleeps", "level up!", True),
    "glorp": (glorp, "Glorp", "A dungeon slime who swallowed the key. It isn't giving it back.", "plink", "blorp!", False),
    "nova": (nova, "Nova", "A pocket arcade spaceship, fully fuelled and slightly over-excited.", "zoom", "pew pew!", False),
    "dot": (dot, "Dot", "A rubber-hose cartoon bean, fresh out of a 1930s reel.", "fanfare", "hot dog!", False),
    "scoot": (scoot, "Scoot", "A Saturday-morning alley cat. The bandage is from a long story.", "cackle", "meep!", False),
    "momo": (momo, "Momo", "A rice ball with a seaweed wrap and a very soft heart.", "shimmer", "mochi!", False),
}


def pixelate(cell):
    small = cell.resize((W // 3, H // 3 + 1), Image.BOX)
    big = small.resize((W, (H // 3 + 1) * 3), Image.NEAREST).crop((0, 0, W, H))
    alpha = big.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    big.putalpha(alpha)
    return big


def cell(draw, pixel, mood, phase, still):
    pose = Pose(mood, phase, still)
    body = Pen()
    hx, htop = draw(body, pose, 104 + pose.dx, 196 + pose.dy)
    img = body.done()
    if pixel:
        img = pixelate(img)
    fx = Pen()
    effects(fx, pose, hx, htop)
    img.alpha_composite(fx.done())
    return img


def sheet(draw, pixel, still):
    out = Image.new("RGBA", (W * COLS, H * ROWS), (0, 0, 0, 0))
    for row, mood in enumerate(MOODS):
        for col in range(COLS):
            out.paste(cell(draw, pixel, mood, col / COLS, still), (col * W, row * H))
    return out


def check(img, name):
    """The spec's layout rules: top-right corner and cell edges stay empty."""
    a = img.getchannel("A")
    for row in range(ROWS):
        for col in range(COLS):
            x0, y0 = col * W, row * H
            corner = a.crop((x0 + 131, y0, x0 + W, y0 + 50)).getbbox()
            edges = [a.crop(b).getbbox() for b in ((x0, y0, x0 + 1, y0 + H), (x0 + W - 1, y0, x0 + W, y0 + H),
                                                  (x0, y0, x0 + W, y0 + 1), (x0, y0 + H - 1, x0 + W, y0 + H))]
            if corner or any(edges):
                print(f"  {name}: row {row} col {col}: {'corner' if corner else 'edge'} not empty")


def main():
    out = Path(sys.argv[1])
    preview = "--preview" in sys.argv
    for pid, (draw, name, about, sound, line, pixel) in CHARACTERS.items():
        folder = out / pid
        folder.mkdir(parents=True, exist_ok=True)
        main_sheet, still_sheet = sheet(draw, pixel, False), sheet(draw, pixel, True)
        check(main_sheet, pid)
        check(still_sheet, pid + " (still)")
        main_sheet.save(folder / "spritesheet.png", optimize=True)
        still_sheet.save(folder / "spritesheet-still.png", optimize=True)
        (folder / "pet.json").write_text(json.dumps({
            "id": pid, "displayName": name, "description": about, "spriteVersionNumber": 1,
            "spritesheetPath": "spritesheet.png", "stillSpritesheetPath": "spritesheet-still.png",
            "boopSignature": sound, "boopBubble": line, "license": "CC-BY-4.0", "author": "BRBuddy",
        }, indent=2) + "\n")
        if preview:   # one frame of each mood on the away screen's background
            moods = [0, 7, 3, 4, 5, 6]
            board = Image.new("RGBA", (W * len(moods), H), (23, 18, 31, 255))
            for i, row in enumerate(moods):
                board.alpha_composite(main_sheet.crop((2 * W, row * H, 3 * W, row * H + H)), (i * W, 0))
            board.save(out / f"{pid}-preview.png")
        print("drew", pid)


main()
