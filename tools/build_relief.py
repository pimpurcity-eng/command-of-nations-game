#!/usr/bin/env python3
"""Bake a shaded-relief texture for the game map from Natural Earth (public domain).

Usage: python3 tools/build_relief.py <SR_HR.tif> game/assets/materials/relief.png

The texture covers the game's terrain extent ORIGIN (-24,-27) .. ORIGIN+EXTENT (26,21) in map
units (see scripts/terrain_visual_map.gd). The game projection is linear in longitude and
latitude (scripts/geographic_projection.gd), so the matching lon/lat window is a plain crop.
"""
import math
import sys

from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ORIGIN = (-24.0, -27.0)
EXTENT = (50.0, 48.0)
K = 2.6 * math.cos(math.radians(50.0))


def lon(x):
    return x / K + 32.0


def lat(z):
    return 50.0 - z / 2.6


def main():
    src, dst = sys.argv[1], sys.argv[2]
    sr = Image.open(src)
    ppd = sr.size[0] / 360.0
    lon0, lon1 = lon(ORIGIN[0]), lon(ORIGIN[0] + EXTENT[0])
    lat0, lat1 = lat(ORIGIN[1]), lat(ORIGIN[1] + EXTENT[1])  # north, south
    crop = sr.crop((round((lon0 + 180) * ppd), round((90 - lat0) * ppd),
                    round((lon1 + 180) * ppd), round((90 - lat1) * ppd)))
    width = 1024
    height = round(width * EXTENT[1] / EXTENT[0])
    crop.resize((width, height), Image.LANCZOS).convert("L").save(dst, optimize=True)
    print(f"relief {width}x{height} lon {lon0:.2f}..{lon1:.2f} lat {lat1:.2f}..{lat0:.2f}")


if __name__ == "__main__":
    main()
