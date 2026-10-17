#!/usr/bin/env python3
"""Owner 2026-10-17: little map pictures for the Games list (Call of War style).

Usage: python3 extras/maps/tools/render_game_thumbs.py <out_dir>
Draws each game's region from the world map outlines (Natural Earth, public domain).
"""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "data", "maps")
world = json.load(open(os.path.join(ROOT, "world100", "provinces.json")))
wmap = json.load(open(os.path.join(ROOT, "world100", "map.json")))
emap = json.load(open(os.path.join(ROOT, "europe20", "map.json")))
WORLD_COLORS = {p["id"]: "#" + p["color"] for p in wmap["players"]}
EUROPE_COLORS = {p["id"]: "#" + p["color"] for p in emap["players"]}
SIZE, SS = 256, 4

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

GAMES = {
    "russia_ukraine": {"box": (21, 40.5, 53, 58), "colors": {"russia": "#c0504a", "ukraine": "#3f74c4"}},
    "middle_east": {"box": (31, 22, 63, 41), "colors": {"iran": "#3f9a62", "israel": "#4a7fd0"}, "rings": [(35.0, 31.4)]},
    "china": {"box": (70, 13, 140, 55), "colors": {"china": "#d0a040", "taiwan": "#8c7a52"}},
    "europe": {"box": (-12, 34, 46, 71), "colors": EUROPE_COLORS},
    "world": {"box": (-128, -42, 152, 76), "colors": WORLD_COLORS, "kx": 0.42},
}

def render(name, spec):
    w0, s0, e0, n0 = spec["box"]
    mid = math.radians((s0 + n0) / 2)
    kx = spec.get("kx", math.cos(mid))
    span_x, span_y = (e0 - w0) * kx, (n0 - s0)
    scale = SIZE * SS / max(span_x, span_y)
    ox = (SIZE * SS - span_x * scale) / 2
    oy = (SIZE * SS - span_y * scale) / 2
    def pt(lon, lat):
        if name == "world" and lon < -170: lon += 360
        return (ox + (lon - w0) * kx * scale, oy + (n0 - lat) * scale)
    S = SIZE * SS
    img = Image.new("RGBA", (S, S))
    # Ocean: deep navy with a soft radial light.
    sea = Image.new("RGBA", (S, S), hexc("#0d2230"))
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((-S * .2, -S * .35, S * 1.2, S * .95), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S / 6))
    sea.paste(Image.new("RGBA", (S, S), hexc("#1f4a5e")), mask=glow)
    img.alpha_composite(sea)
    d = ImageDraw.Draw(img)
    # Graticule.
    step = 30 if name == "world" else 10
    for lon in range(-180, 200, step):
        d.line([pt(lon, -85), pt(lon, 85)], fill=(120, 170, 190, 28), width=SS)
    for lat in range(-80, 90, step):
        d.line([pt(-180, lat), pt(200, lat)], fill=(120, 170, 190, 28), width=SS)
    colors = spec["colors"]
    land = Image.new("RGBA", (S, S))
    ld = ImageDraw.Draw(land)
    shadow = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(shadow)
    for o in world["outlines"]:
        cid = o["country_id"]
        fill = hexc(colors[cid]) if cid in colors else hexc("#3a4a4f")
        for ring in o["rings"]:
            pts = [pt(x, y) for x, y in ring]
            if len(pts) < 3: continue
            xs = [p[0] for p in pts]
            if name == "world" and max(xs) - min(xs) > S * .8: continue
            sd.polygon([(x + SS * 3, y + SS * 4) for x, y in pts], fill=200)
            ld.polygon(pts, fill=fill)
            edge = (16, 24, 28, 170) if cid not in colors else (250, 235, 200, 150)
            ld.line(pts + [pts[0]], fill=edge, width=max(1, SS if name == "world" else SS * 2))
    # Small countries get a ring so they can be found (Israel on the Middle East map).
    for lon, lat in spec.get("rings", []):
        x, y = pt(lon, lat); r = S * .07
        ld.ellipse((x - r, y - r, x + r, y + r), outline=(250, 235, 200, 230), width=SS * 3)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SS * 4))
    img.paste(Image.new("RGBA", (S, S), (2, 8, 12, 150)), mask=shadow)
    img.alpha_composite(land)
    # Light from the top-left and a dark vignette at the edges.
    shade = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shade).rectangle((0, 0, S, S), fill=0)
    vig = Image.new("L", (S, S), 255)
    ImageDraw.Draw(vig).ellipse((S * .06, S * .02, S * .94, S * 1.0), fill=0)
    vig = vig.filter(ImageFilter.GaussianBlur(S / 9))
    img.paste(Image.new("RGBA", (S, S), (4, 12, 18, 200)), mask=vig)
    hi = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hi).ellipse((-S * .4, -S * .6, S * .7, S * .45), fill=55)
    hi = hi.filter(ImageFilter.GaussianBlur(S / 8))
    img.paste(Image.new("RGBA", (S, S), (255, 240, 210, 255)), mask=hi.point(lambda v: v // 3))
    return img.resize((SIZE, SIZE), Image.LANCZOS)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for name, spec in GAMES.items():
    render(name, spec).convert("RGB").save(os.path.join(out, name + ".png"), optimize=True)
    print("wrote", name)
