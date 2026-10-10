#!/usr/bin/env python3
"""Repair the game's province polygons so neighbouring provinces share exact borders.

The recovered data/administrative_regions.json had 67 overlapping province pairs and 76
small gaps (each province was simplified on its own). Overlapping meshes are drawn twice at
the same height, which flickers (the "doubled rendering"), and gaps show the sea through the
land. Neighbouring-country outlines (Belarus, Romania, ...) also overlapped Ukraine/Russia.

This tool keeps every feature, its id, name, country, centre and the order/number of its
polygon pieces (territory ids and saved games depend on them). Only the shapes change:

1. Node all province borders into one line network and polygonize it.
2. Give every face to the original piece that contains it; small gaps go to the neighbour
   sharing the longest border. Every border then exists exactly once.
3. Rebuild mesh_polygons (hole-free patches that Godot can triangulate).
4. Cut the Ukraine/Russia provinces out of the neighbouring countries.

Usage: python3 tools/repair_regions.py game/data
"""
import json
import math
import sys

import shapely
from shapely.geometry import Polygon, MultiPolygon, box, mapping, shape
from shapely.ops import unary_union

MAX_GAP_DEG2 = 0.05  # only fill small slivers, never real water bodies
NEIGHBOURS = ["BLR", "POL", "ROU", "MDA", "GEO", "TUR", "SVK", "HUN", "LVA", "LTU", "EST", "FIN",
              "BGR", "SRB", "DEU", "CZE", "AZE", "ARM"]


def polys(g):
    if g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    out = []
    for p in getattr(g, "geoms", []):
        out += polys(p)
    return out


def clean(g):
    return unary_union([p for p in polys(shapely.make_valid(g)) if p.area > 1e-12])


def game_bounds():
    # RegionData clips everything to projected (-24,-27)..(26,21); convert to lon/lat.
    k = 2.6 * math.cos(math.radians(50.0))
    lon = lambda x: x / k + 32.0
    lat = lambda y: 50.0 - y / 2.6
    return box(lon(-24), lat(21), lon(26), lat(-27))


def ring(coords):
    c = [[round(x, 6), round(y, 6)] for x, y in coords]
    if c[0] != c[-1]:
        c.append(c[0])
    return c


def mesh_patches(p):
    """Hole-free patches covering polygon p (Godot's triangulate_polygon has no holes)."""
    if not p.interiors:
        return [ring(p.exterior.coords)]
    return [ring(list(t.exterior.coords)[:3]) for t in shapely.constrained_delaunay_triangles(p).geoms]


def main():
    data_dir = sys.argv[1]
    path = f"{data_dir}/administrative_regions.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    # ---- collect pieces exactly as RegionData.territories() enumerates them ------------------
    pieces = []  # {"feature": i, "slot": polygon_index, "geom": Polygon}
    for fi, feat in enumerate(data["features"]):
        geom = feat["geometry"]
        rings = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for pi, poly in enumerate(rings):
            g = Polygon(poly[0], poly[1:])
            pieces.append({"feature": fi, "slot": pi, "geom": clean(g)})
    geoms = [p["geom"] for p in pieces]
    before_overlaps = sum(1 for i, g in enumerate(geoms) for j in shapely.STRtree(geoms).query(g)
                          if j > i and g.intersection(geoms[j]).area > 1e-9)

    # ---- polygonize the noded border network ----------------------------------------------
    lines = unary_union([g.boundary for g in geoms])
    faces = list(shapely.polygonize(list(getattr(lines, "geoms", [lines]))).geoms)
    tree = shapely.STRtree(geoms)
    owned = [[] for _ in pieces]
    gaps = []
    for face in faces:
        rp = face.representative_point()
        hits = [j for j in tree.query(rp) if geoms[j].contains(rp)]
        if hits:
            owned[min(hits)].append(face)
        else:
            gaps.append(face)
    new = [clean(unary_union(fs)) if fs else shapely.Polygon() for fs in owned]
    filled = 0
    for face in gaps:
        if face.area > MAX_GAP_DEG2:
            continue  # a real hole (lake / inland sea), leave it
        best, best_len = None, 0.0
        for j in tree.query(face.buffer(1e-7)):
            ln = face.boundary.intersection(new[j].buffer(1e-7)).length
            if ln > best_len:
                best, best_len = j, ln
        if best is not None:
            new[best] = clean(new[best].union(face))
            filled += 1

    # Every piece must stay one polygon: hand detached crumbs to the neighbour.
    for i, g in enumerate(new):
        parts = polys(g)
        if len(parts) <= 1:
            continue
        parts.sort(key=lambda p: -p.area)
        new[i] = parts[0]
        for crumb in parts[1:]:
            best, best_len = None, 0.0
            for j, other in enumerate(new):
                if j == i:
                    continue
                ln = crumb.boundary.intersection(other.buffer(1e-7)).length
                if ln > best_len:
                    best, best_len = j, ln
            if best is not None:
                new[best] = clean(new[best].union(crumb))

    for i, g in enumerate(new):
        parts = polys(g)
        assert len(parts) == 1, f"piece {i} split into {len(parts)} parts"
        new[i] = parts[0]

    assert shapely.coverage_is_valid(new), "province coverage still has overlaps"
    after_overlaps = sum(1 for i, g in enumerate(new) for j in shapely.STRtree(new).query(g)
                         if j > i and g.intersection(new[j]).area > 1e-9)

    # ---- write provinces back --------------------------------------------------------------
    for fi, feat in enumerate(data["features"]):
        mine = [(p["slot"], new[k]) for k, p in enumerate(pieces) if p["feature"] == fi]
        mine.sort()
        coords = [[ring(g.exterior.coords)] + [ring(h.coords) for h in g.interiors] for _, g in mine]
        if len(coords) == 1:
            feat["geometry"] = {"type": "Polygon", "coordinates": coords[0]}
        else:
            feat["geometry"] = {"type": "MultiPolygon", "coordinates": coords}
        feat["mesh_polygons"] = [mesh_patches(g) for _, g in mine]
    data["source"] = data.get("source", "") + " Repaired to an exact coverage by tools/repair_regions.py."
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    # ---- neighbouring countries: cut out Ukraine/Russia provinces ----------------------------
    land = unary_union(new)
    bounds = game_bounds()
    trimmed = 0
    for code in NEIGHBOURS:
        cpath = f"{data_dir}/{code}.geo.json"
        with open(cpath, encoding="utf-8") as f:
            cdata = json.load(f)
        feat = cdata["features"][0]
        geom = feat["geometry"]
        rings = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        out = []
        for poly in rings:
            outer = Polygon(poly[0])
            if not outer.intersects(bounds) or not outer.intersects(land):
                out.append(poly)
                continue
            cut = [p for p in polys(clean(outer.difference(land))) if p.area > 1e-6]
            if not cut:
                out.append(poly)
                continue
            # keep one ring per original ring so territory ids stay stable
            main = max(cut, key=lambda p: p.area)
            out.append([ring(main.exterior.coords)])
            trimmed += 1
        feat["geometry"] = {"type": "MultiPolygon", "coordinates": out} if geom["type"] == "MultiPolygon" else {"type": "Polygon", "coordinates": out[0]}
        with open(cpath, "w", encoding="utf-8") as f:
            json.dump(cdata, f, ensure_ascii=False, separators=(",", ":"))

    print(f"pieces={len(pieces)} overlapping pairs before={before_overlaps} after={after_overlaps} "
          f"gaps filled={filled} neighbour rings trimmed={trimmed}")


if __name__ == "__main__":
    main()
