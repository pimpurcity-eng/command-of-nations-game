# Command of Nations — shared battle-effects checkpoint

## Canonical handoff

Intended branch: `chatgpt/battle-effects` in `pimpurcity-eng/command-of-nations-game`.
The GitHub integration rejected the write with HTTP 403 (Resource not accessible by integration); **no branch or commit was created**. This checkpoint is supplied in `Command_of_Nations_Battle_Effects_Claude_Handoff.zip` for Claude to commit on that branch.
Base: Claude's `claude/godot-strategy-game-io20at`, commit `49c40be42eaf4b4c64ae26a91fd076b81910ae75`.
This source adds the battle effects directly to Claude's source. His terrain, repaired province geometry, cities, camera, portrait HUD, movement paths, camouflage, and model fitting are retained.

Use this source as the integration base, then commit it on the intended branch. Do not overwrite entire scripts from the older recovered zip. Make subsequent changes as small commits, record the source commit and checks here, and exchange screenshots before publishing. Neither main nor a deployed build was changed by this handoff.

## Changed files relative to Claude's base

- `game/scripts/combat_effects.gd`: visible missile and shell flight, brief muzzle flashes, model recoil, soft smoke trails, original-model wrecks, damaged-unit smoke, effect limits and cleanup, visibility checks.
- `game/scripts/combat_system.gd`: emit effects for damaging gunfire and defensive fire as well as ranged attacks; simulation damage and reload rules remain unchanged.
- `game/scripts/unit_visual.gd`: enable mesh shadows, add firing-heading helper, remove only the `upload20ab` 180-degree yaw correction. Claude's per-role footprint, fitting, camouflage and other model corrections remain.
- `game/scripts/unit_system.gd`: create and update each unit's ground shadow; keep model at child index zero.
- `game/scripts/unit_shadow.gd` and `game/assets/unit_shadow.gdshader`: soft ground shadows, including elevated aircraft.
- `game/tests/test_battle_effects.gd`: effects, launcher heading, model fit, shadows, recoil, expiration, fog visibility and bounds checks.
- `game/tests/render_battle_effects.gd`: controlled native flight preview; writes to `BATTLE_PREVIEW_DIR` or `user://battle-preview`.
- This checkpoint.

No battle-effects edits to `main.gd`, `hud.gd`, `strategy_camera.gd`, `strategic_map.gd`, `city_system.gd` or `project.godot`.

## Facing and visuals

The owner's latest instruction is: **the front/cab of the truck faces the enemy**.
The 20AB recovered truck's cab is toward model-local -Z. Its ModelFit keeps that direction, without the extra 180-degree `upload20ab` correction. Unit headings use `atan2(-direction.x, -direction.z)`; movement and firing both use -Z as forward.
Missile firing rotates the whole visible unit assembly toward its target and updates its heading. The launcher mesh is baked together; no independent rack/turret animation is claimed. Gun recoil briefly offsets the visible model and restores it; simulation/world position does not move.
Other model yaw corrections and the zero base yaw remain as Claude supplied them. Their individual visual facing still needs the owner's lineup review.
The owner rejected added persistent fake flames and chunky smoke dots: those were removed. Original brief impact flashes remain; flight smoke uses soft transparent billboards. Models are original recovered geometry.

## Engine and assets

Tested with Godot **4.6.3**, Compatibility renderer. Keep Claude's existing `project.godot`: feature tag `4.6`, GL Compatibility, 720x1440 portrait viewport, handheld orientation 1. No new engine settings are required. `project.binary` is absent from the package; do not restore it.
No files from `assets/library/` or `assets/vehicles/` are committed. Obtain those folders privately from `Command_of_Nations_Recovered_Source.zip`; public licences remain unchecked. The package requires those assets locally for model and missile previews.

## Validation on merged source

