#!/usr/bin/env python3
"""Build the Russia-Ukraine theater map for the Godot game from Natural Earth data.

Natural Earth (https://www.naturalearthdata.com) is public domain.

Usage:
    python3 tools/build_map.py <natural_earth_dir> <godot_project_dir>

<natural_earth_dir> must contain:
    ne_10m_admin_1_states_provinces.geojson
    ne_10m_admin_0_countries.geojson
    ne_10m_populated_places_simple.geojson
    ne_10m_lakes.geojson
    ne_10m_rivers_lake_centerlines.geojson
    sr/SR_HR.tif   (Natural Earth 10m shaded relief raster)

Writes <godot_project_dir>/data/map.json and <godot_project_dir>/textures/relief.png.

Map coordinates are kilometres on a flat projection centred on 35E 50N:
    x = (lon - 35) * KX   (east)
    z = (50 - lat) * KZ   (south)
"""
import json
import math
import os
import sys

import numpy as np
import shapely
from shapely.geometry import MultiPoint, Point, box, shape
from shapely.ops import polylabel, unary_union
from PIL import Image, ImageDraw, ImageFilter

Image.MAX_IMAGE_PIXELS = None

LON0, LAT0 = 35.0, 50.0
KX = 111.32 * math.cos(math.radians(LAT0))
KZ = 111.0
BBOX = (21.8, 43.2, 48.3, 56.5)  # lon_min, lat_min, lon_max, lat_max

RURAL_TARGET_KM2 = 13000.0
SIMPLIFY_KM = 1.0
MIN_PART_KM2 = 40.0

# Neutral countries drawn around the theater (one province each).
NEUTRAL_COUNTRIES = {
    "POL": "Poland", "SVK": "Slovakia", "HUN": "Hungary", "ROU": "Romania",
    "MDA": "Moldova", "BGR": "Bulgaria", "TUR": "Turkey", "GEO": "Georgia",
    "ARM": "Armenia", "AZE": "Azerbaijan", "KAZ": "Kazakhstan", "LTU": "Lithuania",
    "LVA": "Latvia", "SRB": "Serbia", "EST": "Estonia",
}

# Modern spellings for cities and regions.
NAME_FIX = {
    "Dnipropetrovsk": "Dnipro", "Dnepropetrovsk": "Dnipro", "Kirovohrad": "Kropyvnytskyi",
    "Kirovograd": "Kropyvnytskyi", "Odessa": "Odesa", "Nikolayev": "Mykolaiv",
    "Zaporozhye": "Zaporizhzhia", "Zaporizhzhya": "Zaporizhzhia", "Kharkov": "Kharkiv",
    "Kiev": "Kyiv", "Lvov": "Lviv", "Lugansk": "Luhansk", "Chernigov": "Chernihiv",
    "Zhitomir": "Zhytomyr", "Rovno": "Rivne", "Vinnitsa": "Vinnytsia", "Kherson": "Kherson",
    "Simferopol": "Simferopol", "Ivano-Frankovsk": "Ivano-Frankivsk", "Cherkassy": "Cherkasy",
    "Chernovtsy": "Chernivtsi", "Uzhgorod": "Uzhhorod", "Krivoy Rog": "Kryvyi Rih",
    "Kryvyy Rih": "Kryvyi Rih", "Khmelnytskyy": "Khmelnytskyi", "Ternopol": "Ternopil",
    "Mariupol'": "Mariupol", "Sumy": "Sumy", "Poltava": "Poltava", "Luts'k": "Lutsk",
    "Lutsk": "Lutsk", "Dnipropetrovs'k": "Dnipro", "Kirovohrad Oblast": "Kropyvnytskyi",
    "Mahilioŭ": "Mogilev", "Kramatorsk": "Kramatorsk", "Sevastopol'": "Sevastopol",
    "Autonomous Republic of Crimea": "Crimea", "Dnipropetrovsk Oblast": "Dnipro",
    "Mykolayiv": "Mykolaiv", "Vinnytsya": "Vinnytsia", "Orel": "Oryol", "Naltchik": "Nalchik",
    "Groznyy": "Grozny", "Izmayil": "Izmail", "Yevpatoriya": "Yevpatoria",
    "Kamyanets-Podilskyy": "Kamianets-Podilskyi", "Kerch": "Kerch", "Berdyansk": "Berdiansk",
    "Kupyansk": "Kupiansk", "Melitopol": "Melitopol", "Kremenchuk": "Kremenchuk",
}

