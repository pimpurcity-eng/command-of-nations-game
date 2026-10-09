"""Install the owner's tank, APC and aircraft models (Drive folder "Weapons") into the
private, gitignored game/assets/library/arsenal/. Pass one or more of the owner's zips."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archives", type=Path, nargs="+")
args = parser.parse_args()
manifest = json.loads((root / "docs/ARSENAL_ASSETS.json").read_text())["models"]
found = {}
for archive in args.archives:
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            if Path(name).name in manifest and Path(name).name not in found:
                found[Path(name).name] = z.read(name)
missing = sorted(set(manifest) - set(found))
if missing:
    raise SystemExit("Missing models: " + ", ".join(missing))
for name, contents in found.items():
    if hashlib.sha256(contents).hexdigest() != manifest[name]:
        raise SystemExit("Unexpected asset hash: " + name)
destination = root / "game/assets/library/arsenal"
destination.mkdir(parents=True, exist_ok=True)
for name, contents in found.items():
    (destination / name).write_bytes(contents)
print("Installed", len(found), "original models into", destination)
