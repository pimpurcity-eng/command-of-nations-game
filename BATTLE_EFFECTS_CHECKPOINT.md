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

### Claude — 2026-10-09 (Matthew's phone test, round 3)
Feedback: resources like Call of War — one per province/city; planes fly anywhere in range (not on roads); paint all the buildings; menu layout good but looks like "Atari graphics".
- **Resources:** `ResourceSites` now places exactly one resource per province, beside its centre (`_beside`, away from roads): city provinces use the city's single resource (`resource_sites.json` "cities"), others the majority of the real producing sites inside them ("sites" are now geographic hints), else land type ("by_landform"; forest south of 56°N counts as farmland). 73 provinces: 27 materials, 25 manpower, 13 fuel, 8 electronics.
- **Planes:** confirmed already straight-line within range (`AirOperations.order`, waypoints = [destination]); roads-only applies to ground armies only. No change.
- **Buildings painted:** coloured Soviet-era blocks, houses and roof tiles (weathered 10%); infrastructure models (warehouse/factory GLBs) get shared painted materials (`CitySystem._paint_infrastructure`).
- **Menu skin:** `tools/make_ui_skin.py` → `assets/interface/skin/*.png` (bevelled buttons, brushed panels, inset wells, parchment rows, tabs, research banners) and shaded `res_*.png` icons; fonts Oswald + Roboto Condensed (OFL, `assets/fonts/`), set in `StrategyTheme`. `CowUI.skin()` used by city/research screens and HUD bars/buttons. `ResourceSites.icon()` returns in-memory copies (the imported money icon drew as a white square in the HUD on GL Compatibility).
- Tests: `test_map_features.gd` 19/0 (one resource per province, at its centre); campaign, battle effects, touch 0 failures. Screenshot `docs/review/phone_round3.png`.

