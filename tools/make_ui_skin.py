#!/usr/bin/env python3
"""Generate the menu skin (original artwork): textured panels, bevelled buttons, parchment
rows, tabs, research banners and shaded resource icons, replacing flat colour boxes.

Usage: python3 tools/make_ui_skin.py game/assets/interface
Writes skin/*.png (9-patch pieces; margins are set in scripts/cow_ui.gd) and res_*.png icons.
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageChops

rng = random.Random(7)


def noise(size, amount, blur=0.0):
    n = Image.effect_noise(size, amount).convert("L")
    return n.filter(ImageFilter.GaussianBlur(blur)) if blur else n


def vgradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return img


def grain(img, strength=0.06, blur=0.6):
    n = noise(img.size, 40, blur).convert("RGBA")
    out = Image.blend(img, n, strength)
    out.putalpha(img.getchannel("A"))
    return out


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return m


def button(path, top, bottom, border, radius=10, size=(96, 64)):
    img = vgradient(size, top, bottom)
    img = grain(img, 0.05)
    d = ImageDraw.Draw(img)
    w, h = size
    # Glossy top half highlight and a dark lower lip (bevel).
    gloss = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([3, 3, w - 4, h // 2], radius - 3, fill=(255, 255, 255, 38))
    img = Image.alpha_composite(img, gloss)
    d = ImageDraw.Draw(img)
    d.line([(radius, 2), (w - radius, 2)], fill=(255, 255, 255, 90), width=2)
    d.line([(radius, h - 4), (w - radius, h - 4)], fill=(0, 0, 0, 70), width=3)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius, outline=border + (255,), width=2)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), rounded_mask(size, radius)))
    img.save(path)


def panel(path, top, bottom, edge, size=(96, 96), radius=0):
    img = vgradient(size, top, bottom)
    # Brushed-metal streaks.
    streak = noise((size[0] * 4, size[1]), 60).resize(size).filter(ImageFilter.BoxBlur(1))
    streak = streak.transform(size, Image.AFFINE, (1, 0, 0, 0, 0.15, 0)).convert("RGBA")
    img = Image.blend(img, streak, 0.05)
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (size[0], 0)], fill=edge + (255,), width=1)
    d.line([(0, size[1] - 1), (size[0], size[1] - 1)], fill=(0, 0, 0, 255), width=1)
    if radius:
        img.putalpha(rounded_mask(size, radius))
    img.save(path)


def inset(path, size=(96, 96)):
    img = vgradient(size, (20, 23, 26), (30, 34, 38))
    img = grain(img, 0.04)
    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(6):
        sd.rectangle([i, i, size[0] - 1 - i, size[1] - 1 - i], outline=(0, 0, 0, 110 - i * 18))
    img = Image.alpha_composite(img, shade)
    ImageDraw.Draw(img).rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(88, 92, 94, 255), width=1)
    img.putalpha(rounded_mask(size, 6))
    img.save(path)


def parchment(path, size=(128, 96), dark=False):
    top, bottom = ((206, 200, 180), (190, 183, 161)) if dark else ((228, 223, 205), (212, 206, 186))
    img = vgradient(size, top, bottom)
    img = grain(img, 0.07, 0.8)
    d = ImageDraw.Draw(img)
    if not dark:
        d.line([(0, 0), (size[0], 0)], fill=(246, 243, 232, 255), width=2)
        d.line([(0, size[1] - 2), (size[0], size[1] - 2)], fill=(150, 143, 120, 255), width=2)
        d.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(156, 149, 126, 255), width=1)
    img.save(path)


def tab(path, selected, size=(96, 72)):
    img = vgradient(size, (62, 66, 68) if selected else (40, 44, 47), (44, 47, 50) if selected else (30, 33, 35))
    img = grain(img, 0.04)
    d = ImageDraw.Draw(img)
    if selected:
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rectangle([0, size[1] - 14, size[0], size[1]], fill=(233, 196, 106, 70))
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(5)))
        d = ImageDraw.Draw(img)
        d.rectangle([0, size[1] - 4, size[0], size[1]], fill=(233, 196, 106, 255))
    d.line([(size[0] - 1, 6), (size[0] - 1, size[1] - 6)], fill=(20, 22, 24, 255))
    img.save(path)


def frame(path, size=(64, 64)):
    img = vgradient(size, (58, 63, 67), (36, 40, 43))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], 5, outline=(171, 140, 72, 255), width=3)
    d.rounded_rectangle([4, 4, size[0] - 5, size[1] - 5], 3, outline=(20, 22, 24, 255), width=1)
    img.putalpha(rounded_mask(size, 5))
    img.save(path)


def star(cx, cy, r, inner=0.42, turn=-math.pi / 2):
    pts = []
    for i in range(10):
        rad = r if i % 2 == 0 else r * inner
        a = turn + i * math.pi / 5
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def banner(path, tint, size=(720, 160)):
    w, h = size
    img = Image.new("RGBA", size, (232, 229, 216, 255))
    px = img.load()
    for x in range(w):
        t = max(0.0, (x / w - 0.25) / 0.75)
        for y in range(h):
            base = px[x, y]
            px[x, y] = tuple(int(base[i] + (tint[i] - base[i]) * t * 0.55) for i in range(3)) + (255,)
    emblem = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(emblem).polygon(star(w * 0.72, h * 0.5, h * 0.95), fill=(214, 190, 92, 120))
    img = Image.alpha_composite(img, emblem.filter(ImageFilter.GaussianBlur(2)))
    sparks = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sparks)
    for _ in range(70):
        x, y = rng.uniform(w * 0.35, w), rng.uniform(0, h)
        r = rng.uniform(0.6, 2.2)
        sd.ellipse([x - r, y - r, x + r, y + r], fill=(255, 205, 120, rng.randint(60, 160)))
    img = Image.alpha_composite(img, sparks.filter(ImageFilter.GaussianBlur(0.6)))
    img = grain(img, 0.05, 0.8)
    ImageDraw.Draw(img).rectangle([0, 0, w - 1, h - 1], outline=(120, 112, 90, 255), width=2)
    img.save(path)


# --- shaded resource icons -------------------------------------------------------------
S, SS = 128, 4


def icon_canvas():
    img = Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4 * SS, 6 * SS, (S - 4) * SS, (S - 2) * SS], fill=(0, 0, 0, 90))  # drop shadow
    d.ellipse([4 * SS, 4 * SS, (S - 4) * SS, (S - 6) * SS], fill=(28, 32, 34, 240), outline=(214, 190, 120, 255), width=5 * SS)
    return img, d


def P(x, y):
    return (x * SS, y * SS)


def shade_poly(img, pts, light, dark):
    """Fill a polygon with a top-left light to bottom-right dark gradient."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon([P(*p) for p in pts], fill=255)
    grad = Image.linear_gradient("L").rotate(45, expand=False).resize(img.size)
    fill = Image.composite(Image.new("RGBA", img.size, light + (255,)), Image.new("RGBA", img.size, dark + (255,)), ImageChops.invert(grad))
    img.paste(fill, (0, 0), mask)


