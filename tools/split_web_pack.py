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
    "arsenal/russia_motor_rifleman", "arsenal/russia_t64", "airdefense/russia_strela10", "skyguard_russian",
    "arsenal/russia_yak130", "arsenal/euro_hawk_t2", "arsenal/euro_fr_foreign_legion",
    "arsenal/euro_uk_royal_marine", "arsenal/euro_amx30", "airdefense/nato_roland", "skyguard_european",
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
    # Unit pictures (ChatGPT's art) come with the start: menus showed old pictures while they
    # downloaded (owner 2026-10-15). They are imported small (384 px, lossy), about 5 MB.
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
# One small pack per model or picture (owner 2026-10-15: the single 186 MB weapons pack made the
# phone browser run out of memory - "WebGL context lost" in the weapons range). The game fetches
# only the packs for what is on screen; web_extras_index.txt says which pack holds each file.
def group_of(source):
    source = source.rsplit(".", 1)[0]
    for folder in ("assets/library/arsenal/", "assets/library/airdefense/", "assets/library/buildings_oct12/", "assets/library/transport/", "assets/interface/unit_art/", "assets/vehicles/"):
        if source.startswith(folder):
            return (folder.split("/")[-2] + "_" + source[len(folder):].split("/")[0]).split(".")[0]
    rest = source[len("assets/library/"):] if source.startswith("assets/library/") else source
    return rest.split("/")[0]
# Model base names: textures named after a model (t90m_russian_russian_ground_color) travel with it.
groups = {}
owner_of = {}
for e in extra_entries:
    name = e["name"]
    if name.endswith((".import", ".remap")):
        source = name[: -len(name.split(".")[-1]) - 1]
        owner_of[name] = group_of(source)
        for t in targets(name): owner_of.setdefault(t, group_of(source))
bases = sorted({g for g in owner_of.values()}, key=len, reverse=True)
def group_for(name):
    if name in owner_of: return owner_of[name]
    stem = name.split("/")[-1]
    for b in bases:
        if stem.startswith(b.split("_", 1)[-1]) or stem.startswith(b): return b
    return "misc"
for e in extra_entries: groups.setdefault(group_for(e["name"]), []).append(e)
# Textures shared by several models (e.g. one camouflage sheet) go with the first model that names
# them; the index below records the real pack for every file.
os.makedirs(os.path.join(web, "extras"), exist_ok=True)
for old in os.listdir(os.path.join(web, "extras")): os.remove(os.path.join(web, "extras", old))
index_lines = []
for number, (group, members) in enumerate(sorted(groups.items())):
    write_pack(os.path.join(web, "extras", "%d.pck" % number), header, members)
    for e in members:
        if e["name"].endswith((".import", ".remap")):
            index_lines.append("res://" + e["name"].rsplit(".", 1)[0] + "\t%d" % number)
# Every resource also needs the packs of the files its import points at (textures of a model).
group_names = sorted(groups)
pack_of_file = {e["name"]: n for n, (g, members) in enumerate(sorted(groups.items())) for e in members}
needs = {}
for e in extra_entries:
    if e["name"].endswith((".import", ".remap")):
        packs = {pack_of_file[e["name"]]}
        data = by_name[e["name"]]["data"].decode("utf-8", "ignore")
        for t in targets(e["name"]):
            if t in pack_of_file: packs.add(pack_of_file[t])
        # A model scene names its textures inside the .scn.
        for t in targets(e["name"]):
            if t in by_name and t.endswith(".scn"):
                for ref in re.findall(rb"res://([A-Za-z0-9_./-]+)", by_name[t]["data"]):
                    ref = ref.decode()
                    for candidate in (ref + ".import", ref):
                        if candidate in pack_of_file: packs.add(pack_of_file[candidate])
                        if candidate in by_name and candidate.endswith(".import"):
                            for tt in targets(candidate):
                                if tt in pack_of_file: packs.add(pack_of_file[tt])
        # Exported scenes are compressed (RSCC), so their texture names cannot be read here.
        # Textures are named after their model (russia_t90a.glb -> russia_t90a_Camo.png,
        # t90m_russian.glb -> t90m_russian_russian_ground_color.png): they travel together.
        own = group_of(e["name"][: -len(e["name"].split(".")[-1]) - 1])
        for n, g in enumerate(group_names):
            if g.startswith(own + "_"): packs.add(n)
        needs["res://" + e["name"].rsplit(".", 1)[0]] = sorted(packs)
listing = "\n".join(k + "\t" + ",".join(str(p) for p in v) for k, v in sorted(needs.items())).encode()
core_entries = [e for e in core_entries if e["name"] != "web_extras_index.txt"]
core_entries.append({"name": "web_extras_index.txt", "size": len(listing), "data": listing,
                     "md5": hashlib.md5(listing).digest(), "flags": 0})
write_pack(os.path.join(web, "index.pck"), header, core_entries)
if os.path.exists(os.path.join(web, "index.extras.pck")): os.remove(os.path.join(web, "index.extras.pck"))

html = os.path.join(web, "index.html")
text = open(html).read()
text = re.sub(r'"index\.pck":\s*\d+', '"index.pck":%d' % os.path.getsize(os.path.join(web, "index.pck")), text)
open(html, "w").write(text)
mb = lambda p: os.path.getsize(os.path.join(web, p)) // 1048576
sizes = [os.path.getsize(os.path.join(web, "extras", f)) for f in os.listdir(os.path.join(web, "extras"))]
print(f"start pack {mb('index.pck')} MB ({len(core_entries)} files), {len(sizes)} weapon packs, largest {max(sizes)//1048576} MB, total {sum(sizes)//1048576} MB")
