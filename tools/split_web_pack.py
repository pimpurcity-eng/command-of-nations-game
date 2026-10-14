#!/usr/bin/env python3
"""Split the web export's index.pck so the browser game starts fast (owner 2026-10-14: the 180 MB
download on the phone was "unacceptable").

  python3 tools/split_web_pack.py <web export dir> <game dir>

Writes <dir>/index.pck (everything needed to start: map, cities, interface, sounds and the starting
armies) and <dir>/index.extras.pck (every other weapon model and picture), which the game
downloads in the background (scripts/web_extras.gd). Updates the size in index.html.
"""
import os, re, struct, sys, json

ALIGN = 32
web, game = sys.argv[1], sys.argv[2]
src = os.path.join(web, "index.pck")

def read_pack(path):
    f = open(path, "rb")
    header = f.read(112)
    assert header[:4] == b"GDPC"
    base = struct.unpack("<Q", header[24:32])[0]
    directory = struct.unpack("<Q", header[32:40])[0]
    f.seek(directory)
    entries = []
    for _ in range(struct.unpack("<I", f.read(4))[0]):
        length = struct.unpack("<I", f.read(4))[0]
        name = f.read(length).rstrip(b"\0").decode()
        offset, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        flags = struct.unpack("<I", f.read(4))[0]
        entries.append({"name": name, "offset": offset, "size": size, "md5": md5, "flags": flags})
    for e in entries:
        f.seek(base + e["offset"])
        e["data"] = f.read(e["size"])
    return header, entries

def write_pack(path, header, entries):
    with open(path, "wb") as f:
        f.write(header)
        offsets = []
        position = 0
        for e in entries:
            pad = (-position) % ALIGN
            f.write(b"\0" * pad); position += pad
            offsets.append(position)
            f.write(e["data"]); position += e["size"]
        pad = (-position) % ALIGN
        f.write(b"\0" * pad); position += pad
        directory = 112 + position
        f.write(struct.pack("<I", len(entries)))
        for e, offset in zip(entries, offsets):
            name = e["name"].encode() + b"\0"
            name += b"\0" * ((-len(name)) % 4)
            f.write(struct.pack("<I", len(name)) + name + struct.pack("<QQ", offset, e["size"]) + e["md5"] + struct.pack("<I", e["flags"]))
        f.seek(32)
        f.write(struct.pack("<Q", directory))

header, entries = read_pack(src)
by_name = {e["name"]: e for e in entries}

# Models and pictures the first minutes need: the starting armies (both sides) and the stand-ins
# shown until the rest arrives. Everything under assets/library outside these stays for later,
# except buildings, transport (trains) and the city art, which the map needs at once.
CORE_MODELS = [
    "arsenal/russia_motor_rifleman", "pl01_russian", "airdefense/russia_strela10", "skyguard_russian",
    "arsenal/russia_yak130", "arsenal/euro_hawk_t2", "arsenal/euro_fr_foreign_legion",
    "arsenal/euro_uk_royal_marine", "pl01_european", "airdefense/nato_roland", "skyguard_european",
    # Buildings standing at the start (capital recruitment centre and train station, the
    # province airport of the starting plane) and the rail and road pieces drawn on the map.
    "buildings_oct12/recruitment_center", "buildings_oct12/train_station", "buildings_oct12/road_straight",
    "buildings_oct12/rail_straight", "buildings_oct12/province_airport_l1",
    # City resource emblems on the map tags.
    "buildings_oct12/resource_",
]
KEEP_FOLDERS = ()
core_prefixes = ["assets/library/" + m for m in CORE_MODELS]
# Buildings and their pictures (data/buildings.json, its asset-roster entries and the facility
# scenes) are drawn and listed from the start; some are loaded without an existence check.
building_text = open(os.path.join(game, "data/buildings.json")).read()
roster_ids = set(re.findall(r'"asset_roster_id":\s*"([^"]+)"', building_text))
for entry in json.load(open(os.path.join(game, "data/asset_roster.json"))):
    if entry.get("id") in roster_ids or entry.get("shared_building"):
        building_text += json.dumps(entry)
for root, _dirs, files in os.walk(os.path.join(game, "scenes/facilities")):
    for name in files: building_text += open(os.path.join(root, name), errors="ignore").read()
for path in re.findall(r"res://(assets/library/[A-Za-z0-9_./-]+)", building_text):
    if not path.startswith("assets/library/buildings_oct12/"):
        core_prefixes.append(path.rsplit(".", 1)[0])

def is_extra(source):
    # Unused vehicle set, and everything in the library the start does not show: other weapons,
    # stand-ins, other buildings and levels, trade ships and trains (all loaded on demand with
    # existence checks; WebExtras swaps them in when the pack arrives).
    if source.startswith("assets/vehicles/"): return True
    if not source.startswith("assets/library/"): return False
    return not any(source.startswith(p) for p in core_prefixes)

def targets(entry_name):
    data = by_name[entry_name]["data"].decode("utf-8", "ignore")
    return set(re.findall(r'"res://([^"]+)"', data))

extra = set()
for e in entries:
    name = e["name"]
    for suffix in (".import", ".remap"):
        if name.endswith(suffix) and is_extra(name[: -len(suffix)]):
            extra.add(name)
            extra |= {t for t in targets(name) if t in by_name and t.startswith(".godot/")}
    if is_extra(name): extra.add(name)

# Safety: nothing the start pack keeps may point at a file that moved to the extras pack.
moved = True
while moved:
    moved = False
    referenced = set()
    for e in entries:
        # Only real resource dependencies count; data tables and scripts name every model but
        # load them on demand (and check ResourceLoader.exists first).
        if e["name"] in extra or not e["name"].endswith((".scn", ".res", ".tscn", ".tres")): continue
        referenced |= {m.decode() for m in re.findall(rb"res://(assets/library/[A-Za-z0-9_./-]+)", e["data"])}
    for path in referenced:
        for suffix in (".import", ".remap"):
            key = path + suffix
            if key in extra:
                extra.discard(key)
                extra -= {t for t in targets(key)}
                moved = True

core_entries = [e for e in entries if e["name"] not in extra]
# List of everything that arrives later, so the game knows exactly which files to wait for
# (WebExtras.has); ResourceLoader.exists cannot tell in an exported game.
later = sorted({"res://" + n.rsplit(".", 1)[0] for n in extra if n.endswith((".import", ".remap"))})
listing = "\n".join(later).encode()
import hashlib
core_entries.append({"name": "web_extras_index.txt", "size": len(listing), "data": listing,
                     "md5": hashlib.md5(listing).digest(), "flags": 0})
extra_entries = [e for e in entries if e["name"] in extra]
write_pack(os.path.join(web, "index.pck"), header, core_entries)
write_pack(os.path.join(web, "index.extras.pck"), header, extra_entries)

html = os.path.join(web, "index.html")
text = open(html).read()
text = re.sub(r'"index\.pck":\s*\d+', '"index.pck":%d' % os.path.getsize(os.path.join(web, "index.pck")), text)
open(html, "w").write(text)
mb = lambda p: os.path.getsize(os.path.join(web, p)) // 1048576
print(f"start pack {mb('index.pck')} MB ({len(core_entries)} files), weapons pack {mb('index.extras.pck')} MB ({len(extra_entries)} files)")
