# Europe (20 players) and World (100 players) maps — Claude

Not wired into the 0.23 app (ChatGPT kept them out of 0.23 on purpose). Copied here so nothing is lost.
Origin: branch `chatgpt/battle-effects` (Claude's line). To use them, copy `game/*` into the game
folder (note: `geographic_projection.gd` here has the LAEA / Equal Earth projections the maps need —
compare with the game's copy before replacing), add the scenes to the start menu, and run
`tests/test_europe_map.gd` and `tests/test_world_map.gd`. Builders: `tools/build_europe_map.py`,
`tools/build_world_map.py` (Natural Earth data, Shapely).
- Europe: 20 playable countries, 5 cities each, AI for the rest.
- World: 100 playable countries, 15 provinces each.
