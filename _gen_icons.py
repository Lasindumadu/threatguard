# Generates ThreatGuard launcher icon assets with Pillow.
# Design: diagonal navy-teal gradient + cyan glow, white shield, cyan inner
# shield, white check mark. Supersampled 4x for crisp edges.
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "assets", "icons")
os.makedirs(OUT, exist_ok=True)

FULL = 4096          # supersample canvas
FINAL = 1024         # export size

# Brand palette (matches lib/core/theme/app_theme.dart)
NAVY_TOP = (20, 82, 110)      # slightly lifted #14526E
NAVY_BOT = (10, 35, 49)       # #0A2331
CYAN = (0, 184, 212)          # #00B8D4

SS = np.linspace(0.0, 1.0, FULL, dtype=np.float32)
Xg, Yg = np.meshgrid(SS, SS)

# --- Background: diagonal gradient (top-left -> bottom-right) ---
t = (Xg + Yg) / 2.0
bg = np.empty((FULL, FULL, 3), dtype=np.float32)
for c in range(3):
    bg[:, :, c] = NAVY_TOP[c] * (1 - t) + NAVY_BOT[c] * t

# --- Soft cyan glow in the upper-right ---
gx, gy, rg = 0.72, 0.20, 0.55
d = np.sqrt((Xg - gx) ** 2 + (Yg - gy) ** 2)
glow = np.clip(1.0 - (d / rg) ** 2, 0.0, 1.0) ** 1.6 * 0.34
for c in range(3):
    bg[:, :, c] = bg[:, :, c] * (1 - glow) + CYAN[c] * glow
bg = np.clip(bg, 0, 255).astype(np.uint8)
base = Image.fromarray(bg, "RGB")


def shield_polygon(cx, cy_top, cy_bottom, half_w, steps=96):
    """Classic security shield: crest top, straight flanks, bezier bottom tip."""
    pts = []
    # top edge: left corner -> crest -> right corner
    x_l, x_r, x_c = cx - half_w, cx + half_w, cx
    y_corner = cy_top + half_w * 0.075
    pts += [(x_l, y_corner), (x_c, cy_top), (x_r, y_corner)]
    # right flank down
    y_flank = cy_top + (cy_bottom - cy_top) * 0.46
    pts += [(x_r, y_flank)]
    # bottom bezier: right flank -> tip -> left flank
    tip = (cx, cy_bottom)
    def bez(p0, p1, p2, p3, n):
        out = []
        for i in range(1, n + 1):
            u = i / n
            cu = 1 - u
            b = [cu**3 * a + 3 * cu * cu * u * b +
                 3 * cu * u * u * c + u**3 * dd
                 for a, b, c, dd in zip(p0, p1, p2, p3)]
            out.append(tuple(b))
        return out
    r0 = (x_r, y_flank)
    c1r = (x_r, y_flank + (cy_bottom - y_flank) * 0.62)
    c1b = (cx + half_w * 0.60, cy_bottom)
    l0 = (x_l, y_flank)
    c2l = (x_l, y_flank + (cy_bottom - y_flank) * 0.62)
    c2b = (cx - half_w * 0.60, cy_bottom)
    # right bezier down to tip
    pts += bez(r0, c1r, c1b, tip, steps // 2)
    # left bezier (mirrored) from tip back up
    left_curve = bez(tip, c2b, c2l, l0, steps // 2)
    pts += left_curve
    pts += [(x_l, y_flank)]
    return pts


def scale_about(pts, cx, cy, s):
    return [(cx + (x - cx) * s, cy + (y - cy) * s) for x, y in pts]


def draw_glyph(canvas, scale, alpha=255):
    """Draw shield + check onto RGBA canvas centered in unit square * scale."""
    W, H = canvas.size
    fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)

    cx, cy = 0.5 * W, 0.53 * H
    span = W * scale
    half_w = 0.26 * span
    shield = shield_polygon(cx, cy - 0.30 * span, cy + 0.31 * span, half_w)
    inner = scale_about(shield, cx, cy, 0.80)

    d.polygon(shield, fill=(255, 255, 255, alpha))
    d.polygon(inner, fill=(0, 184, 212, int(0.30 * alpha)))

    # check mark: thick polyline with round caps
    stroke = 0.062 * span
    a = (cx - 0.155 * span, cy - 0.055 * span)
    b = (cx - 0.045 * span, cy + 0.065 * span)
    c2 = (cx + 0.170 * span, cy - 0.150 * span)
    d.line([a, b, c2], fill=(255, 255, 255, alpha),
           width=int(stroke), joint="curve")
    r = stroke / 2
    for p in (a, c2):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r],
                  fill=(255, 255, 255, alpha))
    return Image.alpha_composite(canvas.convert("RGBA"), fg)


# 1) Full-bleed icon (legacy launcher + iOS)
full = draw_glyph(base, 0.98)
full.resize((FINAL, FINAL), Image.LANCZOS).save(
    os.path.join(OUT, "app_icon.png"))

# 2) Adaptive foreground: glyph on transparency, pulled into safe zone
fg_canvas = Image.new("RGBA", (FULL, FULL), (0, 0, 0, 0))
fg = draw_glyph(fg_canvas, 0.80, alpha=255)
fg.resize((FINAL, FINAL), Image.LANCZOS).save(
    os.path.join(OUT, "ic_launcher_foreground.png"))

# 3) Adaptive background tile (subtle radial depth, mostly uniform navy)
bg_small = Image.fromarray(
    np.clip(bg, 0, 255).astype(np.uint8), "RGB").resize((FINAL, FINAL),
                                                        Image.LANCZOS)
bg_small.save(os.path.join(OUT, "ic_launcher_background.png"))

for fn in ("app_icon.png", "ic_launcher_foreground.png",
           "ic_launcher_background.png"):
    p = os.path.join(OUT, fn)
    print(fn, os.path.getsize(p), "bytes")
print("done")
