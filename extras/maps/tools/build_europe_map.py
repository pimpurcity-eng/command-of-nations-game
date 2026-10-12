#!/usr/bin/env python3
"""Build the separate 20-player Europe map (owner request 2026-10-12) from Natural Earth.

Natural Earth (https://www.naturalearthdata.com) is public domain.

Usage:
    python3 tools/build_europe_map.py <natural_earth_dir> game

<natural_earth_dir> must contain ne_10m_admin_0_countries.geojson,
ne_10m_admin_1_states_provinces.geojson and sr/SR_HR.tif (shaded relief).

Writes:
    game/data/maps/europe20/map.json        countries (20 players, AI countries), frame, projection
    game/data/maps/europe20/provinces.json  every province (players + AI) and the context land
    game/assets/materials/relief_europe20.png  shaded relief in map coordinates

Rules from the owner:
- 20 player countries. The other European countries are AI countries that are not player
  slots (they still have provinces). Land outside Europe is blank context.
- Russia is the part of Russia the regional map already has (the 46 Russian provinces of
  data/administrative_regions.json); Ukraine keeps its 27 provinces as well.
- No resources and no units.

Projection: Lambert azimuthal equal-area on a sphere, centred 20E 52N, at the regional map's
scale (2.6 map units per 111 km), so units and buildings keep their size. The game does the
same projection in scripts/geographic_projection.gd (MapDefinition decides which one).
"""
import json
import math
import os
import sys

import numpy as np
import shapely
from shapely.geometry import MultiPolygon, Point, Polygon, box, shape
from shapely.ops import polylabel, unary_union
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

LON0, LAT0 = 20.0, 52.0
R = 6371.0
SCALE = 2.6 / 111.0  # map units per km, as on the regional map
SIMPLIFY_DEG = 0.02
MIN_PROVINCE_KM2 = 10000.0
MIN_PART_KM2 = 150.0
ISLAND_JOIN_KM = 140.0
MARGIN = 2.5  # map units around the playable land
# Owner: a similar number of provinces in every player country. Ukraine keeps the regional
# map's 27; the others are merged or split to this count.
PLAYER_PROVINCES = 25
CITIES_PER_PLAYER = 5
CITY_SPACING_KM = 110.0
# Russia's north (Karelia, Murmansk, Arkhangelsk and the parts the regional map cut off at
# its frame) joins Russia; east of this meridian Russia stays context land.
RUSSIA_NORTH = (26.0, 58.0, 50.0, 72.0)
# Map variant (tools/build_world_map.py overrides these before calling main()).
MAP_ID = "europe20"
MAP_NAME = "Europe (20 players)"
PROJECTION = "laea"            # "laea" (Europe) or "equal_earth" (world)
USE_REGIONAL = True            # Ukraine/Russia from the regional map (Europe only)
ROUGH = (-12, 33.5, 52, 72)    # lon/lat box of the playable land
CLIP = None                    # world: lon/lat box everything is clipped to (no Antarctica)
RELIEF_WIDTH = 2048
MASK_WIDTH = 1024
ID_PREFIX = "eu"
REGIONAL_RULES = True
MIN_COUNTRY_KM2 = 0.0          # world: AI countries smaller than this are left out
DROP = set()                   # world: uninhabited territories left out
VIEW = {"longitude": 15.0, "latitude": 50.0, "distance": 110.0, "max_distance": 140.0}  # opening camera

