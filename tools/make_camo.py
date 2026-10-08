#!/usr/bin/env python3
"""Generate the Su-57-inspired blue camouflage used on Russian equipment (original artwork).

Usage: python3 tools/make_camo.py game/assets/materials/russian_blue_camo.png

Pale grey-blue base with angular splinter patches in mid blue-grey and dark slate blue,
like the Su-57's scheme. The texture tiles seamlessly (every patch is drawn with wrap-around).
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BASE = (172, 188, 201)
MID = (118, 142, 166)
DARK = (70, 89, 112)
LIGHT = (198, 210, 219)


def splinter(rng, cx, cy, length, width):
    """An angular sliver: a skewed quadrilateral/pentagon with straight edges."""
    import math
    angle = rng.uniform(-0.7, 0.7) + (math.pi / 2 if rng.random() < 0.35 else 0.0)
    ca, sa = math.cos(angle), math.sin(angle)
    pts = [(-length / 2, -width * rng.uniform(0.3, 0.6)), (length * rng.uniform(0.1, 0.3), -width / 2),
           (length / 2, width * rng.uniform(-0.2, 0.2)), (length * rng.uniform(-0.1, 0.2), width / 2),
           (-length * rng.uniform(0.35, 0.5), width * rng.uniform(0.2, 0.5))]
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def draw_wrapped(draw, poly, color):
    for dx in (-SIZE, 0, SIZE):
        for dy in (-SIZE, 0, SIZE):
            draw.polygon([(x + dx, y + dy) for x, y in poly], fill=color)


def main():
    out = sys.argv[1]
    rng = random.Random(57)
    img = Image.new("RGB", (SIZE, SIZE), BASE)
    d = ImageDraw.Draw(img)
    for color, count, size in ((MID, 46, (190, 70)), (DARK, 30, (150, 48)), (LIGHT, 18, (120, 36))):
        for _ in range(count):
            cx, cy = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
            draw_wrapped(d, splinter(rng, cx, cy, rng.uniform(size[0] * 0.6, size[0] * 1.3),
                                     rng.uniform(size[1] * 0.6, size[1] * 1.3)), color)
    # Light paint grain so the surface does not look like flat vector art.
    noise = Image.effect_noise((SIZE, SIZE), 10).convert("L").filter(ImageFilter.GaussianBlur(0.6))
    img = Image.blend(img, Image.merge("RGB", (noise, noise, noise)), 0.06)
    img.save(out, optimize=True)


if __name__ == "__main__":
    main()