def icons(out):
    result = {}
    img, d = icon_canvas()  # funds: banknote stack
    for k, dy in enumerate((10, 4, -2)):
        shade_poly(img, [(28, 50 + dy), (100, 44 + dy), (102, 72 + dy), (30, 78 + dy)], (150, 206, 120), (60, 120, 52))
        d.line([P(28, 50 + dy), P(100, 44 + dy), P(102, 72 + dy), P(30, 78 + dy), P(28, 50 + dy)], fill=(36, 80, 32), width=2 * SS)
    d.ellipse([P(58, 50), P(72, 64)], fill=(206, 236, 186), outline=(60, 120, 52), width=2 * SS)
    result["funds"] = img
    img, d = icon_canvas()  # materials: steel ingot
    shade_poly(img, [(30, 56), (86, 42), (100, 52), (44, 68)], (228, 232, 238), (150, 158, 170))
    shade_poly(img, [(44, 68), (100, 52), (100, 72), (44, 90)], (150, 158, 170), (92, 98, 110))
    shade_poly(img, [(30, 56), (44, 68), (44, 90), (30, 76)], (120, 126, 138), (78, 84, 96))
    result["materials"] = img
    img, d = icon_canvas()  # electronics: chip with gold pins
    for i in range(4):
        o = 46 + i * 12
        for a, b in (((o, 34), (o, 44)), ((o, 84), (o, 94)), ((34, o), (44, o)), ((84, o), (94, o))):
            d.line([P(*a), P(*b)], fill=(226, 186, 92), width=4 * SS)
    shade_poly(img, [(42, 42), (86, 42), (86, 86), (42, 86)], (88, 140, 158), (34, 70, 84))
    d.rectangle([P(54, 54), P(74, 74)], outline=(160, 210, 222), width=2 * SS)
    result["electronics"] = img
    img, d = icon_canvas()  # fuel: jerrycan
    shade_poly(img, [(40, 44), (54, 30), (88, 30), (88, 98), (40, 98)], (236, 92, 78), (150, 30, 26))
    d.line([P(52, 56), P(78, 86)], fill=(255, 196, 186), width=4 * SS)
    d.line([P(78, 56), P(52, 86)], fill=(255, 196, 186), width=4 * SS)
    d.rounded_rectangle([P(60, 24), P(80, 32)], 2 * SS, fill=(120, 26, 22))
    result["fuel"] = img
    img, d = icon_canvas()  # manpower: helmet
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).pieslice([P(32, 36), P(96, 100)], 180, 360, fill=255)
    grad = Image.linear_gradient("L").resize(img.size)
    fill = Image.composite(Image.new("RGBA", img.size, (90, 104, 58, 255)), Image.new("RGBA", img.size, (162, 178, 110, 255)), grad)
    img.paste(fill, (0, 0), mask)
    d.line([P(26, 68), P(102, 68)], fill=(70, 82, 44), width=7 * SS)
    d.arc([P(40, 42), P(88, 90)], 205, 250, fill=(210, 220, 170), width=3 * SS)
    result["manpower"] = img
    for name, image in result.items():
        image.resize((S, S), Image.LANCZOS).save(f"{out}/res_{name}.png", optimize=True)


