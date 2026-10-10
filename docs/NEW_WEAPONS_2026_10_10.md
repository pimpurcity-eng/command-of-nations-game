# Original artillery, helicopters and rocket artillery

Install privately, from the owner's Drive Weapons folder:

```sh
python3 tools/install_new_weapons.py artillery_only.zip helicopters_only.zip rockets_only.zip
godot --headless --path game --import
```

The installer verifies all 30 GLBs and 30 previews against `NEW_WEAPONS_ASSETS.json`
before writing, and refuses to overwrite different existing originals. Assets stay in
the existing gitignored `game/assets/library/arsenal/`; no model binaries belong in patches.

The six families use the campaign's existing Russian/European equipment mapping:
European models equip Ukraine. Research levels unlock on Days 1, 4, 8, 12, 18.
The order is a game progression, not a historical capability ranking.

| Family | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
| --- | --- | --- | --- | --- | --- |
| Russian artillery | 2S1 Gvozdika | 2S3 Akatsiya | 2S5 Giatsint | 2S19 Msta-S | 2S35 Koalitsiya-SV |
| European artillery | FH70 | Polish 2S1 Gvozdika | CAESAR | PzH 2000 | Archer |
| Russian rockets | BM-21 Grad | BM-27 Uragan | BM-30 Smerch | Tornado-G | TOS-1A |
| European rockets | LAR-160 | RM-70 Vampire | M270 MLRS | PULS | EuroPULS |
| Russian helicopters | Mi-8 / Mi-17 | Mi-24 / Mi-35 | Ka-50 | Mi-28N | Ka-52 |
| European helicopters | Lynx | AW149 | NH90 | Tiger | NH90 Block 2 |

Helicopters reuse existing aircraft movement, attack, patrol, airbase and save mechanics.
They have a separate research category and a fitted helicopter footprint. Original main
and tail rotors spin only while flying; Ka-50/52 rotors counterrotate. Bodies and rotors
are merged separately per material without repainting or altering the original GLBs.
Troop transport is not implemented by this integration.

Artillery uses existing shell effects and production. Rockets use existing missile effects,
with provisional base damage 12, range 3.5 and reload of two combat rounds; other existing
missile families retain their previous defaults. Helicopters use range 10, speed 1.8,
air damage 2 and ground damage 5, with existing level scaling. Balance needs phone playtesting.

Six additional starting groups make the additions visible: artillery in Kursk/Lviv,
rockets in Voronezh/Odesa, and helicopters at Moscow/Kyiv airbases. Existing starting
groups remain; country force counts are recalculated from the complete live scenario.

Run all eight takeover suites and `test_new_weapons`. The latter loads every research-tier
model and verifies fitting, retained materials, merged mesh counts, real rotor motion,
live helicopter flight, configured rocket damage/range, and the national research menu.
`render_new_weapons.gd` produces separate native portrait review images.