- `godot --headless --path game --script res://tests/test_battle_effects.gd`: **27 checks, 0 failures**.
- `godot --headless --path game --script res://tests/test_campaign.gd`: **192 checks, 0 failures**.
- `godot --headless --path game --script res://tests/test_touch_controls.gd`: **13 checks, 0 failures**.
- Native Compatibility flight preview inspected: fitted truck cab faces the target and missile flight is visible. The native renderer logs `Parameter "material" is null` warnings/errors; headless checks do not reproduce these. Investigate this before calling the combined visuals release-ready. Test counts do not certify visuals or every model's front direction.

## Coordination

ChatGPT owns this effects handoff and its facing/shadow integration. Claude should review this commit, preserve the effects while adding subsequent changes, investigate native material logging, rerun all three checks, and send the owner screenshots of moving units, firing launcher cab direction, missile flight, impact, helicopter visibility and shadows before publishing. Keep one integration base, with exact commit references and a changed-file list for each handoff. Resolve conflicting edits to a shared script explicitly rather than replacing the file wholesale.

## Handoff log

### Claude — 2026-10-09
- `aca8542` — ChatGPT's handoff committed on `chatgpt/battle-effects` (base `49c40be`), reviewed: only files with real changes imported (others differed by a trailing blank line / regenerated uids; data JSON identical in content).
- `3ae0c31` — Fix `Parameter "material" is null`: per-unit camouflage materials were freed with replaced/destroyed models while the GL renderer still referenced them; camouflage materials are now shared per (source material, pattern scale). Preview errors 16 → 0.
- Checks with Godot 4.6.3 on `3ae0c31`: battle effects 27/0, campaign 192/0, touch 13/0 (checks/failures); `render_battle_effects.gd` 0 null-material errors.
- Visual review (screenshots sent to Matthew): Moscow and Kyiv skyscraper downtowns present; a Russian IFV ordered into Belgorod arrives at the city point (distance 0.0) and stays visible among the buildings; launcher cab faces its target; missile flight, impact flash/ring and smoke visible.
- Open: with base yaw 0 (commit `f466b89`, the owner's 180° request) the T-90 in the battle preview points its gun **away** from the unit it is set to face — tanks face backwards. Awaiting Matthew's keep/undo decision. Garrisoned units are larger than city blocks (unit footprint 1.35). Impact smoke reads as a hard-edged polygon dome.
- Matthew's decision ("undo, smaller"): base yaw restored to PI so guns face the direction of travel/target; `upload20ab` 180° fix restored so the truck cab still faces its target (verified in the battle preview: T-90 aims at the launcher, launcher cab faces the T-90). Armies within 0.8 of a city centre scale to 55% so they sit among the buildings. Checks: effects 27/0, campaign 192/0, touch 13/0, preview 0 null-material errors.
- Android test build for Matthew (not published): `game/export_presets.cfg` gained an "Android" preset (arm64, debug-signed, package `com.commandofnations.test`) and `project.godot` enables ETC2/ASTC texture import for phones. The APK is built locally into `build/` (gitignored; it contains the models, which stay out of the repo). Export: `godot --headless --export-debug Android ../build/command-of-nations-test.apk` with Godot 4.6.3 Android templates and an Android SDK set in editor settings. Checks after the reimport: campaign 192/0, touch 13/0.

### Claude — 2026-10-09 (Matthew's phone test, round 1)
Matthew installed the APK. Feedback: weapons look white; roads to every province; units with orders never move; some cities look bad; tanks sink into the map; resources in cities and scattered across provinces; builds → ChatGPT.
- **Movement:** `SimulationClock.MOVEMENT_PACE = 10` multiplies ground (`ArmyStacks.movement_speed`) and air (`AirOperations.flight_speed`) speed; the economy clock (`REAL_SECONDS_PER_SIM_SECOND = 120`: production, research, combat rounds) is unchanged. A tank now covers ~3 map units in 30 real seconds (was ~0.3).
- **Ground height:** `StrategicMap.elevation()` now returns the height of the *drawn* province triangles (grid-bucketed, `_ground_cells`) once the ground is built; the smooth formula only seeds the mesh. Roads, units, buildings and labels all sat on the formula, which differed from the coarse mesh by up to ~0.3 (buried roads, sunk tanks). Vehicles rest on the highest point of their footprint (`UnitSystem.footprint_ground`).
- **Kharkiv:** the hard "hills" landform box edge along 50°N made a cliff through the city (the dark grey band). `TerrainProfile` hill zones now have 0.6° soft edges (`hill_weight`) and the ground is levelled within ~1 unit of every city.
- **Colour:** Russian camo regenerated darker (steel blue / navy, `tools/make_camo.py`); Ukrainian ground equipment gets an original olive/brown/black woodland pattern (`tools/make_camo_ukraine.py`, `UnitVisual.paint_camo`). Paint only; model geometry untouched.
- **Roads:** `StrategicMap.road_network()` joins neighbouring provinces centre to centre (shared-border detection, relative-neighbourhood pruning, enclaves joined to the nearest province), under the existing highways.
- **Resources:** `data/resource_sites.json` + `scripts/resource_sites.gd`: 45 sites (oil/gas fields → fuel, mines/steelworks/timber → materials, plants → electronics, farmland → manpower) with original 3D installations and resource badges; income goes to the province's controller (`ProductionSystem.advance`). Cities list specialties (+50% on those resources), shown as badges on the city name tag. Icons: `tools/make_resource_icons.py`.
- Tests: new `tests/test_map_features.gd` 13/0; campaign 0 failures, battle effects 0 failures, touch 0 failures. Review aid `tests/render_view.gd`. Screenshot: `docs/review/phone_round1.png`.
- Builds (city construction) are ChatGPT's next job per Matthew.

### Claude — 2026-10-09 (Matthew's phone test, round 2)
Feedback: research separate from cities; menus (building) too complicated — make them like Call of War (reference screenshots); tanks look like they float; units travel only on roads; every province has a centre that can be taken; take the extra roads out of cities.
- **Roads only:** `LandRoutes` now routes over `StrategicMap.roads` (highways + province roads) following the drawn road curves; an order goes to the tapped province's centre (`StrategicMap.province_hubs`); an army part-way along a road continues along it. `UnitSystem.order` sets the target to the route's end.
- **Province centres:** a flag post at every province centre without a city (`_add_province_posts`), showing the controller's flag; updated on capture. Capture rule unchanged (`MatchSystem`, CAPTURE_RADIUS around the centre).
- **Floating:** vehicles sit at the ground height of their centre and tilt with the slope (`UnitSystem.ground_normal`); sun shadows tightened (2 splits, 45 range, small bias); ChatGPT's contact shadow sits directly under ground vehicles and is placed in map space (`UnitShadow.update`, still 0.04 above ground — battle-effects test unchanged).
- **Research:** national, `ResearchSystem.rate()` = 1.0 regardless of cities/capital; the research center is hidden from the city menu (data entry kept in `buildings.json` — ChatGPT: decide whether to delete it when reworking builds). Research opens only from the Research tab.
- **Menus (CoW style):** shared `scripts/cow_ui.gd`. `CityPanel` rewritten: header, income badges, construction/production status boxes, tabs (Buildings / Produce / Rally point), sectioned building rows with cost icons, time and CONSTRUCT. `ResearchPanel` rewritten: two slots, category banners, per-category tech tree (columns = families, rows = levels by unlock day), bottom bar with cost and RESEARCH, Modernize selected army. Public API kept (`setup`, `open`, signals, `summary`).
- **Previews:** `tests/render_previews.gd` renders each unit's model (with camo) to `assets/library/previews/` (gitignored like the models); `UnitVisual.preview_texture` prefers them.
- **Cities:** avenue asphalt strips removed (gaps kept as streets); map roads stop at the city edge (`CITY_EDGE`).
- **ChatGPT, builds:** the city screen's building rows come from `buildings.json`; adding buildings there adds rows (sections in `CityPanel.SECTIONS`; unknown ids go under "Special").
- Tests: `test_map_features.gd` 18/0, campaign 0 failures, battle effects 0 failures, touch 0 failures. Screenshot `docs/review/phone_round2.png`.