# The 20 player countries: id, Natural Earth code, name, colour (Russia/Ukraine as before).
PLAYERS = [
    ("russia", "RUS", "Russia", "ad4741"),
    ("ukraine", "UKR", "Ukraine", "376bba"),
    ("belarus", "BLR", "Belarus", "4f8a4a"),
    ("poland", "POL", "Poland", "c9a53c"),
    ("germany", "DEU", "Germany", "6b6f78"),
    ("france", "FRA", "France", "4e74c9"),
    ("united_kingdom", "GBR", "United Kingdom", "b8565f"),
    ("spain", "ESP", "Spain", "d39a34"),
    ("italy", "ITA", "Italy", "5a9c63"),
    ("turkey", "TUR", "Turkey", "c46a3c"),
    ("sweden", "SWE", "Sweden", "3d8fb0"),
    ("norway", "NOR", "Norway", "8a4f8f"),
    ("finland", "FIN", "Finland", "8bb7d8"),
    ("romania", "ROU", "Romania", "d2c25a"),
    ("hungary", "HUN", "Hungary", "9c7a4f"),
    ("czechia", "CZE", "Czechia", "5c6fa0"),
    ("austria", "AUT", "Austria", "c97b8a"),
    ("greece", "GRC", "Greece", "6cb2c4"),
    ("serbia", "SRB", "Serbia", "8f5b4a"),
    ("bulgaria", "BGR", "Bulgaria", "7aa35a"),
]
# AI countries: European countries that are not player slots.
AI = [
    ("portugal", "PRT", "Portugal"), ("ireland", "IRL", "Ireland"), ("belgium", "BEL", "Belgium"),
    ("netherlands", "NLD", "Netherlands"), ("luxembourg", "LUX", "Luxembourg"),
    ("switzerland", "CHE", "Switzerland"), ("denmark", "DNK", "Denmark"), ("estonia", "EST", "Estonia"),
    ("latvia", "LVA", "Latvia"), ("lithuania", "LTU", "Lithuania"), ("moldova", "MDA", "Moldova"),
    ("slovakia", "SVK", "Slovakia"), ("slovenia", "SVN", "Slovenia"), ("croatia", "HRV", "Croatia"),
    ("bosnia", "BIH", "Bosnia and Herzegovina"), ("montenegro", "MNE", "Montenegro"),
    ("albania", "ALB", "Albania"), ("north_macedonia", "MKD", "North Macedonia"),
    ("kosovo", "KOS", "Kosovo"), ("cyprus", "CYP", "Cyprus"), ("malta", "MLT", "Malta"),
    ("georgia", "GEO", "Georgia"), ("armenia", "ARM", "Armenia"), ("azerbaijan", "AZE", "Azerbaijan"),
]
AI_COLOR = "9a9a8c"
# Micro-states and dependencies are part of a neighbouring country on this map.
MERGED = {"AND": "ESP", "GIB": "ESP", "MCO": "FRA", "SMR": "ITA", "VAT": "ITA", "LIE": "CHE",
          "JEY": "GBR", "GGY": "GBR", "IMN": "GBR", "ALD": "FIN", "FRO": "DNK", "CYN": "CYP",
          "CNM": "CYP", "ESB": "CYP", "WSB": "CYP"}


# ---- projection -----------------------------------------------------------------------------
EE = (1.340264, -0.081106, 0.000893, 0.003796)
EE_M = math.sqrt(3.0) / 2.0


def fwd(lon, lat):
    if PROJECTION == "equal_earth":
        lam = np.radians(np.asarray(lon, dtype=float) - LON0)
        t = np.arcsin(EE_M * np.sin(np.radians(np.asarray(lat, dtype=float))))
        a1, a2, a3, a4 = EE
        d = a1 + 3 * a2 * t ** 2 + 7 * a3 * t ** 6 + 9 * a4 * t ** 8
        x = R * 2.0 * math.sqrt(3.0) * lam * np.cos(t) / (3.0 * d)
        y = R * (a1 * t + a2 * t ** 3 + a3 * t ** 7 + a4 * t ** 9)
        return x * SCALE, -y * SCALE
    lam, phi = np.radians(np.asarray(lon) - LON0), np.radians(lat)
    p0 = math.radians(LAT0)
    k = np.sqrt(2.0 / (1.0 + math.sin(p0) * np.sin(phi) + math.cos(p0) * np.cos(phi) * np.cos(lam)))
    x = R * k * np.cos(phi) * np.sin(lam)
    y = R * k * (math.cos(p0) * np.sin(phi) - math.sin(p0) * np.cos(phi) * np.cos(lam))
    return x * SCALE, -y * SCALE


def inv(X, Z):
    x, y = np.asarray(X, dtype=float) / SCALE, -np.asarray(Z, dtype=float) / SCALE
    if PROJECTION == "equal_earth":
        a1, a2, a3, a4 = EE
        t = y / R / a1
        for _ in range(12):
            f = a1 * t + a2 * t ** 3 + a3 * t ** 7 + a4 * t ** 9 - y / R
            t = t - f / (a1 + 3 * a2 * t ** 2 + 7 * a3 * t ** 6 + 9 * a4 * t ** 8)
        d = a1 + 3 * a2 * t ** 2 + 7 * a3 * t ** 6 + 9 * a4 * t ** 8
        lam = 3.0 * (x / R) * d / (2.0 * math.sqrt(3.0) * np.cos(t))
        return np.degrees(lam) + LON0, np.degrees(np.arcsin(np.clip(np.sin(t) / EE_M, -1, 1)))
    rho = np.hypot(x, y)
    c = 2.0 * np.arcsin(np.clip(rho / (2.0 * R), -1, 1))
    p0 = math.radians(LAT0)
    with np.errstate(invalid="ignore", divide="ignore"):
        phi = np.arcsin(np.cos(c) * math.sin(p0) + np.where(rho > 0, y * np.sin(c) * math.cos(p0) / rho, 0.0))
        lam = np.arctan2(x * np.sin(c), rho * math.cos(p0) * np.cos(c) - y * math.sin(p0) * np.sin(c))
    return np.degrees(lam) + LON0, np.degrees(phi)


