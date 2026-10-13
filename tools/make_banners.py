"""Research banners in the Call of War style (owner 2026-10-13: "make better pictures").

Composites the transparent hero renders from game/tools/render_banner_heroes.gd onto a
painted backdrop: light gradient, flag-coloured rays, smoke and sparks.
    python3 tools/make_banners.py HERO_DIR game/assets/interface/banners
"""
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

W, H = 1400, 380
COLOURS = {"russia": [(200, 16, 46), (0, 57, 166)], "ukraine": [(0, 87, 183), (255, 200, 0)]}

def noise(w, h, scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, h // scale), max(2, w // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return img.filter(ImageFilter.GaussianBlur(scale / 3))

def backdrop(country, seed):
    rnd = random.Random(seed)
    x = np.linspace(0, 1, W)[None, :]
    y = np.linspace(0, 1, H)[:, None]
    base = np.zeros((H, W, 3))
    left, right = np.array([243, 244, 245]), np.array([214, 219, 226])
    base[:] = left * (1 - x[..., None]) + right * x[..., None]
    base -= (y[..., None] * 18)
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
    # Rays fanning out from behind the hero.
    rays = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(rays)
    cx, cy = W * 0.80, H * 0.42
    colours = COLOURS[country]
    n = 16
    for i in range(n):
        a0 = math.pi * 0.62 + i * (math.pi * 0.78 / n)
        a1 = a0 + math.pi * 0.78 / n * 0.55
        r = W * 1.2
        pts = [(cx, cy), (cx + r * math.cos(a0), cy - r * math.sin(a0) * 0.55), (cx + r * math.cos(a1), cy - r * math.sin(a1) * 0.55)]
        col = colours[i % 2]
        d.polygon(pts, fill=col + (70,))
    rays = rays.filter(ImageFilter.GaussianBlur(6))
    # Rays fade out towards the left so the title stays readable.
    fade = Image.fromarray((np.clip((x * 1.6 - 0.25), 0, 1) * np.ones((H, 1)) * 255).astype(np.uint8))
    rays.putalpha(ImageChops.multiply(rays.getchannel("A"), fade))
    img.alpha_composite(rays)
    # Smoke, heavier at the bottom right.
    smoke = noise(W, H, 60, seed)
    mask = np.asarray(smoke, dtype=float) / 255.0
    weight = np.clip(x * 1.3 - 0.2, 0, 1) * np.clip(y * 1.4 - 0.15, 0, 1)
    alpha = np.clip((mask - 0.35) * 2.2, 0, 1) * weight * 200
    layer = np.zeros((H, W, 4), dtype=np.uint8)
    layer[..., :3] = 96
    layer[..., 3] = alpha.astype(np.uint8)
    img.alpha_composite(Image.fromarray(layer))
    return img

def sparks(seed, density):
    rnd = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(density):
        px = W * (0.45 + 0.55 * rnd.random() ** 0.5)
        py = H * rnd.random()
        r = rnd.uniform(0.8, 2.4)
        warm = (255, rnd.randint(140, 210), rnd.randint(40, 90))
        d.ellipse([px - r, py - r, px + r, py + r], fill=warm + (rnd.randint(150, 255),))
    glow = layer.filter(ImageFilter.GaussianBlur(5))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(glow)
    out.alpha_composite(layer)
    return out

def hero_layer(path, group):
    hero = Image.open(path).convert("RGBA")
    hero = hero.crop(hero.getbbox())
    alpha = hero.getchannel("A")
    hero = ImageEnhance.Color(ImageEnhance.Contrast(hero.convert("RGB")).enhance(1.18)).enhance(1.12).convert("RGBA")
    hero.putalpha(alpha)
    target_h = H * (0.92 if group in (5,) else 0.78)
    target_w = W * 0.56
    s = min(target_h / hero.height, target_w / hero.width)
    hero = hero.resize((int(hero.width * s), int(hero.height * s)), Image.LANCZOS)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = int(W - hero.width - W * 0.03)
    y = int(H - hero.height - H * (0.02 if group == 5 else 0.08))
    # Soft ground shadow.
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([x + hero.width * 0.05, y + hero.height * 0.86, x + hero.width * 0.98, y + hero.height * 1.06], fill=(30, 30, 30, 120))
    if group != 1:  # aircraft fly; no ground shadow
        layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    layer.alpha_composite(hero, (x, y))
    return layer

def main(hero_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for country in COLOURS:
        for group in range(7):
            path = os.path.join(hero_dir, f"{country}_{group}.png")
            if not os.path.exists(path):
                continue
            seed = hash((country, group)) & 0xFFFF
            img = backdrop(country, seed)
            img.alpha_composite(sparks(seed + 1, 38))
            img.alpha_composite(hero_layer(path, group))
            img.alpha_composite(sparks(seed + 2, 12))
            # Thin dark frame.
            ImageDraw.Draw(img).rectangle([0, 0, W - 1, H - 1], outline=(60, 58, 50, 255), width=3)
            img.convert("RGB").save(os.path.join(out_dir, f"{country}_{group}.jpg"), quality=88)
            print("banner", country, group)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