# Resources of rural provinces, by region code. Order = preference.
REGION_RES = {
    "UA-12": ["metal", "rare", "food"], "UA-14": ["metal", "metal", "food"],
    "UA-09": ["metal", "food"], "UA-23": ["metal", "rare", "food"],
    "UA-65": ["food", "food"], "UA-48": ["food"], "UA-51": ["food", "food"],
    "UA-35": ["rare", "food"], "UA-53": ["oil", "food", "metal"], "UA-63": ["oil", "food"],
    "UA-71": ["food"], "UA-05": ["food"], "UA-68": ["food"], "UA-61": ["food"],
    "UA-18": ["rare", "food"], "UA-26": ["oil"], "UA-46": ["oil", "food"],
    "UA-43": ["food", "oil"], "UA-74": ["food", "oil"], "UA-59": ["food", "oil"],
    "RU-KRS": ["metal", "food"], "RU-BEL": ["metal", "food"], "RU-LIP": ["metal", "food"],
    "RU-VOR": ["food"], "RU-ROS": ["food", "metal"], "RU-KDA": ["food", "oil"],
    "RU-STA": ["food", "oil"], "RU-VGG": ["oil", "food"], "RU-AST": ["oil"],
    "RU-SAR": ["oil", "food"], "RU-KL": ["oil"], "RU-CE": ["oil"], "RU-DA": ["oil"],
    "RU-KB": ["rare"], "RU-SE": ["rare"], "RU-TAM": ["food"], "RU-TUL": ["metal"],
    "RU-ORL": ["food"], "RU-PNZ": ["food"],
}

CARPATHIANS = shapely.Polygon([(22.3, 48.95), (23.6, 49.15), (25.0, 48.65), (25.7, 47.95),
                               (24.8, 47.65), (23.5, 47.85), (22.4, 48.2)])


def proj(lon, lat):
    return (lon - LON0) * KX, (LAT0 - lat) * KZ


def unproj(x, z):
    return x / KX + LON0, LAT0 - z / KZ


def project_geom(g):
    return shapely.transform(g, lambda c: np.column_stack([(c[:, 0] - LON0) * KX, (LAT0 - c[:, 1]) * KZ]))


def fix_name(n):
    return NAME_FIX.get(n, n)


def largest_poly(g):
    if g.geom_type == "Polygon":
        return g
    return max(g.geoms, key=lambda p: p.area)


def interior_point(g):
    p = largest_poly(g)
    try:
        return polylabel(p, tolerance=1.0)
    except Exception:
        return p.representative_point()


def polys_of(g):
    if g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    if g.geom_type == "MultiPolygon":
        return list(g.geoms)
    return [x for sub in getattr(g, "geoms", []) for x in polys_of(sub)]


def clean(g):
    g = shapely.make_valid(g)
    ps = [p for p in polys_of(g) if p.area > 1e-6]
    return shapely.MultiPolygon(ps) if len(ps) > 1 else (ps[0] if ps else shapely.Polygon())