def to_map(g):
    return shapely.transform(g, lambda c: np.column_stack(fwd(c[:, 0], c[:, 1])))


def km2(g):
    return to_map(g).area / (SCALE * SCALE)


# ---- geometry helpers -------------------------------------------------------------------------
def polys(g):
    if g is None or g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    out = []
    for p in getattr(g, "geoms", []):
        out += polys(p)
    return out


def clean(g):
    return unary_union([p for p in polys(shapely.make_valid(g)) if p.area > 1e-10])


def ring(coords):
    c = [[round(x, 6), round(y, 6)] for x, y in coords]
    if c[0] != c[-1]:
        c.append(c[0])
    return c


def mesh_patches(p):
    """Hole-free patches covering polygon p (Godot's triangulate_polygon has no holes)."""
    if not p.interiors:
        if MAP_ID == "europe20":
            return [ring(p.exterior.coords)]
    # World: always triangles (some desert/Arctic outlines defeat Godot's triangulator).
    if MAP_ID != "europe20":
        return [ring(list(t.exterior.coords)[:3]) for t in shapely.constrained_delaunay_triangles(p).geoms if t.area > 1e-12]
    return [ring(list(t.exterior.coords)[:3]) for t in shapely.constrained_delaunay_triangles(p).geoms]


def centre(p):
    m = to_map(p)
    label = polylabel(m, tolerance=0.05)
    lon, lat = inv(label.x, label.y)
    return [round(float(lon), 5), round(float(lat), 5)]


def frame_polygon(bounds):
    x0, z0, x1, z1 = bounds
    xs = np.concatenate([np.linspace(x0, x1, 200), np.full(200, x1), np.linspace(x1, x0, 200), np.full(200, x0)])
    zs = np.concatenate([np.full(200, z0), np.linspace(z0, z1, 200), np.full(200, z1), np.linspace(z1, z0, 200)])
    lon, lat = inv(xs, zs)
    return Polygon(np.column_stack([lon, lat]))


def short_name(p):
    """Everyday country name: "China", not "People's Republic of China"."""
    full, short = p["NAME_EN"] or p["NAME"], p["NAME"]
    return short if len(full) > 18 and len(short) < len(full) and "." not in short else full


def keep_parts(g):
    """A unit's main piece always stays (city districts such as London); far islets go."""
    parts = sorted(polys(g), key=lambda q: -q.area)
    return parts[:1] + [q for q in parts[1:] if km2(q) >= MIN_PART_KM2]


# ---- provinces --------------------------------------------------------------------------------
def split_unit(u, places, rng):
    """Cut a unit in two (k-means of points inside it, split along the bisector)."""
    m = to_map(u["geom"])
    x0, z0, x1, z1 = m.bounds
    pts = []
    while len(pts) < 400:
        xs = rng.uniform(x0, x1, 800)
        zs = rng.uniform(z0, z1, 800)
        inside = shapely.contains_xy(m, xs, zs)
        pts += list(zip(xs[inside], zs[inside]))
    pts = np.array(pts[:400])
    c = pts[rng.choice(len(pts), 2, replace=False)]
    for _ in range(25):
        lab = np.argmin(((pts[:, None, :] - c[None]) ** 2).sum(-1), axis=1)
        c = np.array([pts[lab == k].mean(0) if (lab == k).any() else c[k] for k in range(2)])
    mid = (c[0] + c[1]) / 2
    d = c[1] - c[0]
    n = np.array([-d[1], d[0]]) / (np.hypot(*d) + 1e-12)
    big = 1000.0
    half = Polygon([mid + n * big, mid + n * big - d / np.hypot(*d) * big, mid - n * big - d / np.hypot(*d) * big, mid - n * big])
    a_map = clean(m.intersection(half))
    b_map = clean(m.difference(half))
    out = []
    for part, centre_xy in ((a_map, c[0]), (b_map, c[1])):
        geom = clean(shapely.transform(part, lambda xy: np.column_stack(inv(xy[:, 0], xy[:, 1]))))
        inside = [pl for pl in places if geom.contains(Point(pl[1], pl[2]))]
        if inside:
            name = max(inside, key=lambda pl: pl[3])[0]
        else:
            other = c[1] if centre_xy is c[0] else c[0]
            v = centre_xy - other
            base = u["name"]
            for word in (" North", " South", " East", " West"):
                base = base.removesuffix(word)  # no "Minsk South South"
            name = base + (" " + ("West" if v[0] < 0 else "East") if abs(v[0]) > abs(v[1]) else " " + ("North" if v[1] < 0 else "South"))
        out.append({"name": name, "region": u["region"], "geom": geom, "area": km2(geom), "members": [(name, u["region"], km2(geom))]})
    return out


