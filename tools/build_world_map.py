#!/usr/bin/env python3
"""Build the 100-player world map (owner request 2026-10-12) from Natural Earth.

Usage:
    python3 tools/build_world_map.py <natural_earth_dir> game

Same builder as the Europe map (tools/build_europe_map.py) with world settings:
- 100 player countries, chosen by size and economy (sqrt(GDP x area), at least 40,000 km²)
  so every continent is represented, plus all 20 Europe-map countries. Each has
  PLAYER_PROVINCES provinces and 5 cities.
- Every other country is an AI country (not a player slot) with one city.
- The whole of Russia (it is a world map); Antarctica is left out.
- Equal Earth projection (equal-area, true country sizes) at half the regional scale, so the
  world fits a phone (about 400 x 170 map units).

Writes game/data/maps/world100/ and game/assets/materials/{relief,coast}_world100.png.
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_europe_map as b  # noqa: E402

PLAYER_CODES = [
    "USA", "CHN", "RUS", "CAN", "BRA", "AUS", "IND", "MEX", "IDN", "JPN", "FRA", "SAU", "DEU", "ARG",
    "IRN", "ESP", "GBR", "ITA", "TUR", "VEN", "ZAF", "NGA", "DZA", "COL", "EGY", "PER", "THA", "PAK",
    "SWE", "CHL", "POL", "KOR", "NOR", "MYS", "COD", "AGO", "PHL", "ETH", "IRQ", "FIN", "UKR", "VNM",
    "LBY", "MAR", "TZA", "ROU", "SDN", "KEN", "NZL", "MMR", "BOL", "BGD", "AUT", "ARE", "CHE", "GRC",
    "ECU", "IRL", "UZB", "OMN", "MNG", "PRT", "MLI", "CZE", "TKM", "CIV", "SYR", "CMR", "ZMB", "GHA",
    "NER", "PRY", "HUN", "DNK", "TCD", "BLR", "AFG", "MOZ", "PNG", "BWA", "YEM", "NAM", "URY", "UGA",
    "MDG", "GTM", "ZWE", "MRT", "BGR", "SDS", "TUN", "LKA", "SVK", "PAN", "KHM", "PRK", "SEN", "NPL",
    "KAZ", "SRB",
]
NAMES = {"USA": "United States", "COD": "DR Congo", "SDS": "South Sudan", "CIV": "Ivory Coast",
         "PRK": "North Korea", "KOR": "South Korea", "ARE": "UAE", "GBR": "United Kingdom",
         "CZE": "Czechia"}
# Europe-map colours stay the same on the world map.
EUROPE = {code: color for _, code, _, color in b.PLAYERS}


def main():
    import json
    a0 = json.load(open(os.path.join(sys.argv[1], "ne_10m_admin_0_countries.geojson"), encoding="utf-8"))
    names = {}
    for feat in a0["features"]:
        p = feat["properties"]
        names.setdefault(p["ADM0_A3"], NAMES.get(p["ADM0_A3"], b.short_name(p)))
    assert len(PLAYER_CODES) == 100 and len(set(PLAYER_CODES)) == 100
    players = []
    for i, code in enumerate(PLAYER_CODES):
        name = names[code]
        cid = "".join(ch if ch.isalnum() else "_" for ch in name.lower()).strip("_")
        if code in EUROPE:
            color = EUROPE[code]
            cid = next(c for c, k, _, _ in b.PLAYERS if k == code)
        else:
            h = (i * 0.618034) % 1.0
            r, g, bl = colorsys.hsv_to_rgb(h, 0.42 + 0.18 * (i % 3) / 2, 0.62 + 0.22 * ((i // 3) % 3) / 2)
            color = "%02x%02x%02x" % (int(r * 255), int(g * 255), int(bl * 255))
        players.append((cid, code, name, color))
    b.PLAYERS = players
    b.AI = None
    b.MAP_ID = "world100"
    b.MAP_NAME = "World (100 players)"
    b.PROJECTION = "equal_earth"
    b.LON0, b.LAT0 = 0.0, 0.0
    b.SCALE = 2.6 / 111.0 * 0.5
    b.USE_REGIONAL = False
    b.ROUGH = (-180, -58, 180, 84)
    b.CLIP = (-180, -58, 180, 84)
    b.SIMPLIFY_DEG = 0.04
    b.MIN_PROVINCE_KM2 = 90000.0
    b.MIN_PART_KM2 = 400.0
    b.MIN_COUNTRY_KM2 = 2500.0
    b.DROP = {"ATF", "ATA", "HMD", "SGS", "BVT"}
    b.ISLAND_JOIN_KM = 350.0
    b.PLAYER_PROVINCES = 15
    b.CITIES_PER_PLAYER = 5
    b.CITY_SPACING_KM = 180.0
    b.RELIEF_WIDTH = 4096
    b.MASK_WIDTH = 2048
    b.ID_PREFIX = "w"
    b.VIEW = {"longitude": 10.0, "latitude": 28.0, "distance": 300.0, "max_distance": 380.0}
    b.MERGED = {**b.MERGED, "SOL": "SOM", "KAB": "KAZ", "CYN": "CYP", "CNM": "CYP", "ESB": "CYP", "WSB": "CYP",
                "BRT": "IND", "KAS": "IND", "PGA": "CHN", "SPI": "CHN", "SCR": "CHN", "USG": "CUB",
                "BJN": "COL", "SER": "COL", "CLP": "FRA", "ATC": "AUS", "IOA": "AUS", "CSI": "AUS"}
    b.main()


if __name__ == "__main__":
    main()
