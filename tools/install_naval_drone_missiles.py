"""Verify and install the owner's naval, drone and missile archives privately."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archives", type=Path, nargs="+")
args = parser.parse_args()
manifest = json.loads((root / "docs/NAVAL_DRONE_MISSILE_ASSETS.json").read_text())
expected = manifest["models"] | manifest["previews"]
found = {}
for archive in args.archives:
    with zipfile.ZipFile(archive) as z:
        for member in z.namelist():
            name = Path(member).name
            if name not in expected:
                continue
            data = z.read(member)
            if hashlib.sha256(data).hexdigest() != expected[name]:
                raise SystemExit("Unexpected asset hash: " + name)
            found[name] = data
missing = sorted(set(expected) - set(found))
if missing:
    raise SystemExit("Missing originals: " + ", ".join(missing))
destination = root / "game/assets/library"
def target_for(name):
    return destination / ("reserve" if name in manifest["reserve_files"] else "arsenal") / name
for name, data in found.items():
    target = target_for(name)
    if target.exists() and target.read_bytes() != data:
        raise SystemExit("Refusing to overwrite different original: " + name)
for name, data in found.items():
    target = target_for(name)
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
print("Verified and installed", len(manifest["models"]), "models and", len(manifest["previews"]), "previews")