def drop_specks(units):
    """World map: specks far out at sea (Tokelau, the Spratlys) are not provinces."""
    if MAP_ID == "europe20" or len(units) < 2:
        return units
    maps = [to_map(u["geom"]) for u in units]
    keep = []
    for i, u in enumerate(units):
        alone = all(maps[i].distance(m) > ISLAND_JOIN_KM * SCALE for j, m in enumerate(maps) if j != i)
        if not (alone and u["area"] < MIN_PART_KM2 * 5):
            keep.append(u)
    return keep or units


def to_count(units, target, places, seed):
    """Split the largest units until there are `target` of them (then merge_small trims)."""
    rng = np.random.default_rng(seed)
    while len(units) < target:
        units.sort(key=lambda u: -u["area"])
        units[0:1] = split_unit(units[0], places, rng)
    return merge_small(units, target)


def merge_small(units, target=None):
    """Join admin-1 units: AI countries into provinces of at least MIN_PROVINCE_KM2 (Call of
    War sized); player countries down to `target` provinces."""
    maps = [to_map(u["geom"]) for u in units]
    tree = shapely.STRtree(maps)
    links = [set() for _ in units]
    for i, m in enumerate(maps):
        for j in tree.query(m.buffer(0.05)):
            if j != i and maps[j].distance(m) < 0.05:
                links[i].add(int(j))
        if not links[i]:  # islands join the nearest unit across a short stretch of sea
            for j in tree.query(m.buffer(ISLAND_JOIN_KM * SCALE)):
                if j != i and maps[j].distance(m) < ISLAND_JOIN_KM * SCALE:
                    links[i].add(int(j))
    for i in range(len(units)):
        for j in links[i]:
            links[j].add(i)
    alive = set(range(len(units)))
    while True:
        if target is not None and len(alive) <= target:
            break
        small = sorted([i for i in alive if (target is not None or units[i]["area"] < MIN_PROVINCE_KM2) and links[i]], key=lambda i: units[i]["area"])
        if not small:
            break
        i = small[0]
        j = min(links[i], key=lambda j: (units[j]["region"] != units[i]["region"], units[j]["area"]))
        keep, gone = (i, j) if units[i]["area"] >= units[j]["area"] else (j, i)
        units[keep]["geom"] = clean(unary_union([units[keep]["geom"], units[gone]["geom"]]))
        units[keep]["area"] += units[gone]["area"]
        units[keep]["members"] += units[gone]["members"]
        alive.discard(gone)
        for k in links[gone]:
            links[k].discard(gone)
            if k != keep:
                links[k].add(keep)
                links[keep].add(k)
        links[keep].discard(keep)
        links[gone] = set()
    result = [units[i] for i in sorted(alive)]
    # Name: the region when one province holds most of it (Northern Ireland, Brittany),
    # otherwise the largest original unit in it.
    dominant = []
    for u in result:
        share = {}
        for name, region, area in u["members"]:
            share[region] = share.get(region, 0.0) + area
        region, area = max(share.items(), key=lambda kv: kv[1])
        dominant.append(region if region and area >= 0.6 * u["area"] and len(u["members"]) > 1 else "")
    for u, region in zip(result, dominant):
        if u.get("fixed_name"):
            continue
        largest = max(u["members"], key=lambda m: m[2])[0]
        u["name"] = region if region and dominant.count(region) == 1 else largest
    return result


