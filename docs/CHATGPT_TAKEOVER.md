# ChatGPT takeover — Command of Nations (2026-10-09)

Claude is pausing (owner's weekly credit). ChatGPT continues alone. Everything needed is
here; nothing depends on Claude's workspace.

## Source of truth
- Public repo `pimpurcity-eng/command-of-nations-game`, branch **`chatgpt/battle-effects`**,
  head **`cef0781`** (or later). Clone it directly; no bundles needed.
- Never merge into `main`, never publish, never delete original files, never overwrite
  another developer's work. Small commits, exact hashes, update `BATTLE_EFFECTS_CHECKPOINT.md`
  (root and `game/` copies are identical) at every handoff. Screenshots before publishing.
- Model files are private and gitignored. Never commit `.glb`, APKs, keys or `accounts.cfg`.

## Install the owner's private models (from Matthew's Drive)
- Air defence: `python3 tools/install_air_defense.py weapons.airdefense.zip`
  → `game/assets/library/airdefense/` (10 models, hashes in `docs/AIR_DEFENSE_ASSETS.json`).
- Tanks, APCs, aircraft: `python3 tools/install_arsenal.py tanks_only.zip apcs_only.zip weapons.zip`
  (Drive folder "Weapons") → `game/assets/library/arsenal/` (29 models,
  `docs/ARSENAL_ASSETS.json`).
- Then `godot --headless --import` once.

## What is in the game now
- Flat map with painted relief (`TerrainProfile.height()` is constant; `relief_height()` paints).
- Ground armies stand and travel only on roads, from province centre to centre; aircraft fly
  freely within range. Troops start at their city/province centre.
- Live arsenal (`game/data/equipment.json`): ChatGPT's 4 air-defence families + Claude's 7
  families (`tanks_*`, `apcs_*`, `bombers_*`, `strike_ukraine`), 5 research tiers each, each
  tier names its model; owner models keep original colours (`UnitVisual.owner_model`), +X
  forward, arsenal models merged per material at load (`UnitVisual.merged`).
- Starting armies (`data/scenario_regional.json`): every city has air defence, a tank group and
  an APC group; bombers at Moscow and Kyiv, strike fighters at Kyiv.
- Unused models in the owner's zips: Igla, Osa-AKM, Pantsir-S1, S-300, deployed S-500.
- Old arsenal archived in `data/archive/weapons_2026-10-09/`; tests use it via
  `tests/arsenal_fixture.gd`.

## Tests (all pass at cef0781)
`test_air_defense_models` 104/0, `test_air_defense_tree` 46/0, `test_building_expansion`,
`test_player_accounts` 21/0, `test_campaign`, `test_battle_effects`, `test_touch_controls`,
`test_map_features` — 0 failures. Run with
`xvfb-run -a godot --path game --script tests/<name>.gd`.

## Android test app
- See `docs/ANDROID_TEST_BUILDS.md`. Latest: **0.11-test, versionCode 11**, package
  `com.commandofnations.test`, in Matthew's private repo `pimpurcity-eng/Command-of-nations-builds`
  (file `command-of-nations-test.apk`, must stay < 100 MB; the Android preset already
  excludes the archived models).
- Claude's signing key could not be shared. ChatGPT signs with its own key from now on. The
  first ChatGPT build will not install over Claude's 0.11: Matthew uninstalls the test app
  once, then installs ChatGPT's build; after that ChatGPT's updates install normally. Keep the
  same key for every later build and use versionCode 12 or higher.

## Owner's standing requests (keep)
Call of War look and feel; portrait Android; no labels on units; original model colours;
answer the owner's questions first; save (commit/push) after every job.
