#!/usr/bin/env python3
"""Generate the woodland camouflage used on Ukrainian ground equipment (original artwork).

Usage: python3 tools/make_camo_ukraine.py game/assets/materials/ukraine_woodland_camo.png

Olive-green base with soft-edged brown, black and light-green blotches, like the green /
brown / black schemes on Ukrainian armour. The texture tiles seamlessly.
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BASE = (86, 96, 56)
BROWN = (92, 70, 44)
BLACK = (32, 33, 27)
LIGHT = (122, 130, 76)


def blob(rng, cx, cy, radius):
    points = []
    count = 14
    phase = rng.random() * math.tau
    for i in range(count):
        a = math.tau * i / count
        r = radius * (0.65 + 0.35 * math.sin(3 * a + phase) + rng.uniform(-0.15, 0.15))
        points.append((cx + math.cos(a) * r * 1.6, cy + math.sin(a) * r))
    return points


def draw_wrapped(draw, poly, color):
    for dx in (-SIZE, 0, SIZE):
        for dy in (-SIZE, 0, SIZE):
            draw.polygon([(x + dx, y + dy) for x, y in poly], fill=color)


def main():
    rng = random.Random(1991)
    img = Image.new("RGB", (SIZE, SIZE), BASE)
    d = ImageDraw.Draw(img)
    for color, count, radius in ((BROWN, 34, 85), (LIGHT, 18, 55), (BLACK, 26, 50)):
        for _ in range(count):
            draw_wrapped(d, blob(rng, rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(radius * 0.6, radius * 1.3)), color)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    noise = Image.effect_noise((SIZE, SIZE), 10).convert("L").filter(ImageFilter.GaussianBlur(0.6))
    img = Image.blend(img, Image.merge("RGB", (noise, noise, noise)), 0.05)
    img.save(sys.argv[1], optimize=True)


if __name__ == "__main__":
    main()
