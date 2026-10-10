#!/usr/bin/env python3
"""Draw the map resource icons (original artwork, same look as the HUD's resource glyphs).

Usage: python3 tools/make_resource_icons.py game/assets/interface
Writes res_funds.png, res_materials.png, res_electronics.png, res_fuel.png, res_manpower.png:
a dark round badge with the resource symbol, readable at 18-24 px.
"""
import sys

from PIL import Image, ImageDraw

S = 128
SS = 4  # supersampling


def badge():
    img = Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4 * SS, 4 * SS, (S - 4) * SS, (S - 4) * SS], fill=(18, 22, 24, 230), outline=(222, 214, 186, 255), width=5 * SS)
    return img, d


def p(x, y):
    return (x * SS, y * SS)


def main():
    out = sys.argv[1]
    icons = {}
    img, d = badge()  # funds: banknote
    d.rectangle([p(30, 44), p(98, 84)], fill=(79, 154, 69), outline=(45, 95, 40), width=3 * SS)
    d.ellipse([p(55, 55), p(73, 73)], fill=(159, 209, 143))
    icons["funds"] = img
    img, d = badge()  # materials: crate
    d.rectangle([p(34, 36), p(94, 92)], fill=(154, 107, 60), outline=(94, 61, 29), width=4 * SS)
    d.line([p(34, 36), p(94, 92)], fill=(94, 61, 29), width=4 * SS)
    d.line([p(94, 36), p(34, 92)], fill=(94, 61, 29), width=4 * SS)
    icons["materials"] = img
    img, d = badge()  # electronics: chip
    d.rectangle([p(44, 44), p(84, 84)], fill=(61, 107, 122))
    for i in range(3):
        o = 52 + i * 12
        for a, b in (((o, 36), (o, 44)), ((o, 84), (o, 92)), ((36, o), (44, o)), ((84, o), (92, o))):
            d.line([p(*a), p(*b)], fill=(159, 196, 207), width=4 * SS)
    icons["electronics"] = img
    img, d = badge()  # fuel: jerrycan
    d.polygon([p(42, 46), p(54, 34), p(86, 34), p(86, 94), p(42, 94)], fill=(200, 53, 46))
    d.line([p(52, 56), p(76, 84)], fill=(255, 179, 168), width=4 * SS)
    d.line([p(76, 56), p(52, 84)], fill=(255, 179, 168), width=4 * SS)
    icons["fuel"] = img
    img, d = badge()  # manpower: helmet
    d.pieslice([p(36, 42), p(92, 98)], 180, 360, fill=(122, 138, 78))
    d.line([p(30, 70), p(98, 70)], fill=(85, 98, 58), width=7 * SS)
    icons["manpower"] = img
    for name, image in icons.items():
        image.resize((S, S), Image.LANCZOS).save(f"{out}/res_{name}.png", optimize=True)


if __name__ == "__main__":
    main()
