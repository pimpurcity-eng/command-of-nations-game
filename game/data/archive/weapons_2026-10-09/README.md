# Archived arsenal (2026-10-09)

Matthew: "Take all weapons out of game, have all new ones coming."
The weapon catalogue, the weapon showcase list and the starting armies were moved here
(nothing deleted). The live files now hold no weapons:
- `data/equipment.json` = `[]`
- `data/weapon_showcase.json` = `[]`
- `data/scenario_regional.json` "units" = `[]` (countries, capitals and everything else unchanged)

`asset_roster.json` here is a copy for reference; the live roster is unchanged because city
buildings use its warehouse entries. The tests run against this archived arsenal through
`tests/arsenal_fixture.gd`. To restore, copy the files back.
