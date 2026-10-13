# Historical game — era unit roster (initial source checkpoint)

This is an isolated **historical unit pack** for a new game based on the Warfront Mandate geography.

- Original game remains unchanged. Nothing in this checkpoint changes an APK or live build.
- Baseline geography: 700 cities, 2,500 provinces; supported match design: 100/150/200 players.
- The data file `game/data/historical_units.json` contains 46 new historical unit archetypes spanning seven eras.
- The Godot helper `game/scripts/historical_unit_catalog.gd` loads the roster, finds an individual unit, resolves eras and filters unlocks by starting era and optional faction.
- A full-campaign match starts in the chosen earliest era and advances through all seven. Era matches start with the corresponding units unlocked.
- Modern equipment, models and military identity files in the Warfront game are deliberately untouched.
- `variant_factions` lists placeholder faction keys for English longbowmen and Mongol horse archers. Tie these to the final 200-faction roster when finalized.
- Stats and production costs are **first-pass placeholders**, not balanced gameplay values.
- Historical 3D assets, specific combat mechanics (melee, arrows, siege, cavalry, naval), research-gating integration, production interface, UI and save compatibility still need implementation/testing.
- This unit pack is **not yet a playable historical build**. A future isolated new-game entry point must bind this catalog to the existing Godot production/research/visual stack, while leaving Warfront Mandate unchanged.
