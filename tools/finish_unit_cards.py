"""Finish rendered unit cards (tools/make_unit_cards.gd): warm golden-hour grade, gentle painterly
softening, vignette, 512x512 WebP into game/assets/interface/unit_art/, and map them in
game/data/menu_art.json. Owner 2026-10-15: "can you make the cards yourself"."""
import json, sys
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/unit_cards")
ART = ROOT / "game/assets/interface/unit_art"
MODELS = {"euro_warmate": "arsenal", "euro_globaleye": "arsenal", "euro_lynx_kf41": "arsenal", "euro_amx30": "arsenal", "russia_t64": "arsenal"}
import os
if os.environ.get("ONLY"): MODELS = {k: v for k, v in MODELS.items() if k in os.environ["ONLY"].split(",")}
for name, folder in MODELS.items():
    image = Image.open(SOURCE / (name + ".png")).convert("RGB")
    image = image.filter(ImageFilter.SMOOTH_MORE).filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    image = ImageEnhance.Contrast(image).enhance(1.12)
    image = ImageEnhance.Color(image).enhance(1.08)
    warm = Image.new("RGB", image.size, (255, 196, 140))
    image = Image.blend(image, warm, 0.06)
    # Soft vignette: a radial gradient, darker toward the corners.
    ring = Image.radial_gradient("L").resize(image.size, Image.BICUBIC)
    shade = ring.point(lambda v: 255 - int(max(0, v - 120) * 0.55))
    image = Image.composite(image, Image.new("RGB", image.size, (24, 18, 12)), shade)
    image.resize((512, 512), Image.LANCZOS).save(ART / (name + ".webp"), "WEBP", quality=88)
    print("card", name)
path = ROOT / "game/data/menu_art.json"
raw = path.read_text()
art = json.loads(raw)
table = art.get("models", art) if isinstance(art, dict) else art
target = None
def find(node):
    global target
    if isinstance(node, dict):
        if any(str(k).endswith(".glb") for k in node): target = node; return
        for v in node.values(): find(v)
find(art)
for name, folder in MODELS.items():
    target[f"res://assets/library/{folder}/{name}.glb"] = f"res://assets/interface/unit_art/{name}.webp"
path.write_text(json.dumps(art, indent=2, ensure_ascii=False) + "\n")
