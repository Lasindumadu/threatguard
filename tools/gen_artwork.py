"""Draws ThreatGuard's bundled artwork.

The previous plates were photographic stock waves: soft, banded once scaled to
a phone, and identical from screen to screen. Everything here is drawn instead,
at 2x resolution and downsampled with a Lanczos filter, so lines stay sharp on
any density and the art uses the app's own palette.

Each screen gets its own motif, so the background changes when the destination
does:

    home      orbital system (rings, planets, star dust)
    threats   radar sweep (rings, spokes, blips)
    reports   growth chart (bars, trend line, dot grid)
    settings  circuit traces (hex grid, nodes, pulses)

Run:  python tools/gen_artwork.py
"""

from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("assets", "images")
SS = 2  # supersampling factor


# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------


def rgb(value: str) -> tuple[float, float, float]:
    value = value.lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16),
    )


CYAN = rgb("00E5FF")
AQUA = rgb("2BE0C8")
VIOLET = rgb("7C5CFF")
MINT = rgb("38F0C0")
GOLD = rgb("FFC46B")
RED = rgb("FF4D6D")


# --------------------------------------------------------------------------
# canvas
# --------------------------------------------------------------------------


class Scene:
    """A dark plate with additive light and a crisp vector layer on top."""

    def __init__(self, width: int, height: int, top: str, bottom: str, seed: int = 7):
        self.w = width * SS
        self.h = height * SS
        self.rng = random.Random(seed)

        top_c = np.array(rgb(top), dtype=np.float32)
        bottom_c = np.array(rgb(bottom), dtype=np.float32)

        ramp = np.linspace(0.0, 1.0, self.h, dtype=np.float32)[:, None, None]
        self.base = (top_c * (1 - ramp) + bottom_c * ramp) * np.ones(
            (self.h, self.w, 1), dtype=np.float32
        )
        # A diagonal wash keeps the plate from reading as a flat gradient.
        ys, xs = np.mgrid[0 : self.h, 0 : self.w].astype(np.float32)
        diag = (xs / self.w + ys / self.h) / 2.0
        self.base *= (0.86 + 0.28 * diag)[:, :, None]

        self.light = np.zeros((self.h, self.w, 3), dtype=np.float32)
        self.layer = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        # Scene methods take final-size coordinates; the proxies scale them.
        self.draw = ScaledDraw(ImageDraw.Draw(self.layer), SS)
        self.soft = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.soft_draw = ScaledDraw(ImageDraw.Draw(self.soft), SS)

    # ---------------------------------------------------------------- light

    def glow(
        self,
        cx: float,
        cy: float,
        radius: float,
        color: tuple[float, float, float],
        strength: float = 1.0,
        power: float = 2.4,
    ) -> None:
        r = radius * SS
        cx, cy = cx * SS, cy * SS
        x0, x1 = max(0, int(cx - r)), min(self.w, int(cx + r) + 1)
        y0, y1 = max(0, int(cy - r)), min(self.h, int(cy + r) + 1)
        if x0 >= x1 or y0 >= y1:
            return
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(r, 1.0)
        falloff = np.clip(1.0 - d, 0.0, 1.0) ** power
        for channel in range(3):
            self.light[y0:y1, x0:x1, channel] += color[channel] * strength * falloff

    # --------------------------------------------------------------- shapes

    def ring(
        self,
        cx: float,
        cy: float,
        rx: float,
        ry: float,
        color: tuple[float, float, float],
        alpha: int = 60,
        width: float = 1.6,
        tilt: float = 0.0,
        soft: bool = False,
    ) -> None:
        """An ellipse ring, optionally tilted around its own centre."""
        rx, ry = rx * SS, ry * SS
        pad = max(rx, ry) + 8
        size = int(pad * 2)
        tmp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(tmp)
        d.ellipse(
            [pad - rx, pad - ry, pad + rx, pad + ry],
            outline=tuple(int(c) for c in color) + (alpha,),
            width=max(1, int(width * SS)),
        )
        if tilt:
            tmp = tmp.rotate(tilt, resample=Image.BICUBIC, expand=False)
        target = self.soft if soft else self.layer
        target.alpha_composite(tmp, (int(cx * SS - pad), int(cy * SS - pad)))

    def arc(
        self,
        cx: float,
        cy: float,
        rx: float,
        ry: float,
        start: float,
        end: float,
        color: tuple[float, float, float],
        alpha: int = 200,
        width: float = 2.4,
        tilt: float = 0.0,
    ) -> None:
        rx, ry = rx * SS, ry * SS
        pad = max(rx, ry) + 12
        size = int(pad * 2)
        tmp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(tmp)
        d.arc(
            [pad - rx, pad - ry, pad + rx, pad + ry],
            start,
            end,
            fill=tuple(int(c) for c in color) + (alpha,),
            width=max(1, int(width * SS)),
        )
        if tilt:
            tmp = tmp.rotate(tilt, resample=Image.BICUBIC, expand=False)
        self.layer.alpha_composite(tmp, (int(cx * SS - pad), int(cy * SS - pad)))

    def dot(
        self,
        cx: float,
        cy: float,
        r: float,
        color: tuple[float, float, float],
        alpha: int = 255,
        soft: bool = False,
    ) -> None:
        target = self.soft_draw if soft else self.draw
        target.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=tuple(int(c) for c in color) + (alpha,),
        )

    def line(
        self,
        points: list[tuple[float, float]],
        color: tuple[float, float, float],
        alpha: int = 90,
        width: float = 1.2,
        soft: bool = False,
    ) -> None:
        target = self.soft_draw if soft else self.draw
        target.line(
            points,
            fill=tuple(int(c) for c in color) + (alpha,),
            width=max(1, int(width * SS)),
            joint="curve",
        )

    def stars(self, count: int, color=CYAN, area=None) -> None:
        x0, y0, x1, y1 = area or (0, 0, self.w // SS, self.h // SS)
        for _ in range(count):
            x = self.rng.uniform(x0, x1)
            y = self.rng.uniform(y0, y1)
            r = self.rng.choice([0.5, 0.7, 0.9, 1.1, 1.6])
            alpha = int(self.rng.uniform(28, 150))
            self.dot(x, y, r, color, alpha)
            if r > 1.4:
                self.glow(x, y, r * 9, color, 0.5)

    # -------------------------------------------------------------- compose

    def save(self, name: str, blur_soft: float = 1.0) -> str:
        if blur_soft:
            self.soft = self.soft.filter(
                ImageFilter.GaussianBlur(blur_soft * SS)
            )

        light = np.clip(self.light, 0, 255)
        out = self.base + light
        out = np.clip(out, 0, 255).astype(np.uint8)
        image = Image.fromarray(out, "RGB").convert("RGBA")

        layer = Image.alpha_composite(self.soft, self.layer)
        image.alpha_composite(layer)

        # Vignette, so the edges of a phone screen fall away instead of
        # showing a hard rectangle of art behind the glass panels.
        w, h = image.size
        ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
        nx = (xs / w - 0.5) * 2
        ny = (ys / h - 0.5) * 2
        d = np.clip(np.sqrt(nx**2 + ny**2) / 1.42, 0, 1)
        vignette = (1.0 - 0.42 * d**2.1)[:, :, None]
        arr = np.asarray(image, dtype=np.float32) * vignette
        image = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

        final_size = (w // SS, h // SS)
        image = image.resize(final_size, Image.LANCZOS)

        path = os.path.join(OUT, name)
        if name.lower().endswith(".jpg"):
            image.convert("RGB").save(path, quality=92, subsampling=0, optimize=True)
        else:
            image.save(path, optimize=True)
        return path


class ScaledDraw:
    """Wraps ImageDraw so art is authored in final-size coordinates.

    The canvas is [SS] times larger so thin strokes stay smooth, and this proxy
    multiplies every coordinate on the way in. Authoring against the real size
    (rather than the supersampled one) keeps the geometry in the code readable
    and comparable to the layout it has to sit inside.
    """

    __slots__ = ("_d", "_k")

    def __init__(self, draw: ImageDraw.ImageDraw, scale: int) -> None:
        self._d = draw
        self._k = scale

    def _box(self, box):
        return [value * self._k for value in box]

    def _points(self, points):
        return [(x * self._k, y * self._k) for x, y in points]

    def ellipse(self, xy, **kwargs):
        self._d.ellipse(self._box(xy), **kwargs)

    def rectangle(self, xy, **kwargs):
        self._d.rectangle(self._box(xy), **kwargs)

    def rounded_rectangle(self, xy, radius=0, **kwargs):
        self._d.rounded_rectangle(self._box(xy), radius=radius, **kwargs)

    def arc(self, xy, start, end, **kwargs):
        self._d.arc(self._box(xy), start, end, **kwargs)

    def chord(self, xy, start, end, **kwargs):
        self._d.chord(self._box(xy), start, end, **kwargs)

    def pieslice(self, xy, start, end, **kwargs):
        self._d.pieslice(self._box(xy), start, end, **kwargs)

    def polygon(self, xy, **kwargs):
        self._d.polygon(self._points(xy), **kwargs)

    def line(self, xy, **kwargs):
        self._d.line(self._points(xy), **kwargs)


def transparent(width: int, height: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img: Image.Image, name: str, glow_layer: Image.Image | None = None) -> str:
    if glow_layer is not None:
        img = Image.alpha_composite(glow_layer, img)
    size = (img.width // SS, img.height // SS)
    img = img.resize(size, Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    return path


def soft_glow(width: int, height: int, blobs) -> Image.Image:
    """A blurred RGBA layer of additive light blobs: (x, y, r, color, alpha)."""
    layer = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x, y, r, color, alpha in blobs:
        draw.ellipse(
            [(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS],
            fill=tuple(int(c) for c in color) + (alpha,),
        )
    return layer.filter(ImageFilter.GaussianBlur(18 * SS))


# --------------------------------------------------------------------------
# background plates
# --------------------------------------------------------------------------


def bg_home() -> str:
    """An orbital system: the brand's 'watching over you' motif, in the dark."""
    s = Scene(1080, 1920, "010B1A", "00101F", seed=11)
    s.glow(540, 690, 620, CYAN, 0.16)
    s.glow(180, 1560, 520, VIOLET, 0.12)
    s.glow(980, 240, 420, AQUA, 0.10)
    s.stars(260, CYAN)

    cx, cy = 540, 800
    rings = [
        (210, 82, 86, 4.0),
        (330, 128, 74, 6.0),
        (455, 176, 62, 4.0),
        (585, 226, 52, 5.0),
    ]
    for rx, ry, alpha, width in rings:
        # Soft pass first, hairline second: the ring reads lit rather than
        # printed, without the blur that made the old photography muddy.
        s.ring(cx, cy, rx, ry, CYAN, alpha=alpha, width=width, tilt=-16, soft=True)
        s.ring(cx, cy, rx, ry, CYAN, alpha=alpha + 26, width=0.9, tilt=-16)

    # A brighter arc on each ring reads as a highlight catching the light.
    s.arc(cx, cy, 210, 82, -50, 55, CYAN, alpha=235, width=2.8, tilt=-16)
    s.arc(cx, cy, 330, 128, 20, 95, AQUA, alpha=205, width=2.4, tilt=-16)
    s.arc(cx, cy, 585, 226, 150, 200, VIOLET, alpha=210, width=2.6, tilt=-16)

    planets = [
        (rings[0], 35, 7.0, AQUA),
        (rings[0], 210, 4.0, MINT),
        (rings[1], 118, 10.0, CYAN),
        (rings[1], 292, 5.0, MINT),
        (rings[2], 205, 12.0, VIOLET),
        (rings[2], 20, 4.5, CYAN),
        (rings[3], 245, 8.5, AQUA),
        (rings[3], 80, 5.0, CYAN),
    ]
    for (rx, ry, _, _), angle, size, color in planets:
        a = math.radians(angle)
        x = cx + rx * math.cos(a)
        y = cy + ry * math.sin(a) * math.cos(math.radians(16))
        s.glow(x, y, size * 9, color, 0.6)
        s.dot(x, y, size, color, 240)

    # Constellation lines between a few fixed points: the "network" half of
    # the story, kept faint so it never competes with the rings.
    nodes = [(120, 300), (330, 210), (760, 240), (980, 420), (150, 1240), (900, 1180)]
    for i, (x, y) in enumerate(nodes):
        for x2, y2 in nodes[i + 1 : i + 3]:
            s.line([(x, y), (x2, y2)], CYAN, alpha=18, width=0.6)
        s.glow(x, y, 26, CYAN, 0.35)
        s.dot(x, y, 2.6, CYAN, 190)

    # Core, with a horizon arc so the system has a "sun".
    s.glow(cx, cy, 240, CYAN, 0.26)
    s.arc(cx, cy, 96, 38, 200, 340, CYAN, alpha=180, width=2.0, tilt=-16)
    s.dot(cx, cy, 30, CYAN, 235)
    s.dot(cx, cy, 52, CYAN, 55, soft=True)

    # Faint perspective grid at the bottom: depth without noise.
    for i in range(-8, 18):
        x = i * 78
        s.line([(x, 1920), (540 + (x - 540) * 0.16, 1300)], CYAN, alpha=30, width=0.9)
    for j in range(1, 8):
        y = 1300 + j**1.8 * 17
        s.line([(0, y), (1080, y)], CYAN, alpha=24, width=0.9)

    return s.save("bg_home.jpg")


def bg_threats() -> str:
    """A radar: rings, spokes, a sweeping beam and a few blips."""
    s = Scene(1080, 1920, "02121C", "00101A", seed=23)
    s.glow(540, 900, 760, AQUA, 0.10)
    s.glow(120, 200, 420, CYAN, 0.08)
    s.stars(150, AQUA)

    cx, cy = 540, 840
    radii = [150, 268, 386, 504, 620]
    for i, r in enumerate(radii):
        s.ring(cx, cy, r, r, AQUA, alpha=38 + i * 7, width=1.0)
        s.ring(cx, cy, r, r, AQUA, alpha=12, width=8.0, soft=True)

    s.line([(0, cy), (1080, cy)], AQUA, alpha=34)
    s.line([(cx, cy - 700), (cx, cy + 700)], AQUA, alpha=34)

    # Spokes every 15 degrees on the inner rings only, so the middle reads as a
    # dial and the outside stays quiet.
    for deg in range(0, 360, 15):
        a = math.radians(deg)
        s.line(
            [(cx + 150 * math.cos(a), cy + 150 * math.sin(a)),
             (cx + 620 * math.cos(a), cy + 620 * math.sin(a))],
            AQUA,
            alpha=14,
        )

    # The sweep: a wedge of light, brightest at the leading edge.
    sweep = -64
    for i in range(48):
        deg = sweep - i * 1.6
        a = math.radians(deg)
        alpha = int(64 * (1 - i / 48) ** 1.6)
        s.line(
            [(cx, cy), (cx + 620 * math.cos(a), cy + 620 * math.sin(a))],
            AQUA,
            alpha=alpha,
            width=1.6,
        )
    a = math.radians(sweep)
    s.line([(cx, cy), (cx + 618 * math.cos(a), cy + 618 * math.sin(a))], AQUA, alpha=170, width=2.0)
    s.glow(cx + 590 * math.cos(a), cy + 590 * math.sin(a), 96, AQUA, 0.34)
    s.glow(cx, cy, 130, AQUA, 0.20)

    blips = [
        (300, 640, RED, 7),
        (742, 1010, GOLD, 6),
        (620, 660, AQUA, 5),
        (412, 1140, AQUA, 4),
        (840, 560, VIOLET, 4),
        (250, 1080, AQUA, 3),
    ]
    for x, y, color, size in blips:
        s.glow(x, y, size * 12, color, 0.45)
        s.dot(x, y, size, color, 235)
        s.ring(x, y, size * 4.5, size * 4.5, color, alpha=120, width=1.0)

    s.dot(cx, cy, 4.0, AQUA, 210)
    for i in range(-5, 6):
        for j in range(-5, 6):
            s.dot(cx + i * 104, 1560 + j * 52, 2.4, AQUA, 30)

    return s.save("bg_threats.jpg")


def bg_reports() -> str:
    """A growth chart: bars, a trend line and a dot grid."""
    s = Scene(1080, 1920, "0A0520", "00101F", seed=31)
    s.glow(240, 480, 620, VIOLET, 0.16)
    s.glow(880, 1320, 560, CYAN, 0.09)
    s.stars(170, VIOLET)

    for i in range(-2, 13):
        s.line([(i * 96, 0), (i * 96, 1920)], VIOLET, alpha=12, width=0.9)
    for j in range(0, 21):
        s.line([(0, j * 96), (1080, j * 96)], VIOLET, alpha=12, width=0.9)
    for i in range(0, 11):
        for j in range(0, 19):
            s.dot(i * 108 + 20, j * 108 + 30, 1.7, CYAN, 24)

    baseline = 1520
    heights = [230, 320, 285, 470, 420, 610, 700]
    for i, height in enumerate(heights):
        x = 132 + i * 136
        top = baseline - height
        s.draw.rounded_rectangle(
            [x - 44, top, x + 44, baseline],
            radius=22 * SS,
            fill=(int(VIOLET[0]), int(VIOLET[1]), int(VIOLET[2]), 58),
            outline=(int(VIOLET[0]), int(VIOLET[1]), int(VIOLET[2]), 130),
            width=2 * SS,
        )
        s.draw.rounded_rectangle(
            [x - 44, top, x + 44, top + 30],
            radius=15 * SS,
            fill=(int(CYAN[0]), int(CYAN[1]), int(CYAN[2]), 165),
        )
        s.glow(x, top, 90, VIOLET, 0.30)

    points = [
        (132, 1180),
        (268, 1120),
        (404, 1175),
        (540, 940),
        (676, 990),
        (812, 790),
        (948, 660),
    ]

    # Area under the line, so the trend has weight instead of floating.
    area = Image.new("RGBA", (s.w, s.h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(area)
    ad.polygon(
        [(x * SS, y * SS) for x, y in points] + [(948 * SS, baseline * SS), (132 * SS, baseline * SS)],
        fill=(int(CYAN[0]), int(CYAN[1]), int(CYAN[2]), 34),
    )
    s.soft.alpha_composite(area.filter(ImageFilter.GaussianBlur(3 * SS)))

    s.line(points, CYAN, alpha=90, width=3.2, soft=True)
    s.line(points, CYAN, alpha=205, width=2.4)
    for x, y in points:
        s.dot(x, y, 3.8, CYAN, 220)
    s.glow(948, 660, 120, CYAN, 0.38)

    s.line([(80, baseline), (1010, baseline)], CYAN, alpha=48, width=1.6)
    for i in range(8):
        y = 240 + i * 165
        s.line([(80, y), (1010, y)], CYAN, alpha=20, width=1.0)

    return s.save("bg_reports.jpg")


def bg_settings() -> str:
    """Circuit traces and a hex field: the configuration layer."""
    s = Scene(1080, 1920, "001310", "00101B", seed=43)
    s.glow(860, 380, 620, MINT, 0.12)
    s.glow(160, 1480, 620, AQUA, 0.11)
    s.stars(140, MINT)

    def hex_ring(cx, cy, r, color, alpha):
        pts = [
            (
                cx + r * math.cos(math.radians(60 * k - 30)),
                cy + r * math.sin(math.radians(60 * k - 30)),
            )
            for k in range(6)
        ]
        s.line(pts + [pts[0]], color, alpha=alpha, width=0.9)

    for row in range(-1, 14):
        for col in range(-1, 11):
            cx = col * 128 + (row % 2) * 64
            cy = row * 148
            hex_ring(cx, cy, 76, MINT, 24)

    # Traces: right-angled runs terminating in a node, the way a board reads.
    traces = [
        [(60, 300), (250, 300), (250, 460), (450, 460)],
        [(1020, 540), (830, 540), (830, 700), (620, 700)],
        [(70, 1120), (300, 1120), (300, 960), (520, 960)],
        [(1010, 1420), (780, 1420), (780, 1270), (560, 1270)],
        [(160, 700), (160, 860), (350, 860)],
        [(920, 1650), (700, 1650), (700, 1520), (480, 1520)],
        [(60, 1780), (240, 1780), (240, 1640), (400, 1640)],
    ]
    for trace in traces:
        s.line(trace, MINT, alpha=64, width=2.0, soft=True)
        s.line(trace, MINT, alpha=135, width=1.3)
        end = trace[-1]
        s.glow(end[0], end[1], 34, MINT, 0.45)
        s.dot(end[0], end[1], 4.4, MINT, 225)

    for x, y in [(60, 300), (250, 460), (620, 700), (520, 960), (560, 1270), (350, 860)]:
        s.dot(x, y, 7.0, MINT, 60, soft=True)

    # A large, very faint gear behind the field: configuration, at a glance.
    gx, gy, gr = 820, 340, 210
    for k in range(12):
        a0 = math.radians(k * 30)
        a1 = math.radians(k * 30 + 14)
        s.line(
            [(gx + gr * math.cos(a0), gy + gr * math.sin(a0)),
             (gx + (gr + 46) * math.cos(a0), gy + (gr + 46) * math.sin(a0))],
            MINT,
            alpha=40,
            width=10,
        )
        s.line(
            [(gx + gr * math.cos(a1), gy + gr * math.sin(a1)),
             (gx + (gr + 24) * math.cos(a1), gy + (gr + 24) * math.sin(a1))],
            MINT,
            alpha=26,
            width=6,
        )
    s.ring(gx, gy, gr, gr, MINT, alpha=44, width=2.4)
    s.ring(gx, gy, gr * 0.55, gr * 0.55, MINT, alpha=30, width=1.6)

    return s.save("bg_settings.jpg")


def plate_wave(name: str, hue: str, variant: int) -> str:
    """Landscape plates used behind cards and the splash.

    Kept in the same drawing language as the page plates so a screen never
    switches between a photo and a diagram.
    """
    s = Scene(1600, 1000, "010A18", "00121E", seed=variant)
    color = rgb(hue)

    cx, cy = 800, 500

    if variant % 3 == 0:  # orbital system
        s.glow(cx, cy, 760, color, 0.18)
        s.stars(220, color, area=(0, 0, 1600, 1000))
        rings = [(180, 66), (300, 112), (430, 160), (560, 210), (690, 258)]
        for rx, ry in rings:
            s.ring(cx, cy, rx, ry, color, alpha=54, width=4.0, tilt=-12, soft=True)
            s.ring(cx, cy, rx, ry, color, alpha=68, width=0.9, tilt=-12)
        s.arc(cx, cy, 430, 160, -40, 50, color, alpha=230, width=2.6, tilt=-12)
        for angle, size, tint in [
            (18, 11, color),
            (104, 7, AQUA),
            (168, 13, VIOLET),
            (232, 8, MINT),
            (300, 10, color),
        ]:
            a = math.radians(angle)
            rx, ry = rings[2] if abs(math.sin(a)) < 0.7 else rings[3]
            x = cx + rx * math.cos(a)
            y = cy + ry * math.sin(a) * math.cos(math.radians(12))
            s.glow(x, y, size * 10, tint, 0.55)
            s.dot(x, y, size, tint, 238)
        s.glow(cx, cy, 150, color, 0.30)
        s.dot(cx, cy, 22, color, 235)
    elif variant % 3 == 1:  # radar
        s.glow(cx, cy, 700, color, 0.16)
        s.stars(160, color, area=(0, 0, 1600, 1000))
        for i, r in enumerate([150, 260, 370, 480]):
            s.ring(cx, cy, r, r, color, alpha=40 + i * 8, width=1.0)
            s.ring(cx, cy, r, r, color, alpha=10, width=8.0, soft=True)
        s.line([(cx - 560, cy), (cx + 560, cy)], color, alpha=36)
        s.line([(cx, cy - 480), (cx, cy + 480)], color, alpha=36)
        for i in range(44):
            deg = -66 - i * 1.8
            a = math.radians(deg)
            s.line(
                [(cx, cy), (cx + 480 * math.cos(a), cy + 480 * math.sin(a))],
                color,
                alpha=int(58 * (1 - i / 44) ** 1.6),
                width=1.6,
            )
        a = math.radians(-66)
        s.line([(cx, cy), (cx + 478 * math.cos(a), cy + 478 * math.sin(a))], color, alpha=180, width=2.0)
        s.glow(cx + 452 * math.cos(a), cy + 452 * math.sin(a), 90, color, 0.35)
        for angle, dist, size, tint in [(30, 300, 7, RED), (150, 220, 5, GOLD), (255, 350, 5, AQUA)]:
            ang = math.radians(angle)
            x = cx + dist * math.cos(ang)
            y = cy + dist * math.sin(ang)
            s.glow(x, y, size * 12, tint, 0.45)
            s.dot(x, y, size, tint, 235)
            s.ring(x, y, size * 4.5, size * 4.5, tint, alpha=120, width=1.0)
    else:  # growth chart
        s.glow(cx, cy, 700, color, 0.16)
        s.stars(160, color, area=(0, 0, 1600, 1000))
        for j in range(6):
            y = 170 + j * 130
            s.line([(140, y), (1460, y)], color, alpha=20, width=1.0)
        baseline = 860
        heights = [150, 230, 200, 330, 300, 430, 500]
        for i, h in enumerate(heights):
            x = 240 + i * 170
            s.draw.rounded_rectangle(
                [x - 40, baseline - h, x + 40, baseline],
                radius=20 * SS,
                fill=(int(color[0]), int(color[1]), int(color[2]), 54),
                outline=(int(color[0]), int(color[1]), int(color[2]), 125),
                width=2 * SS,
            )
            s.draw.rounded_rectangle(
                [x - 40, baseline - h, x + 40, baseline - h + 26],
                radius=13 * SS,
                fill=(int(color[0]), int(color[1]), int(color[2]), 150),
            )
        s.line([(180, baseline + 40), (1430, baseline + 40)], color, alpha=44, width=1.6)
        points = [
            (240, 690), (410, 640), (580, 690), (750, 520),
            (920, 560), (1090, 380), (1260, 300),
        ]
        s.line(points, color, alpha=90, width=3.0, soft=True)
        s.line(points, color, alpha=200, width=2.2)
        for x, y in points:
            s.dot(x, y, 3.6, color, 220)
        s.glow(1260, 300, 110, color, 0.35)

    for i in range(-2, 12):
        s.line([(i * 150, 1000), (i * 150, 0)], color, alpha=12, width=0.8)

    return s.save(name)


# --------------------------------------------------------------------------
# emblems and illustrations
# --------------------------------------------------------------------------


def shield_points(cx, cy, w, h):
    """A shield outline as a smooth polygon: flat shoulders, curved flanks."""
    top = cy - h / 2
    left = cx - w / 2
    right = cx + w / 2

    pts: list[tuple[float, float]] = []
    pts.append((cx, top))
    pts.append((right - w * 0.03, top + h * 0.10))
    pts.append((right, top + h * 0.30))

    # Right flank curving in to the point.
    for i in range(1, 31):
        t = i / 30
        x = right - (w * 0.5) * (t**2.1)
        y = top + h * 0.30 + (h * 0.70) * t
        pts.append((x, y))

    # Left flank, mirrored.
    for i in range(29, -1, -1):
        t = i / 30
        x = left + (w * 0.5) * (t**2.1)
        y = top + h * 0.30 + (h * 0.70) * t
        pts.append((x, y))

    pts.append((left, top + h * 0.30))
    pts.append((left + w * 0.03, top + h * 0.10))
    return pts


def gradient_fill(size, color_a, color_b, vertical=True) -> Image.Image:
    w, h = size
    a = np.array(color_a, dtype=np.float32)
    b = np.array(color_b, dtype=np.float32)
    if vertical:
        ramp = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    else:
        ramp = np.linspace(0, 1, w, dtype=np.float32)[None, :, None]
    arr = a * (1 - ramp) + b * ramp
    arr = np.repeat(arr, w if vertical else h, axis=1 if vertical else 0)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def shield_emblem() -> str:
    size = 1024
    img, d = transparent(size, size)
    cx, cy = 512, 500
    w, h = 760, 880

    shape = shield_points(cx, cy, w, h)
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in shape], fill=255)

    fill = gradient_fill(
        (size * SS, size * SS), (16, 74, 120), (5, 24, 54)
    ).convert("RGBA")
    inner_light = Image.new("RGBA", fill.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(inner_light)
    ld.ellipse(
        [90 * SS, 60 * SS, 950 * SS, 720 * SS],
        fill=(0, 229, 255, 60),
    )
    inner_light = inner_light.filter(ImageFilter.GaussianBlur(90 * SS))
    fill.alpha_composite(inner_light)
    fill.putalpha(mask)
    img.alpha_composite(fill)

    # Rim: bright at the top, falling away toward the point.
    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.line(
        [(x * SS, y * SS) for x, y in shape + [shape[0]]],
        fill=(120, 240, 255, 235),
        width=9 * SS,
        joint="curve",
    )
    img.alpha_composite(rim)

    inner = Image.new("RGBA", img.size, (0, 0, 0, 0))
    idr = ImageDraw.Draw(inner)
    inset = shield_points(cx, cy, w * 0.86, h * 0.86)
    idr.line(
        [(x * SS, y * SS) for x, y in inset + [inset[0]]],
        fill=(0, 229, 255, 90),
        width=2 * SS,
        joint="curve",
    )
    # Circuit inlay: corners and short runs, echoing the page plates.
    for pts in (
        [(300, 330), (300, 420), (380, 420)],
        [(724, 330), (724, 420), (644, 420)],
        [(300, 700), (300, 620), (380, 620)],
        [(724, 700), (724, 620), (644, 620)],
    ):
        idr.line(
            [(x * SS, y * SS) for x, y in pts],
            fill=(0, 229, 255, 110),
            width=3 * SS,
            joint="curve",
        )
        for x, y in (pts[0], pts[-1]):
            idr.ellipse(
                [(x - 7) * SS, (y - 7) * SS, (x + 7) * SS, (y + 7) * SS],
                fill=(0, 229, 255, 170),
            )
    img.alpha_composite(inner)

    # A check: the brand mark, bold enough to read at 40px.
    check = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(check)
    points = [(382, 512), (472, 606), (648, 402)]
    cd.line(
        [(x * SS, y * SS) for x, y in points],
        fill=(255, 255, 255, 255),
        width=34 * SS,
        joint="curve",
    )
    for x, y in points:
        cd.ellipse(
            [(x - 17) * SS, (y - 17) * SS, (x + 17) * SS, (y + 17) * SS],
            fill=(255, 255, 255, 255),
        )
    img.alpha_composite(check)

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([160 * SS, 180 * SS, 864 * SS, 780 * SS], fill=(0, 229, 255, 46))
    glow = glow.filter(ImageFilter.GaussianBlur(60 * SS))
    return finish(img, "shield_emblem.png", glow)


def hero_burst(name: str, hue, symbol: str) -> str:
    """Alert-style hero art: rays behind a rounded plate carrying a mark."""
    size = 1200
    img, d = transparent(size, size)
    cx, cy = 600, 580

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [(cx - 420) * SS, (cy - 420) * SS, (cx + 420) * SS, (cy + 420) * SS],
        fill=hue + (80,),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(70 * SS))

    rays = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for i in range(24):
        angle = math.radians(i * 15)
        r0, r1 = 480, 480 + (130 if i % 2 == 0 else 65)
        rd.line(
            [
                ((cx + r0 * math.cos(angle)) * SS, (cy + r0 * math.sin(angle)) * SS),
                ((cx + r1 * math.cos(angle)) * SS, (cy + r1 * math.sin(angle)) * SS),
            ],
            fill=hue + (90,),
            width=5 * SS,
        )
    rays = rays.filter(ImageFilter.GaussianBlur(3 * SS))

    plate = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate)
    r = 430
    pd.rounded_rectangle(
        [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
        radius=90 * SS,
        fill=(10, 26, 45, 255),
        outline=hue + (200,),
        width=6 * SS,
    )
    pd.rounded_rectangle(
        [
            (cx - r + 26) * SS,
            (cy - r + 26) * SS,
            (cx + r - 26) * SS,
            (cy + r - 26) * SS,
        ],
        radius=70 * SS,
        outline=hue + (70,),
        width=2 * SS,
    )

    mark = Image.new("RGBA", img.size, (0, 0, 0, 0))
    md = ImageDraw.Draw(mark)
    if symbol == "triangle":
        tri = [(cx, cy - 240), (cx + 270, cy + 210), (cx - 270, cy + 210)]
        md.polygon([(x * SS, y * SS) for x, y in tri], fill=hue + (240,))
        md.line(
            [((x) * SS, (y) * SS) for x, y in tri + [tri[0]]],
            fill=(255, 255, 255, 110),
            width=4 * SS,
            joint="curve",
        )
        md.rounded_rectangle(
            [(cx - 26) * SS, (cy - 70) * SS, (cx + 26) * SS, (cy + 90) * SS],
            radius=22 * SS,
            fill=(10, 20, 34, 255),
        )
        md.ellipse(
            [(cx - 30) * SS, (cy + 118) * SS, (cx + 30) * SS, (cy + 178) * SS],
            fill=(10, 20, 34, 255),
        )
    else:
        md.line(
            [
                ((cx - 110) * SS, (cy + 10) * SS),
                ((cx - 20) * SS, (cy + 100) * SS),
                ((cx + 130) * SS, (cy - 90) * SS),
            ],
            fill=(255, 255, 255, 240),
            width=44 * SS,
            joint="curve",
        )
        for x, y in [(cx - 110, cy + 10), (cx - 20, cy + 100), (cx + 130, cy - 90)]:
            md.ellipse(
                [(x - 22) * SS, (y - 22) * SS, (x + 22) * SS, (y + 22) * SS],
                fill=(255, 255, 255, 240),
            )

    img.alpha_composite(rays)
    img.alpha_composite(plate)
    img.alpha_composite(mark)
    return finish(img, name, glow)


def globe_illustration() -> str:
    size = 1200
    img, d = transparent(size, size)
    cx, cy, r = 600, 600, 300

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [(cx - 420) * SS, (cy - 420) * SS, (cx + 420) * SS, (cy + 420) * SS],
        fill=(0, 180, 220, 80),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(80 * SS))

    # Sphere: lit from the top-left, so it reads as a world, not a disc.
    sphere = gradient_fill((size * SS, size * SS), (26, 120, 170), (3, 16, 40)).convert("RGBA")
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).ellipse(
        [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=255
    )
    sphere.putalpha(mask)
    img.alpha_composite(sphere)

    lines = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for i in range(1, 6):
        y = cy - r + (2 * r) * i / 6
        hw = math.sqrt(max(0.0, r**2 - (y - cy) ** 2))
        ld.ellipse(
            [(cx - hw) * SS, (y - hw * 0.22) * SS, (cx + hw) * SS, (y + hw * 0.22) * SS],
            outline=(150, 240, 255, 90),
            width=2 * SS,
        )
    for i in range(-2, 3):
        hw = abs(i) / 3 * r
        ld.ellipse(
            [(cx - hw) * SS, (cy - r) * SS, (cx + hw) * SS, (cy + r) * SS],
            outline=(150, 240, 255, 80),
            width=2 * SS,
        )
    ld.ellipse(
        [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
        outline=(150, 245, 255, 240),
        width=5 * SS,
    )
    # A specular edge on the upper left, so the sphere reads as lit.
    ld.arc(
        [(cx - r + 14) * SS, (cy - r + 14) * SS, (cx + r - 14) * SS, (cy + r - 14) * SS],
        start=185,
        end=290,
        fill=(235, 255, 255, 200),
        width=7 * SS,
    )
    img.alpha_composite(lines)

    # Orbit with satellite nodes.
    orbit = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(orbit)
    od.ellipse(
        [(cx - 470) * SS, (cy - 180) * SS, (cx + 470) * SS, (cy + 180) * SS],
        outline=(0, 229, 255, 120),
        width=3 * SS,
    )
    img.alpha_composite(orbit)

    for angle, color in [(20, CYAN), (150, MINT), (250, VIOLET), (320, AQUA)]:
        a = math.radians(angle)
        x = cx + 470 * math.cos(a)
        y = cy + 180 * math.sin(a)
        node = Image.new("RGBA", img.size, (0, 0, 0, 0))
        nd = ImageDraw.Draw(node)
        nd.rounded_rectangle(
            [(x - 58) * SS, (y - 58) * SS, (x + 58) * SS, (y + 58) * SS],
            radius=24 * SS,
            fill=(8, 32, 52, 250),
            outline=color + (235,),
            width=4 * SS,
        )
        nd.ellipse([(x - 22) * SS, (y - 22) * SS, (x + 22) * SS, (y + 22) * SS], fill=color + (235,))
        nd.ellipse([(x - 34) * SS, (y - 34) * SS, (x + 34) * SS, (y + 34) * SS], outline=color + (110,), width=2 * SS)
        img.alpha_composite(node)

    dots = [(505, 505), (660, 470), (700, 660), (560, 730), (640, 580)]
    dd = ImageDraw.Draw(img)
    for x, y in dots:
        dd.ellipse([(x - 9) * SS, (y - 9) * SS, (x + 9) * SS, (y + 9) * SS], fill=(255, 255, 255, 210))

    return finish(img, "onboarding_connected_world.png", glow)


def radar_illustration() -> str:
    size = 1200
    img, d = transparent(size, size)
    cx, cy = 600, 580

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [(cx - 400) * SS, (cy - 400) * SS, (cx + 400) * SS, (cy + 400) * SS],
        fill=(0, 200, 200, 80),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(80 * SS))

    rings = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    for i, r in enumerate([120, 210, 300, 390]):
        rd.ellipse(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
            outline=(120, 240, 235, 90 + i * 20),
            width=2 * SS,
        )
    rd.line([(cx - 420) * SS, cy * SS, (cx + 420) * SS, cy * SS], fill=(120, 240, 235, 50), width=2 * SS)
    rd.line([cx * SS, (cy - 420) * SS, cx * SS, (cy + 420) * SS], fill=(120, 240, 235, 50), width=2 * SS)
    img.alpha_composite(rings)

    sweep = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sweep)
    for i in range(30):
        deg = -100 - i * 2.2
        a = math.radians(deg)
        sd.line(
            [(cx * SS, cy * SS), ((cx + 390 * math.cos(a)) * SS, (cy + 390 * math.sin(a)) * SS)],
            fill=(43, 224, 200, int(70 * (1 - i / 30))),
            width=3 * SS,
        )
    img.alpha_composite(sweep)

    for angle, dist, color, radius in [(35, 300, RED, 22), (150, 240, GOLD, 16), (265, 350, AQUA, 14)]:
        a = math.radians(angle)
        x = cx + dist * math.cos(a)
        y = cy + dist * math.sin(a)
        ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
        rdd = ImageDraw.Draw(ring)
        rdd.ellipse(
            [(x - radius * 2.4) * SS, (y - radius * 2.4) * SS, (x + radius * 2.4) * SS, (y + radius * 2.4) * SS],
            outline=color + (120,),
            width=2 * SS,
        )
        rdd.ellipse(
            [(x - radius) * SS, (y - radius) * SS, (x + radius) * SS, (y + radius) * SS],
            fill=color + (235,),
        )
        img.alpha_composite(ring)

    shield = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sdw = ImageDraw.Draw(shield)
    pts = shield_points(cx, cy + 6, 230, 270)
    sdw.polygon([(x * SS, y * SS) for x, y in pts], fill=(6, 26, 44, 245))
    sdw.line(
        [(x * SS, y * SS) for x, y in pts + [pts[0]]],
        fill=(120, 240, 255, 235),
        width=5 * SS,
        joint="curve",
    )
    sdw.line(
        [(cx - 46) * SS, (cy + 10) * SS, (cx - 6) * SS, (cy + 56) * SS, (cx + 62) * SS, (cy - 40) * SS],
        fill=(255, 255, 255, 245),
        width=22 * SS,
        joint="curve",
    )
    img.alpha_composite(shield)

    return finish(img, "onboarding_threat_detection.png", glow)


def privacy_illustration() -> str:
    size = 1200
    img, d = transparent(size, size)
    cx, cy = 600, 580

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [(cx - 390) * SS, (cy - 390) * SS, (cx + 390) * SS, (cy + 390) * SS],
        fill=(120, 90, 255, 80),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(80 * SS))

    for r, alpha in [(400, 95), (470, 55), (540, 28)]:
        circle = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(circle).ellipse(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
            outline=(150, 170, 255, alpha),
            width=2 * SS,
        )
        img.alpha_composite(circle)

    shield = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shield)
    pts = shield_points(cx, cy, 480, 560)
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    fill = gradient_fill((size * SS, size * SS), (58, 40, 128), (8, 18, 44)).convert("RGBA")
    fill.putalpha(mask)
    shield.alpha_composite(fill)
    sd.line(
        [(x * SS, y * SS) for x, y in pts + [pts[0]]],
        fill=(170, 170, 255, 235),
        width=5 * SS,
        joint="curve",
    )
    # Padlock.
    sd.rounded_rectangle(
        [(cx - 78) * SS, (cy - 20) * SS, (cx + 78) * SS, (cy + 116) * SS],
        radius=22 * SS,
        fill=(235, 235, 255, 245),
    )
    sd.arc(
        [(cx - 54) * SS, (cy - 120) * SS, (cx + 54) * SS, (cy + 20) * SS],
        start=180,
        end=360,
        fill=(235, 235, 255, 245),
        width=16 * SS,
    )
    sd.ellipse([(cx - 12) * SS, (cy + 26) * SS, (cx + 12) * SS, (cy + 50) * SS], fill=(30, 30, 70, 255))
    sd.rounded_rectangle(
        [(cx - 8) * SS, (cy + 44) * SS, (cx + 8) * SS, (cy + 80) * SS],
        radius=6 * SS,
        fill=(30, 30, 70, 255),
    )
    img.alpha_composite(shield)

    for angle, color in [(35, CYAN), (145, AQUA), (230, GOLD), (315, MINT)]:
        a = math.radians(angle)
        x = cx + 400 * math.cos(a)
        y = cy + 400 * math.sin(a)
        node = Image.new("RGBA", img.size, (0, 0, 0, 0))
        nd = ImageDraw.Draw(node)
        nd.ellipse([(x - 20) * SS, (y - 20) * SS, (x + 20) * SS, (y + 20) * SS], fill=color + (220,))
        nd.ellipse([(x - 44) * SS, (y - 44) * SS, (x + 44) * SS, (y + 44) * SS], outline=color + (110,), width=2 * SS)
        img.alpha_composite(node)

    return finish(img, "onboarding_privacy_protection.png", glow)


def privacy_check_art() -> str:
    size = 1200
    img, d = transparent(size, size)
    cx, cy = 600, 580

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [(cx - 380) * SS, (cy - 380) * SS, (cx + 380) * SS, (cy + 380) * SS],
        fill=(0, 220, 200, 70),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(80 * SS))

    shield = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shield)
    pts = shield_points(cx, cy, 380, 450)
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    fill = gradient_fill((size * SS, size * SS), (14, 96, 108), (4, 20, 40)).convert("RGBA")
    fill.putalpha(mask)
    shield.alpha_composite(fill)
    sd.line(
        [(x * SS, y * SS) for x, y in pts + [pts[0]]],
        fill=(140, 255, 240, 235),
        width=5 * SS,
        joint="curve",
    )
    # An eye: what is looked at, and what looks back. Almond outline, drawn as
    # two mirrored arcs rather than an ellipse, so it reads at 80px.
    for direction in (1, -1):
        eye = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(eye).arc(
            [(cx - 165) * SS, (cy - 118) * SS, (cx + 165) * SS, (cy + 118) * SS],
            start=0 if direction > 0 else 180,
            end=180 if direction > 0 else 360,
            fill=(190, 255, 245, 225),
            width=5 * SS,
        )
        img.alpha_composite(eye)
    sd.ellipse(
        [(cx - 62) * SS, (cy - 62) * SS, (cx + 62) * SS, (cy + 62) * SS],
        outline=(190, 255, 245, 235),
        width=5 * SS,
    )
    sd.ellipse([(cx - 22) * SS, (cy - 22) * SS, (cx + 22) * SS, (cy + 22) * SS], fill=(190, 255, 245, 245))
    sd.ellipse(
        [(cx - 150) * SS, (cy - 40) * SS, (cx - 96) * SS, (cy + 14) * SS],
        fill=(190, 255, 245, 70),
    )
    img.alpha_composite(shield)

    for angle, color in [(20, CYAN), (160, MINT), (250, VIOLET)]:
        a = math.radians(angle)
        x = cx + 380 * math.cos(a)
        y = cy + 400 * math.sin(a)
        node = Image.new("RGBA", img.size, (0, 0, 0, 0))
        nd = ImageDraw.Draw(node)
        nd.ellipse([(x - 16) * SS, (y - 16) * SS, (x + 16) * SS, (y + 16) * SS], fill=color + (220,))
        nd.ellipse([(x - 40) * SS, (y - 40) * SS, (x + 40) * SS, (y + 40) * SS], outline=color + (100,), width=2 * SS)
        img.alpha_composite(node)

    return finish(img, "privacy_security_illustration.png", glow)