def kmeans(points, k, rng, iters=25):
    cent = points[rng.choice(len(points), k, replace=False)]
    for _ in range(iters):
        d = ((points[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        for i in range(k):
            m = points[lab == i]
            if len(m):
                cent[i] = m.mean(0)
    return cent


def sample_in(poly, n, rng):
    minx, miny, maxx, maxy = poly.bounds
    out = []
    prepared = shapely.prepared.prep(poly)
    while len(out) < n:
        xs = rng.uniform(minx, maxx, n)
        ys = rng.uniform(miny, maxy, n)
        for x, y in zip(xs, ys):
            if prepared.contains(Point(x, y)):
                out.append((x, y))
                if len(out) >= n:
                    break
    return np.array(out)


def split_region(geom, k, rng):
    if k <= 1:
        return [geom]
    pts = sample_in(geom, 1500, rng)
    seeds = kmeans(pts, k, rng)
    cells = shapely.voronoi_polygons(MultiPoint([tuple(s) for s in seeds]), extend_to=geom.envelope.buffer(10))
    parts = []
    for c in cells.geoms:
        piece = clean(geom.intersection(c))
        if not piece.is_empty:
            parts.append(piece)
    return parts


def terrain_for(region, lon, lat, kind, owner):
    if kind == "sea":
        return "water"
    if kind == "city":
        return "urban"
    pt = Point(lon, lat)
    if CARPATHIANS.contains(pt):
        return "mountains"
    if region in ("UA-43", "UA-40") and lat < 45.0 and 33.4 < lon < 35.4:
        return "mountains"
    if lat < 43.95 and lon > 38.6:
        return "mountains"
    if region in ("RU-KB", "RU-SE", "RU-IN", "RU-CE", "RU-KC") and lat < 43.6:
        return "mountains"
    if region in ("RU-KL", "RU-AST"):
        return "desert"
    if region == "RU-DA" and lat > 43.6:
        return "desert"
    if region == "RU-VGG" and lon > 45.6:
        return "desert"
    if owner == "UKR" and lat > 50.75:
        return "forest"  # Polissia
    if region in ("UA-07", "UA-56"):
        return "forest"
    if owner == "BLR":
        return "forest"
    if region in ("RU-SMO", "RU-BRY", "RU-KLU", "RU-MOW", "RU-MOS", "RU-TVE", "RU-VLA", "RU-MO"):
        return "forest"
    if owner == "RUS" and lat > 54.4:
        return "forest"
    if region in ("UA-46", "UA-61", "UA-68", "UA-05", "UA-77", "UA-26", "UA-21"):
        return "hills"
    if region in ("UA-14", "UA-09") and 47.8 < lat < 48.7 and 37.4 < lon < 40.2:
        return "hills"  # Donets Ridge
    if region in ("UA-43",) and lat < 45.3:
        return "hills"
    if region in ("RU-KRS", "RU-BEL", "RU-ORL", "RU-TUL", "RU-PNZ", "RU-STA", "RU-KC", "RU-KB", "RU-SE", "RU-IN", "RU-CE"):
        return "hills"
    if region == "RU-SAR" and lon < 46.0:
        return "hills"
    if region == "RU-VOR" and lon < 39.6:
        return "hills"
    return "plains"


def main():
    ne_dir, game_dir = sys.argv[1], sys.argv[2]
    rng = np.random.default_rng(7)

    def load(name):
        with open(os.path.join(ne_dir, name), encoding="utf-8") as f:
            return json.load(f)["features"]

    bbox_ll = box(*BBOX)
    bbox_p = project_geom(bbox_ll)

    # ---- playable regions (Ukraine + Russia admin-1) -------------------------------------
    regions = []
    for f in load("ne_10m_admin_1_states_provinces.geojson"):
        p = f["properties"]
        iso = p.get("iso_3166_2") or ""
        if p["adm0_a3"] not in ("UKR", "RUS", "BLR"):
            continue
        g = shape(f["geometry"])
        if not g.intersects(bbox_ll):
            continue
        g = clean(g.intersection(bbox_ll))
        owner = "UKR" if iso.startswith("UA-") else p["adm0_a3"]
        gp = clean(project_geom(g))
        if gp.area < 800:
            continue
        name = fix_name(p.get("name_en") or p["name"])
        regions.append({"iso": iso, "owner": owner, "name": name, "geom": gp})

    # Sequential difference: no two regions overlap.
    taken = shapely.Polygon()
    for r in regions:
        r["geom"] = clean(r["geom"].difference(taken))
        taken = taken.union(r["geom"])
    regions = [r for r in regions if not r["geom"].is_empty]
    print("regions", len(regions))

    # ---- cities ----------------------------------------------------------------------
    places = []
    for f in load("ne_10m_populated_places_simple.geojson"):
        p = f["properties"]
        lon, lat = f["geometry"]["coordinates"]
        if not (BBOX[0] <= lon <= BBOX[2] and BBOX[1] <= lat <= BBOX[3]):
            continue
        places.append({
            "name": fix_name(p.get("nameascii") or p["name"]), "lon": lon, "lat": lat,
            "pop": p.get("pop_max") or 0, "cls": p.get("featurecla") or "",
            "capital": "Admin-0 capital" in (p.get("featurecla") or ""),
            "admin1cap": "Admin-1" in (p.get("featurecla") or ""),
            "xz": proj(lon, lat),
        })
    places.sort(key=lambda c: -c["pop"])

    whole_city_regions = {"UA-30": "Kyiv", "RU-MOS": "Moscow", "UA-40": "Sevastopol"}
    city_specs = []
    for c in places:
        if c["name"] in whole_city_regions.values():
            continue
        big = c["pop"] >= 350000 or (c["admin1cap"] and c["pop"] >= 120000) or c["capital"]
        if not big:
            continue
        pt = Point(c["xz"])
        reg = next((r for r in regions if r["owner"] in ("UKR", "RUS") and r["geom"].contains(pt)), None)
        if reg is None or reg["iso"] in whole_city_regions:
            continue
        if any(math.dist(c["xz"], o["xz"]) < 40 for o in city_specs):
            continue
        city_specs.append({**c, "region": reg})
    print("cities", len(city_specs) + len(whole_city_regions))

    provinces = []

    def add(name, kind, owner, region, geom, center=None, pop=0, capital=False):
        provinces.append({"name": name, "kind": kind, "owner": owner, "region": region,
                          "geom": geom, "center": center, "pop": pop, "capital": capital})

    # Whole-region cities (Kyiv, Moscow, Sevastopol) keep their admin polygon.
    used_names = set()
    for r in regions:
        if r["iso"] in whole_city_regions:
            cname = whole_city_regions[r["iso"]]
            c = next((p for p in places if p["name"] == cname), None)
            add(cname, "city", r["owner"], r["iso"], r["geom"], c["xz"] if c else None,
                c["pop"] if c else 0, capital=bool(c and c["capital"]))
            used_names.add(cname)

    city_geoms = {}
    for c in city_specs:
        reg = c["region"]
        r_km = max(9.0, min(22.0, 9.0 + 7.0 * math.log10(max(c["pop"], 1e5) / 1e5)))
        disk = Point(c["xz"]).buffer(r_km, 24)
        g = clean(disk.intersection(reg["geom"]))
        for og in city_geoms.values():
            g = clean(g.difference(og))
        if g.is_empty or g.area < 80:
            continue
        city_geoms[c["name"]] = g
        add(c["name"], "city", reg["owner"], reg["iso"], g, c["xz"], c["pop"], capital=c["capital"])
        used_names.add(c["name"])

    all_cities = unary_union(list(city_geoms.values())) if city_geoms else shapely.Polygon()

    # ---- rural provinces --------------------------------------------------------------
    for r in regions:
        if r["iso"] in whole_city_regions:
            continue
        rest = clean(r["geom"].difference(all_cities))
        if rest.is_empty:
            continue
        if r["owner"] == "BLR":
            add(r["name"], "rural", "BLR", r["iso"], rest)
            continue
        k = max(1, round(rest.area / RURAL_TARGET_KM2))
        parts = split_region(rest, k, rng)
        for i, part in enumerate(parts):
            # Name after the biggest town inside the part.
            town = None
            for pl in places:
                if pl["name"] in used_names:
                    continue
                if part.contains(Point(pl["xz"])):
                    town = pl
                    break
            if town:
                nm = town["name"]
                used_names.add(nm)
            else:
                cx, cz = part.centroid.x - rest.centroid.x, part.centroid.y - rest.centroid.y
                ang = math.degrees(math.atan2(-cz, cx)) % 360
                dirs = ["East", "Northeast", "North", "Northwest", "West", "Southwest", "South", "Southeast"]
                nm = f"{r['name']} {dirs[int((ang + 22.5) // 45) % 8]}" if len(parts) > 1 else r["name"]
            add(nm, "rural", r["owner"], r["iso"], part)

    # ---- neutral countries -------------------------------------------------------------
    playable_union = unary_union([p["geom"] for p in provinces])
    land_parts = [playable_union]
    for f in load("ne_10m_admin_0_countries.geojson"):
        p = f["properties"]
        code = p.get("ADM0_A3")
        if code not in NEUTRAL_COUNTRIES and code not in ("RUS", "UKR", "BLR"):
            continue
        g = shape(f["geometry"])
        if not g.intersects(bbox_ll):
            continue
        gp = clean(project_geom(clean(g.intersection(bbox_ll))))
        gp = clean(gp.difference(unary_union(land_parts)))
        if gp.is_empty:
            continue
        land_parts.append(gp)
        if code in NEUTRAL_COUNTRIES:
            add(NEUTRAL_COUNTRIES[code], "neutral", code, code, gp)
        else:
            # Coastline mismatches between datasets: fold into neighbours later.
            for poly in polys_of(gp):
                add("_sliver", "sliver", code, code, poly)

    # ---- seas --------------------------------------------------------------------------
    land = unary_union(land_parts)
    water = clean(bbox_p.difference(land))
    zones = [
        ("Caspian Sea", project_geom(box(46.3, 41.0, 49.0, 47.6))),
        ("Sea of Azov", project_geom(box(34.75, 45.27, 39.6, 47.4))),
        ("Western Black Sea", project_geom(box(20.0, 40.0, 33.0, 47.0))),
        ("Eastern Black Sea", project_geom(box(33.0, 40.0, 42.0, 45.27))),
    ]
    rest = water
    for name, z in zones:
        g = clean(rest.intersection(z))
        rest = clean(rest.difference(z))
        big = [p for p in polys_of(g) if p.area > 2000]
        small = [p for p in polys_of(g) if p.area <= 2000]
        if big:
            add(name, "sea", "SEA", name, clean(unary_union(big)))
        for s in small:
            add("_sliver", "sliver", "SEA", name, s)
    for p in polys_of(rest):
        add("_sliver", "sliver", "SEA", "lake", p)

    # ---- fold slivers and tiny parts into neighbours ------------------------------------
    def fold_small():
        changed = True
        while changed:
            changed = False
            geoms = [p["geom"] for p in provinces]
            tree = shapely.STRtree(geoms)
            for i, p in enumerate(provinces):
                parts = polys_of(p["geom"])
                if not parts:
                    continue
                main_area = max(q.area for q in parts)
                for q in parts:
                    small = p["kind"] == "sliver" or q.area < MIN_PART_KM2 or (q.area < 0.02 * main_area and q.area < 400)
                    if not small:
                        continue
                    best, best_len = None, 0.0
                    for j in tree.query(q.buffer(0.05)):
                        if j == i or provinces[j]["kind"] == "sliver" or provinces[j]["geom"].is_empty:
                            continue
                        ln = q.boundary.intersection(provinces[j]["geom"].buffer(0.05)).length
                        if ln > best_len:
                            best, best_len = j, ln
                    if best is None:
                        continue
                    provinces[best]["geom"] = clean(provinces[best]["geom"].union(q))
                    p["geom"] = clean(p["geom"].difference(q))
                    changed = True
                if changed:
                    break

    fold_small()
    provinces[:] = [p for p in provinces if p["kind"] != "sliver" and not p["geom"].is_empty]
    print("provinces before simplify", len(provinces))

    # ---- rebuild as an exact coverage ----------------------------------------------------
    # Node every boundary into one line network and polygonize it, then give each face to
    # the province that contains it. Every border then exists exactly once, so neighbouring
    # provinces never overlap (double rendering) or leave gaps (holes in the map).
    geoms = [p["geom"] for p in provinces]
    linework = unary_union([g.boundary for g in geoms] + [bbox_p.boundary])
    faces = list(shapely.polygonize(list(getattr(linework, "geoms", [linework]))).geoms)
    tree = shapely.STRtree(geoms)
    owned = [[] for _ in provinces]
    for face in faces:
        if not bbox_p.buffer(0.01).contains(face):
            continue
        rp = face.representative_point()
        hits = [j for j in tree.query(rp) if geoms[j].contains(rp)]
        if not hits:
            hits = sorted(tree.query(face.buffer(0.1)), key=lambda j: -face.boundary.intersection(geoms[j].buffer(0.1)).length)
        if hits:
            owned[hits[0]].append(face)
    for p, fs in zip(provinces, owned):
        p["geom"] = clean(unary_union(fs)) if fs else shapely.Polygon()
    provinces[:] = [p for p in provinces if not p["geom"].is_empty]

    # ---- topology-preserving simplification --------------------------------------------
    geoms = [p["geom"] for p in provinces]
    print("coverage valid:", shapely.coverage_is_valid(geoms, gap_width=0.0))
    simp = shapely.coverage_simplify(geoms, SIMPLIFY_KM)
    for p, g in zip(provinces, simp):
        p["geom"] = clean(g)
    provinces[:] = [p for p in provinces if not p["geom"].is_empty]
    print("coverage valid after simplify:", shapely.coverage_is_valid([p["geom"] for p in provinces], gap_width=0.0))

    # ---- attributes --------------------------------------------------------------------
    for idx, p in enumerate(provinces):
        p["id"] = idx
        if p["center"] is None or not p["geom"].buffer(0.5).contains(Point(p["center"])):
            pt = interior_point(p["geom"])
            p["center"] = (pt.x, pt.y)
        lon, lat = unproj(*p["center"])
        p["terrain"] = terrain_for(p["region"], lon, lat, p["kind"], p["owner"])
        area = p["geom"].area
        res = {}
        if p["kind"] == "city":
            pop = max(p["pop"], 100000)
            res["money"] = round(40 + 30 * math.log10(pop / 1e5) * 2, 1)
            res["manpower"] = round(25 + 20 * math.log10(pop / 1e5), 1)
            prefs = REGION_RES.get(p["region"], ["food"])
            res[prefs[0]] = round(res.get(prefs[0], 0) + 30, 1)
            p["vp"] = 15 if p["capital"] else 10
        elif p["kind"] == "rural":
            res["money"] = round(8 + area / 2500, 1)
            res["manpower"] = round(5 + area / 4000, 1)
            prefs = REGION_RES.get(p["region"])
            if prefs and (idx % 5) != 4:
                r = prefs[idx % len(prefs)]
                res[r] = 14.0
            p["vp"] = 1
        else:
            p["vp"] = 0
        p["res"] = res

    # ---- shared edges + adjacency -----------------------------------------------------
    geoms = [p["geom"] for p in provinces]
    tree = shapely.STRtree(geoms)
    edges = []
    adj = [set() for _ in provinces]
    for i, g in enumerate(geoms):
        for j in tree.query(g):
            if j <= i:
                continue
            shared = g.boundary.intersection(geoms[j].boundary)
            if shared.is_empty:
                continue
            merged = shapely.line_merge(shapely.MultiLineString([ls for ls in getattr(shared, "geoms", [shared]) if ls.geom_type == "LineString"])) if shared.geom_type != "LineString" else shared
            lines = [ls for ls in getattr(merged, "geoms", [merged]) if ls.geom_type == "LineString"]
            total = sum(ls.length for ls in lines)
            if total < 0.5:
                continue
            for ls in lines:
                if ls.length < 0.2:
                    continue
                edges.append({"a": i, "b": int(j), "p": [round(v, 2) for xy in ls.coords for v in xy]})
            if total > 2.0:
                adj[i].add(int(j))
                adj[int(j)].add(i)

    # Kerch Strait crossing (bridge): connect eastern Crimea with Taman.
    def nearest(lon, lat, owner_filter=None, kinds=("rural", "city")):
        x, z = proj(lon, lat)
        cands = [p for p in provinces if p["kind"] in kinds and (owner_filter is None or p["region"] in owner_filter)]
        return min(cands, key=lambda p: p["geom"].distance(Point(x, z)))
    a = nearest(36.4, 45.35, ("UA-43",))
    b = nearest(36.75, 45.25, ("RU-KDA",))
    adj[a["id"]].add(b["id"])
    adj[b["id"]].add(a["id"])

    # ---- triangulation -----------------------------------------------------------------
    out_prov = []
    for p in provinces:
        tris = []
        for poly in polys_of(p["geom"]):
            for t in shapely.constrained_delaunay_triangles(poly).geoms:
                c = list(t.exterior.coords)[:3]
                for xy in c:
                    tris += [round(xy[0], 2), round(xy[1], 2)]
        out_prov.append({
            "id": p["id"], "name": p["name"], "kind": p["kind"], "owner": p["owner"],
            "region": p["region"], "terrain": p["terrain"], "vp": p.get("vp", 0),
            "capital": p["capital"], "res": p["res"], "area": round(p["geom"].area),
            "center": [round(p["center"][0], 2), round(p["center"][1], 2)],
            "adj": sorted(adj[p["id"]]), "tris": tris,
        })

    # ---- country labels --------------------------------------------------------------------
    countries = []
    names = {"UKR": "Ukraine", "RUS": "Russia", "BLR": "Belarus", **NEUTRAL_COUNTRIES}
    for code in sorted({p["owner"] for p in provinces if p["owner"] != "SEA"}):
        g = unary_union([p["geom"] for p in provinces if p["owner"] == code])
        big = largest_poly(g)
        pt = interior_point(big)
        rect = big.minimum_rotated_rectangle
        cs = list(rect.exterior.coords)
        e1 = (cs[1][0] - cs[0][0], cs[1][1] - cs[0][1])
        e2 = (cs[2][0] - cs[1][0], cs[2][1] - cs[1][1])
        major = e1 if math.hypot(*e1) >= math.hypot(*e2) else e2
        ang = math.degrees(math.atan2(major[1], major[0]))
        if ang > 90:
            ang -= 180
        if ang < -90:
            ang += 180
        if abs(ang) > 60:
            ang = 0.0
        countries.append({"code": code, "name": names.get(code, code), "label": [round(pt.x, 1), round(pt.y, 1)],
                          "angle": round(ang, 1), "size": round(min(max(math.hypot(*major), 120), 900), 1)})
    for z in ("Western Black Sea", "Eastern Black Sea", "Sea of Azov", "Caspian Sea"):
        sp = next((p for p in provinces if p["name"] == z), None)
        if sp:
            pt = interior_point(sp["geom"])
            countries.append({"code": "SEA", "name": z.replace("Western ", "").replace("Eastern ", ""), "label": [round(pt.x, 1), round(pt.y, 1)], "angle": 0.0, "size": 300.0})

    xmin, zmin, xmax, zmax = bbox_p.bounds
    data = {
        "projection": {"lon0": LON0, "lat0": LAT0, "kx": KX, "kz": KZ},
        "bounds": [round(xmin, 2), round(zmin, 2), round(xmax, 2), round(zmax, 2)],
        "provinces": out_prov, "edges": edges, "countries": countries,
        "source": "Natural Earth 1:10m (public domain), processed by tools/build_map.py",
    }
    os.makedirs(os.path.join(game_dir, "data"), exist_ok=True)
    with open(os.path.join(game_dir, "data", "map.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"), ensure_ascii=False)

    # ---- relief / water texture ------------------------------------------------------
    W = 2048
    H = round(W * (zmax - zmin) / (xmax - xmin))
    sr = Image.open(os.path.join(ne_dir, "sr", "SR_HR.tif"))
    ppd = sr.size[0] / 360.0
    crop = sr.crop((round((BBOX[0] + 180) * ppd), round((90 - BBOX[3]) * ppd),
                    round((BBOX[2] + 180) * ppd), round((90 - BBOX[1]) * ppd)))
    relief = crop.resize((W, H), Image.LANCZOS).convert("L")

    def to_px(x, z):
        return ((x - xmin) / (xmax - xmin) * W, (z - zmin) / (zmax - zmin) * H)

    water = Image.new("L", (W, H), 0)
    dw = ImageDraw.Draw(water)

    def fill(g, val):
        for poly in polys_of(g):
            dw.polygon([to_px(*c) for c in poly.exterior.coords], fill=val)
            for hole in poly.interiors:
                dw.polygon([to_px(*c) for c in hole.coords], fill=0)

    for p in provinces:
        if p["kind"] == "sea":
            fill(p["geom"], 255)
    for f in load("ne_10m_lakes.geojson"):
        g = shape(f["geometry"])
        if g.intersects(bbox_ll):
            fill(project_geom(clean(g.intersection(bbox_ll))), 255)
    sea_mask = water.copy()
    for f in load("ne_10m_rivers_lake_centerlines.geojson"):
        sr_rank = f["properties"].get("scalerank", 10)
        if sr_rank > 7:
            continue
        g = shape(f["geometry"])
        if not g.intersects(bbox_ll):
            continue
        g = project_geom(g.intersection(bbox_ll))
        width = 3 if sr_rank <= 3 else 2
        for ls in getattr(g, "geoms", [g]):
            if ls.geom_type == "LineString":
                dw.line([to_px(*c) for c in ls.coords], fill=255, width=width, joint="curve")
    coast = Image.eval(sea_mask, lambda v: 255 - v).filter(ImageFilter.GaussianBlur(7))
    os.makedirs(os.path.join(game_dir, "textures"), exist_ok=True)
    Image.merge("RGB", (relief, coast, water)).save(os.path.join(game_dir, "textures", "relief.png"), optimize=True)
    print("provinces", len(out_prov), "edges", len(edges), "texture", W, H)


if __name__ == "__main__":
    main()