### Claude — 2026-10-09 (Matthew: "units are not sitting right")
- The terrain shader is unshaded (receives no sun shadows), so vehicles had no ground contact cue and looked like they hovered. `UnitShadow.update`: contact shadow under the hull, wider (1.25x, follows the model's city shrink), darker (0.7), spread slightly toward the viewer; `unit_shadow.gdshader` firmer core. Shadow height still ground + 0.04 (battle-effects test unchanged). All four suites pass. Android test build 0.5.

## ChatGPT building expansion — 2026-10-09

Base: shared branch `chatgpt/battle-effects`, commit `577393ce8edbb475b6767fb307f16e1a99858a03` (includes Claude's latest city/research UI and province resource sites).

Scope: building data, effects, and recolored asset scene wrappers only. City/research screens, map/roads/terrain, city placement, units, camouflage and Android files have no edits in this handoff. The earlier interface draft is excluded to honor the ownership agreement.

- Four original buildings retained. Ten additions: financial office, materials works, electronics factory, fuel depot, recruitment centre, barracks, tank plant, naval base, bunkers and infrastructure. All support three levels, queues, cancellation and saves. New buildings start at level 0.
- Five resource facilities: +25% matching city resource output per level, layered over existing industry/specialty bonuses. Province resource-site output is unchanged.
- Barracks: +25% mechanized/infantry production speed per level; tank plant: armor; naval base: ships. These are optional specialist bonuses, preserving existing equipment unlocks and initial available units. Naval bases are restricted to Odesa and Rostov-on-Don, including save validation.
- Infrastructure: +15% construction speed per level. Bunkers: -20% incoming damage per level (max -60%) for friendly ground units within 0.6 of a city their country controls. Applied to simultaneous ground/air battle damage through MatchSystem; does not protect aircraft, drones or ships.
- Old four-building saves migrate to unbuilt new facilities. Validation still rejects malformed original building data.
- Four recovered warehouse models reused through `game/scenes/facilities/*.tscn`; `facility_paint.gd` applies role colors using shared cached materials. No model files or geometry modifications. Catalog `colour` metadata is also available for list previews. Existing thumbnail images are unchanged.
- Exact costs, levels, color names and effects: `docs/BUILDING_CATALOG.md`.

Validation: Godot 4.6.3 Compatibility — building expansion **37/0**, campaign **192/0**, touch **13/0**, battle effects **27/0**. Native city/list previews inspected, **0 render errors**, including no null-material errors. Screenshots are review previews, not a published game build; map preview temporarily sets all eligible buildings to level 1 for visibility.

Claude UI follow-through (not edited here): group new buildings into economy/production/defense/infrastructure; use `definition.description` for new effect text and `definition.colour` for preview tint; city income display should multiply `buildings.resource_rate(city_id, resource)`; production ETA should use `buildings.production_rate(city_id, spec)`; construction ETA should use `buildings.construction_time(city_id, building_id, target, progress)` rather than raw duration. The current screens show base durations/income until these helpers are connected. Keep live publishing paused until Matthew reviews the screenshots.

## Menu polish — 2026-10-09, Matthew requested

This follows local building commit de1ea9c9b6194e065a4f41588d309f5a9fd9526e, based on shared 577393ce8edbb475b6767fb307f16e1a99858a03. Matthew explicitly requested menu improvements after the ownership agreement. Changes are focused on shared style helpers, icon assets, original-model thumbnail selection, and production-list sizing; city/research layout and signals are retained.

- Clean slate headers, light neutral rows, muted green actions, subtle outlines and rounded corners replace the embossed texture skin. Roboto Condensed is used consistently with lighter body text and restrained title weight.
- High-resolution SVG resources and outline command icons replace chunky silhouettes and circular resource badges. Country flags retain national colours.
- Close control fits its button; production lists use larger previews and show more equipment. Research and production use original same-role model previews when a specific unit has no recovered thumbnail, rather than presenting a flag as its equipment image.
- Files: cow_ui.gd, strategy_theme.gd, hud.gd, resource_sites.gd, mobile_start_panel.gd, production_panel.gd, research_panel.gd, SVG icons and render_menu_style.gd. No battle, movement, economy or building-rule changes in this commit.
- Validation: campaign 192/0, touch 13/0, buildings 37/0; native portrait city/production/research screenshots inspected with zero render errors. Review screenshots in docs/review/menus. Not published live.
- Claude: import the menu commit after the building commit, review these narrow shared-style/thumbnail changes against any newer UI work, and keep Matthew's screenshot review before publishing. The new rate helpers from the building checkpoint still need the city-screen income/ETA connections.


## 2026-10-09 — Air-defense research paths (ChatGPT)
User resumed work specifically to add Russian short/long-range air-defense research using supplied lineup. Based on local b475388 (menu handoff), itself on remote 577393c. Keep previous building/menu handoffs when importing.
- Existing equipment IDs skyguard_russia / patriot_russia preserved for saves and production. Two independent five-level branches; national two-slot research, sequential prerequisites and existing Day 1/1/2/4/6 gates preserved.
- Short: Strela-10 → guidance → Tor-M2 → radar → interception. Long: Buk-M3 → radar → S-400 → guidance → S-500. Ukrainian existing families also receive branch labels and corresponding upgrades, without Russian names.
- Reused Skyguard/Patriot meshes and thumbnails are explicitly labelled stand-ins in selected research details. No new 3D models, no assertion that these are authentic Russian meshes. No model files in commit.
- EquipmentIdentity.research_tier/title and air_defense_range provide per-level gameplay values. AirBattleSystem uses tier damage without applying generic level bonus a second time, plus per-level interception range. Existing aircraft/drone target rules unchanged; cruise/ballistic/hypersonic/satellite interception NOT implemented or advertised.
- Values are game balance units, not real-world km: short range 2.4/2.5/2.7/2.8/3.0, damage 7/8/9/10/11; long range 3.5/3.8/4.2/4.5/5.0, damage 10/11.5/13/14.5/16.
- UI: wider two-column cards with branch headers, per-level names, connectors, selected tier improvement/range/damage/model disclosure; muted completed/active/available/locked colors. Call of War official research wiki used for categories/columns/day gates/slots/details structure, not copied art or stats.
- Files changed: equipment.json, equipment_identity.gd, air_battle_system.gd, research_panel.gd; two test/render scripts; review image. No map, movement, city, Android changes.
- Checks: air-defense 42/0, campaign 192/0; native phone screenshot and touch check recorded with handoff. Review before publication. No live release or GitHub push claimed.


## 2026-10-09 — Rounded menus and equipment pictures (ChatGPT)
Owner requested better pictures, less square menus, then explicitly requested backgrounds in pictures. Based on dce247e.
- Re-rendered every existing equipment family's recovered model at 640x400, with three-quarter camera, floor background and contact shadows. Shared CowUI.equipment_picture prefers these portraits; stand-in identity disclosures from prior handoff remain. No new model identity or geometry claimed.
- Rounded shared panel/button skin corners to 16px. Research board uses 22px corners, softer two-column cards, rounded portrait masks, integrated names, thin connectors and no square grid border lines.
- Portraits stored as UI PNGs; model source folders remain excluded. Reproducible render_equipment_portraits.gd uses original UnitVisual.create, preserves owner's current camouflage and facing.
- Cosmetic only: research costs, prerequisites, range and combat rules unchanged. Phone native render clean; touch 13/0. Screenshot docs/review/research/Rounded_Air_Defense_Tree.png. No live publication or GitHub push.
