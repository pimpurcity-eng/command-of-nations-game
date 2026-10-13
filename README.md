# command-of-nations-game

Warfront Mandate (formerly Command of Nations) — Godot 4.6 strategy game for Android.

## Anti-cheat

Every match runs an automatic anti-cheat sweep once all players have joined and the map is loaded, then keeps watching during play (speed hacks, memory-edited resources, units from nowhere, edited saves). Flagged matches become unranked — no medals or ranks are synced.

- Code: `game/scripts/anti_cheat.gd`
- Full write-up: [docs/ANTI_CHEAT.md](docs/ANTI_CHEAT.md)
- Hook into main.gd: `git apply docs/anti_cheat_main_hookup.patch`
- Tests: `game/tests/test_anti_cheat.gd`