def main():
    ne_dir, game_dir = sys.argv[1], sys.argv[2]
    a0 = json.load(open(os.path.join(ne_dir, "ne_10m_admin_0_countries.geojson"), encoding="utf-8"))
    a1 = json.load(open(os.path.join(ne_dir, "ne_10m_admin_1_states_provinces.geojson"), encoding="utf-8"))
    regional = json.load(open(os.path.join(game_dir, "data/administrative_regions.json"), encoding="utf-8"))

    players = {code: (cid, name, color) for cid, code, name, color in PLAYERS}
    if AI is None:  # world: every other country is an AI country
        names = {}
        for feat in a0["features"]:
            p = feat["properties"]
            code = MERGED.get(p["ADM0_A3"], p["ADM0_A3"])
            if code not in players and code not in names and p["ADM0_A3"] == code and code not in DROP:
                names[code] = short_name(p)
        ai_list = [("".join(ch if ch.isalnum() else "_" for ch in n.lower()).strip("_"), code, n) for code, n in sorted(names.items())]
    else:
        ai_list = AI
    ai = {code: (cid, name, AI_COLOR) for cid, code, name in ai_list}
    nations = {**players, **ai}

    # The regional map's provinces: Russia's part of the map and all of Ukraine.
    fixed = []
    russia_units = []
    for feat in (regional["features"] if USE_REGIONAL else []):
        props = feat["properties"]
        g = clean(shape(feat["geometry"]))
        if props["country"] == "Russia":
            russia_units.append({"name": props["name"], "region": props["name"], "geom": g, "area": km2(g),
                                 "members": [(props["name"], props["name"], km2(g))]})
        else:
            fixed.append({"id": props["id"], "name": props["name"], "code": "UKR", "geom": g})
    fixed_land = unary_union([u["geom"] for u in fixed] + [u["geom"] for u in russia_units] + [Polygon()])
    # Russia's north, which the regional map cut off at its frame.
    north = box(*RUSSIA_NORTH)
    for feat in a1["features"]:
        p = feat["properties"]
        if not USE_REGIONAL or p["adm0_a3"] != "RUS" or not shape(feat["geometry"]).intersects(north):
            continue
        g = clean(shape(feat["geometry"]).intersection(north).difference(fixed_land))
        parts = keep_parts(g)
        if parts:
            g = unary_union(parts)
            name = p["name"] or p["name_en"]
            russia_units.append({"name": name, "region": name, "geom": g, "area": km2(g), "members": [(name, name, km2(g))]})
    fixed_land = unary_union([fixed_land] + [u["geom"] for u in russia_units])
    places = []
    pp = json.load(open(os.path.join(ne_dir, "ne_10m_populated_places_simple.geojson"), encoding="utf-8"))
    for feat in pp["features"]:
        p = feat["properties"]
        places.append((p["nameascii"] or p["name"], p["longitude"], p["latitude"], p["pop_max"] or 0,
                       MERGED.get(p["adm0_a3"], p["adm0_a3"]), bool(p["adm0cap"]), p["adm0_a3"]))

    # Frame: the playable land plus a margin, as a rectangle in map units.
    countries = {}
    for feat in a0["features"]:
        p = feat["properties"]
        code = MERGED.get(p["ADM0_A3"], p["ADM0_A3"])
        countries.setdefault(code, []).append(shape(feat["geometry"]))
    countries = {k: clean(unary_union(v)) for k, v in countries.items()}
    rough = box(*ROUGH)
    skip = ("RUS", "UKR") if USE_REGIONAL else ()
    playable = [fixed_land] + [countries[c].intersection(rough) for c in nations if c not in skip and c in countries]
    b = to_map(unary_union([p for g in playable for p in polys(g) if km2(p) > 2500.0])).bounds
    bounds = (math.floor(b[0] - MARGIN), math.floor(b[1] - MARGIN), math.ceil(b[2] + MARGIN), math.ceil(b[3] + MARGIN))
    frame = box(*CLIP) if CLIP else frame_polygon(bounds)

    # Admin-1 units of every player/AI country except Russia and Ukraine.
    units_by_code = {}
    for feat in a1["features"]:
        p = feat["properties"]
        code = MERGED.get(p["adm0_a3"], p["adm0_a3"])
        if code not in nations or code in skip:
            continue
        g = clean(shape(feat["geometry"]).intersection(frame))
        g = clean(g.difference(fixed_land))
        parts = keep_parts(g)
        if not parts:
            continue
        g = unary_union(parts)
        name = p["name"] or p["name_en"] or code
        region = p.get("region") or ""
        units_by_code.setdefault(code, []).append({"name": name, "region": region, "geom": g, "area": km2(g),
                                                   "members": [(name, region, km2(g))]})
    for code in nations:
        if code not in skip and code not in units_by_code and code in countries:
            g = clean(countries[code].intersection(frame).difference(fixed_land))
            units_by_code[code] = [{"name": nations[code][1], "region": "", "geom": g, "area": km2(g),
                                    "members": [(nations[code][1], "", km2(g))]}]

    for code in [c for c in units_by_code if c in ai and sum(u["area"] for u in units_by_code[c]) < MIN_COUNTRY_KM2]:
        del units_by_code[code]
    provinces = list(fixed)
    if USE_REGIONAL:
        units_by_code["RUS"] = russia_units
    for code, units in units_by_code.items():
        units = drop_specks(units)
        local = [pl for pl in places if pl[4] == code]
        grouped = to_count(units, PLAYER_PROVINCES, local, len(code) * 7919) if code in players else merge_small(units)
        for n, u in enumerate(sorted(grouped, key=lambda u: -u["area"])):
            provinces.append({"id": f"{ID_PREFIX}_{code.lower()}_{n}", "name": u["name"], "code": code, "geom": u["geom"]})

    seen = {}
    for p in provinces:
        seen[p["name"]] = seen.get(p["name"], 0) + 1
    for p in provinces:
        if seen[p["name"]] > 1:
            p["name"] = f"{p['name']} ({nations[p['code']][1]})"
    # Still equal (same name twice in one country): number them. Road hubs are keyed by name.
    again = {}
    for p in provinces:
        again.setdefault(p["name"], []).append(p)
    for name, group in again.items():
        if len(group) > 1:
            for n, p in enumerate(group):
                p["name"] = f"{name} {n + 1}"

    # Context: all other land inside the frame (the rest of Russia, Kazakhstan, Africa, Asia).
    claimed = unary_union([p["geom"] for p in provinces])
    context = []
    for code, g in countries.items():
        if code in nations and (code != "RUS" or not USE_REGIONAL):
            continue
        g = clean(g.intersection(frame).difference(claimed))
        parts = [q for q in polys(g) if km2(q) >= MIN_PART_KM2]
        if parts:
            name = "Russia" if code == "RUS" else code
            context.append({"id": f"ctx_{code.lower()}", "name": name, "code": code, "geom": unary_union(parts)})

    # ---- one exact coverage: shared borders exist once, no overlaps, slivers filled ----------
    pieces = []
    for owner, item in enumerate(provinces + context):
        g = item["geom"] if item["code"] == "UKR" and USE_REGIONAL else item["geom"].simplify(SIMPLIFY_DEG, preserve_topology=True)
        for q in polys(clean(g)):
            pieces.append((owner, q))
    geoms = [q for _, q in pieces]
    lines = unary_union([g.boundary for g in geoms])
    faces = list(shapely.polygonize(list(getattr(lines, "geoms", [lines]))).geoms)
    tree = shapely.STRtree(geoms)
    items = provinces + context
    owned = [[] for _ in items]
    gaps = []
    for face in faces:
        rp = face.representative_point()
        hits = [j for j in tree.query(rp) if geoms[j].contains(rp)]
        if hits:
            owned[pieces[min(hits)][0]].append(face)
        else:
            gaps.append(face)
    shapes = [clean(unary_union(fs)) if fs else Polygon() for fs in owned]
    filled = 0
    stree = shapely.STRtree(shapes)
    for face in gaps:
        if face.area > (0.05 if USE_REGIONAL else 0.4):
            continue  # real water (seas, lakes)
        best, best_len = None, 0.0
        for j in stree.query(face.buffer(1e-7)):
            ln = face.boundary.intersection(shapes[j].buffer(1e-7)).length
            if ln > best_len:
                best, best_len = j, ln
        if best is not None:
            shapes[best] = clean(shapes[best].union(face))
            filled += 1
    # Crumbs cut off by the repair go to the neighbour that touches them most.
    for i, g in enumerate(shapes):
        parts = polys(g)
        keep = [p for p in parts if km2(p) >= MIN_PART_KM2 or p.area == max(q.area for q in parts)]
        for crumb in [p for p in parts if not any(p is k for k in keep)]:
            best, best_len = None, 0.0
            for j in stree.query(crumb.buffer(1e-7)):
                if j == i:
                    continue
                ln = crumb.boundary.intersection(shapes[j].buffer(1e-7)).length
                if ln > best_len:
                    best, best_len = j, ln
            if best is not None:
                shapes[best] = clean(shapes[best].union(crumb))
        shapes[i] = unary_union(keep)
    all_parts = [p for g in shapes for p in polys(g)]
    assert shapely.coverage_is_valid(all_parts), "coverage has overlaps"

    # ---- write ------------------------------------------------------------------------------
    features = []
    for i, item in enumerate(items):
        parts = sorted(polys(shapes[i]), key=lambda p: -p.area)
        if not parts:
            continue
        code = item["code"]
        role = "context" if i >= len(provinces) else ("player" if code in players else "ai")
        cid, cname = (nations[code][0], nations[code][1]) if role != "context" else (code.lower(), item["name"])
        coords = [[ring(p.exterior.coords)] + [ring(h.coords) for h in p.interiors] for p in parts]
        features.append({
            "type": "Feature",
            "properties": {"id": item["id"], "name": item["name"], "country": cname, "country_id": cid, "role": role},
            "geometry": {"type": "Polygon", "coordinates": coords[0]} if len(coords) == 1 else {"type": "MultiPolygon", "coordinates": coords},
            "mesh_polygons": [mesh_patches(p) for p in parts],
            "centers": [centre(p) for p in parts],
        })
    # Cities (owner): five in every player country, the capital in every AI country. The
    # capital first, then the largest towns, spaced out and one per province.
    cities = []
    for code, (cid, cname, _) in nations.items():
        own = [(item, shapes[i]) for i, item in enumerate(items) if i < len(provinces) and item["code"] == code]
        wanted = CITIES_PER_PLAYER if code in players else 1
        chosen = []
        used = set()
        candidates = [pl for pl in places if pl[4] == code and pl[6] == code]
        if len(candidates) < wanted:  # codes differ between Natural Earth files (South Sudan)
            land = unary_union([g for _, g in own] + [Polygon()])
            near = land.buffer(0.3)
            candidates += [pl for pl in places if pl not in candidates and near.contains(Point(pl[1], pl[2]))]
        candidates.sort(key=lambda pl: (not pl[5], -pl[3]))
        for spacing in (CITY_SPACING_KM, CITY_SPACING_KM * 0.6, CITY_SPACING_KM * 0.3, 0.0):
          for name, lon, lat, pop, pcode, capital, _ in candidates:
            if len(chosen) >= wanted:
                break
            if any(c["name"] == name for c in chosen):
                continue
            home = next((item["id"] for item, g in own if g.contains(Point(lon, lat))), None)
            if home is None and own:  # coastal towns just outside the simplified coast
                item, g = min(own, key=lambda o: o[1].distance(Point(lon, lat)))
                if g.distance(Point(lon, lat)) < 0.3:
                    home = item["id"]
            if home is None or home in used:
                continue
            x, z = (float(v) for v in fwd(lon, lat))
            if any(math.hypot(x - c["_x"], z - c["_z"]) / SCALE < spacing for c in chosen):
                continue
            used.add(home)
            chosen.append({"id": f"{cid}_{len(chosen)}", "name": name, "country": cname, "country_id": cid,
                           "longitude": round(lon, 4), "latitude": round(lat, 4), "capital": len(chosen) == 0 and capital,
                           "province": home, "_x": float(x), "_z": float(z)})
        for c in chosen:
            del c["_x"], c["_z"]
            # Coastal towns can fall just outside the simplified coastline: move them onto land.
            g = next(g for item, g in own if item["id"] == c["province"])
            if not g.contains(Point(c["longitude"], c["latitude"])):
                inner = g.buffer(-0.03)
                target = inner if not inner.is_empty else g
                from shapely.ops import nearest_points
                q = nearest_points(target, Point(c["longitude"], c["latitude"]))[0]
                c["longitude"], c["latitude"] = round(q.x, 4), round(q.y, 4)
        cities += chosen

    # Country outlines (players and AI) for the thick national borders and the road clip.
    outlines = []
    for code, (cid, cname, _) in nations.items():
        own = [shapes[i] for i, item in enumerate(items) if i < len(provinces) and item["code"] == code]
        for p in polys(unary_union(own)):
            outlines.append({"country_id": cid, "rings": [ring(p.exterior.coords)] + [ring(h.coords) for h in p.interiors]})
    out_dir = os.path.join(game_dir, f"data/maps/{MAP_ID}")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "provinces.json"), "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection",
                   "source": "Natural Earth 1:10m admin-0/admin-1 (public domain) and the regional map's "
                             "Russia/Ukraine provinces; built by tools/build_europe_map.py / build_world_map.py.",
                   "outlines": outlines, "features": features}, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(out_dir, "cities.json"), "w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)
        f.write("\n")
    counts = {}
    for feat in features:
        counts[feat["properties"]["country_id"]] = counts.get(feat["properties"]["country_id"], 0) + 1
    definition = {
        "id": MAP_ID,
        "name": MAP_NAME,
        "players": [{"id": cid, "name": name, "color": color, "provinces": counts.get(cid, 0),
                     "cities": sum(1 for c in cities if c["country_id"] == cid)} for cid, code, name, color in PLAYERS],
        "ai_countries": [{"id": cid, "name": name, "color": AI_COLOR, "provinces": counts.get(cid, 0),
                          "cities": sum(1 for c in cities if c["country_id"] == cid)} for cid, code, name in ai_list if counts.get(cid, 0) > 0],
        "projection": {"type": PROJECTION, "longitude": LON0, "latitude": LAT0, "units_per_km": SCALE},
        "frame": {"origin": [bounds[0], bounds[1]], "extent": [bounds[2] - bounds[0], bounds[3] - bounds[1]]},
        "relief": f"res://assets/materials/relief_{MAP_ID}.png",
        "coast_mask": f"res://assets/materials/coast_{MAP_ID}.png",
        "cities": f"res://data/maps/{MAP_ID}/cities.json",
        "view": VIEW,
        "resources": False,
        "units": False,
    }
    with open(os.path.join(out_dir, "map.json"), "w", encoding="utf-8") as f:
        json.dump(definition, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # ---- shaded relief in map coordinates ---------------------------------------------------
    sr = Image.open(os.path.join(ne_dir, "sr/SR_HR.tif")).convert("L")
    src = np.asarray(sr)
    ppd = src.shape[1] / 360.0
    width = RELIEF_WIDTH
    height = round(width * (bounds[3] - bounds[1]) / (bounds[2] - bounds[0]))
    xs = bounds[0] + (np.arange(width) + 0.5) / width * (bounds[2] - bounds[0])
    zs = bounds[1] + (np.arange(height) + 0.5) / height * (bounds[3] - bounds[1])
    gx, gz = np.meshgrid(xs, zs)
    lon, lat = inv(gx, gz)
    px = np.clip(((lon + 180.0) * ppd).astype(int), 0, src.shape[1] - 1)
    py = np.clip(((90.0 - lat) * ppd).astype(int), 0, src.shape[0] - 1)
    Image.fromarray(src[py, px]).save(os.path.join(game_dir, f"assets/materials/relief_{MAP_ID}.png"), optimize=True)

    # Coast mask for the sea shader: green = distance to land / 8 map units.
    from PIL import ImageDraw
    from scipy.ndimage import distance_transform_edt
    mw = MASK_WIDTH
    mh = round(mw * (bounds[3] - bounds[1]) / (bounds[2] - bounds[0]))
    mask = Image.new("L", (mw, mh), 0)
    draw = ImageDraw.Draw(mask)
    for g in shapes:
        for p in polys(g):
            m = to_map(p)
            draw.polygon([((x - bounds[0]) / (bounds[2] - bounds[0]) * mw, (z - bounds[1]) / (bounds[3] - bounds[1]) * mh)
                          for x, z in m.exterior.coords], fill=255)
    land = np.asarray(mask) > 0
    dist = distance_transform_edt(~land) * (bounds[2] - bounds[0]) / mw
    g = np.clip(dist / 8.0 * 255.0, 0, 255).astype(np.uint8)
    rgb = np.dstack([land.astype(np.uint8) * 255, g, np.zeros_like(g)])
    Image.fromarray(rgb, "RGB").save(os.path.join(game_dir, f"assets/materials/coast_{MAP_ID}.png"), optimize=True)

    total = sum(1 for f in features if f["properties"]["role"] != "context")
    print(f"frame={bounds} provinces={total} context={len(features) - total} gaps filled={filled}")
    for cid, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {cid}: {n}")


if __name__ == "__main__":
    main()