def mountain_night() -> str:
    s = Scene(1600, 1100, "01101F", "041A2B", seed=57)
    s.glow(800, 260, 620, CYAN, 0.12)
    s.stars(320, CYAN, area=(0, 0, 1600, 700))

    # A moon, low enough to light the nearest ridge.
    s.glow(1180, 250, 260, CYAN, 0.16)
    s.glow(1180, 250, 120, CYAN, 0.20)

    # Ridges from summed sines: smooth, natural silhouettes instead of the
    # sawtooth a random-walk produces.
    layers = [
        (760, (11, 42, 68), 215, 150, 0.0),
        (900, (8, 30, 50), 240, 190, 1.7),
        (1040, (4, 16, 30), 255, 150, 3.1),
    ]
    for base_y, color, alpha, amp, phase in layers:
        ridge = []
        for x in range(0, 1601, 16):
            h = (
                0.55 * math.sin(x / 260 + phase)
                + 0.28 * math.sin(x / 121 + phase * 2.3)
                + 0.17 * math.sin(x / 53 + phase * 4.1)
            )
            ridge.append((x, base_y - (0.5 - 0.5 * h) * amp))
        pts = ridge + [(1600, 1100), (0, 1100)]
        layer = Image.new("RGBA", (1600 * SS, 1100 * SS), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(
            [(px * SS, py * SS) for px, py in pts], fill=color + (alpha,)
        )
        s.layer.alpha_composite(layer)
        # Rim light along the crest: what makes a silhouette read as a ridge.
        s.line(ridge, CYAN, alpha=70, width=1.6)
        s.line(ridge, CYAN, alpha=26, width=5.0, soft=True)

    for i in range(0, 17):
        s.line([(i * 100, 1100), (800 + (i * 100 - 800) * 0.12, 940)], CYAN, alpha=22, width=0.9)
    for j in range(1, 5):
        s.line([(0, 940 + j * 32), (1600, 940 + j * 32)], CYAN, alpha=16, width=0.9)

    return s.save("cyber_mountain_night.jpg")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    written = [
        bg_home(),
        bg_threats(),
        bg_reports(),
        bg_settings(),
        plate_wave("cyber_navy_wave.jpg", "1E7CFF", 0),
        plate_wave("cyber_teal_glow.jpg", "2BE0C8", 1),
        plate_wave("cyber_violet_glow.jpg", "7C5CFF", 2),
        shield_emblem(),
        hero_burst("critical_threat_hero.png", RED, "triangle"),
        privacy_check_art(),
        globe_illustration(),
        radar_illustration(),
        privacy_illustration(),
        mountain_night(),
    ]
    for path in written:
        size = os.path.getsize(path) // 1024
        print(f"{path:52s} {size:5d} KB")


if __name__ == "__main__":
    main()