def main():
    out = sys.argv[1]
    skin = out + "/skin"
    button(f"{skin}/btn_green.png", (110, 170, 78), (52, 104, 38), (30, 64, 22))
    button(f"{skin}/btn_green_pressed.png", (60, 112, 44), (84, 140, 62), (30, 64, 22))
    button(f"{skin}/btn_red.png", (214, 94, 82), (150, 46, 40), (90, 26, 22))
    button(f"{skin}/btn_grey.png", (150, 150, 142), (110, 110, 104), (70, 70, 66))
    button(f"{skin}/btn_dark.png", (70, 76, 80), (44, 48, 52), (20, 22, 24))
    panel(f"{skin}/panel_dark.png", (44, 48, 52), (30, 33, 36), (78, 84, 88))
    panel(f"{skin}/header.png", (34, 37, 40), (22, 24, 26), (60, 64, 66))
    inset(f"{skin}/inset.png")
    parchment(f"{skin}/row.png")
    parchment(f"{skin}/list.png", dark=True)
    tab(f"{skin}/tab_on.png", True)
    tab(f"{skin}/tab_off.png", False)
    frame(f"{skin}/frame.png")
    banner(f"{skin}/banner_russia.png", (196, 70, 60))
    banner(f"{skin}/banner_ukraine.png", (60, 110, 190))
    icons(out)


if __name__ == "__main__":
    main()
