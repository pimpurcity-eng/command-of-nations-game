"""Limit derived research pictures to 512px; leave supplied PNG/GLB originals unchanged.
Run after the first Godot import, then import again before Android export.
"""
import json
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
changed = 0
for manifest_name in ["NEW_WEAPONS_ASSETS.json", "NAVAL_DRONE_MISSILE_ASSETS.json"]:
    manifest = json.loads((root / "docs" / manifest_name).read_text())
    for name in manifest["previews"]:
        folder = "reserve" if name in manifest.get("reserve_files", []) else "arsenal"
        sidecar = root / "game/assets/library" / folder / (name + ".import")
        if not sidecar.exists():
            raise SystemExit("Run Godot import first: " + str(sidecar))
        content = sidecar.read_text()
        replacement, count = re.subn(r"^process/size_limit=\d+$", "process/size_limit=512", content, flags=re.M)
        if count != 1:
            raise SystemExit("Missing Godot size_limit option: " + str(sidecar))
        if replacement != content:
            sidecar.write_text(replacement)
            changed += 1
print("Configured 512px derived phone previews:", changed, "changed; originals untouched")
