"""Install only the ten selected models from the owner's private archive."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archive", type=Path)
args = parser.parse_args()
manifest = json.loads((root / "docs/AIR_DEFENSE_ASSETS.json").read_text())
# Verify all originals before writing any destination.
with zipfile.ZipFile(args.archive) as archive:
    files = {name: archive.read(name) for name in manifest["models"]}
for name, contents in files.items():
    if hashlib.sha256(contents).hexdigest() != manifest["models"][name]:
        raise SystemExit("Unexpected asset hash: " + name)
destination = root / "game/assets/library/airdefense"
destination.mkdir(parents=True, exist_ok=True)
for name, contents in files.items():
    (destination / name).write_bytes(contents)
print("Installed", len(files), "original air-defense models into", destination)
