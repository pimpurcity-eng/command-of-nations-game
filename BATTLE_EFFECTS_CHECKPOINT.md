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


## 2026-10-09 — Distinct illustrated Russian air-defense portraits
Owner rejected blue rendered thumbnails and specifically requested drawings, pointing out that previous levels reused the same images. Built-in image-generation tool produced five distinct illustrated assets: strela10, torm2, bukm3, s400, s500. Olive woodland camouflage, three-quarter view, field/treeline background, no insignia or text. These are illustrative UI art, not claims of technically exact model geometry.
CowUI.research_picture selects the named vehicle for each research level; same-vehicle guidance/radar improvements intentionally retain that vehicle's portrait. Research cards, active slots and selected details use the level-specific image; Russian category/production family preview uses the branch baseline illustration. Rounded menu from 0af38e6 retained. No gameplay changes, no model files added, no publication.
Assets: game/assets/interface/illustrations/*.png. Native phone screenshot: docs/review/research/Illustrated_Air_Defense_Tree.png. Model archive integration/animations/range circles remain a separate queued task while owner asked to finish menu first.


## 2026-10-09 — Full-card research artwork
Owner requested the unit fill the whole square. Research portraits now fill the rounded card with only a 3px selection-border inset; names sit over a dark bottom overlay. Air-defense cells are taller (208px) to preserve complete launchers rather than crop tall S-400/S-500 tubes. Tree scrolls vertically to later tiers. Updated native renderer captures initial and later-tier views separately. No gameplay/data changes. Based on abc48d7.

Owner then requested spaced unlocks with S-500 on Day 18. Per-family research_days now short 1/3/6/9/12, long 1/4/8/12/18 (both countries' air-defense branches). ResearchSystem.unlock_day drives actual start gating; non-air-defense families retain original day gates. Sidebar shows levels and individual cards show their actual unlock day, avoiding ambiguous shared day rows. Air-defense tests now 46/0, including rejection on Day 17 and successful S-500 research start on Day 18.


## 2026-10-09 — Original Russian and European air defense (ChatGPT)
Integrated owner's weapons.airdefense.zip (Drive 1GZy0URrrecdz8yUeXAj_S6B2uO7SCkya): exactly five Russian and five European models; Igla/Osa/Pantsir/S-300/duplicate S-500 excluded. Original camouflage kept. Models are private under assets/library/airdefense and never committed. tools/install_air_defense.py verifies SHA-256 and installs the ten GLBs from the original archive. Model paths selected by researched level; modernization updates the visual and saves restore the correct model.
AirDefenseAnimator controls named launcher elevation, radar sweep, turret aiming and moving wheels. CombatEffects starts interceptors at the model's launcher and triggers firing animation. Range circle matches actual AA reach and follows the selected unit (city or province). Ground movement/placement follows existing navigation; aircraft-only interception rules retained. Russian research drawings stay; European provided preview images and real names replace obsolete stand-ins.
Initial checks: original-model integration 104/0, research 46/0, campaign 216/0, effects 27/0, touch 13/0, buildings 37/0; native preview clean. Campaign fixture now explicitly sets assaulting tank moving to test direct attack rather than nearby artillery. Native deployment/interceptor recordings saved separately for both lineups.
Fetched latest shared branch 51c8e918864ae20ab09d8f6bd3f092fa3423099a; it has flat terrain, road/centre placement and archived live weapons. Merge that work before handoff; do not restore obsolete weapons to the live arsenal. This checkpoint will be updated after integration validation. No live publication.


## Claude upstream checkpoint (51c8e91)
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

### Claude — 2026-10-09 (owner's weapons.zip: Russian air defence)
- Matthew's `weapons.zip` (Drive): low-poly GLBs built by a script (`build_s500.py`, `vehicles.py`; scripts were read, not run). Models copied to `assets/library/ad_*.glb` (gitignored, like all models; pristine zip kept in `assets/library/source_weapons_zip/`). In game: **Strela-10, Tor-M2, Buk-M3, S-400, S-500 Prometey** (`equipment.json` ids `strela10`, `tor_m2`, `buk_m3`, `s400`, `s500`; roster entries in `asset_roster.json`). The zip's `ad_s500_radar.glb` and `ad_s500_launcher_4tube.glb` are in the library but not yet used — awaiting Matthew.
- Models are +X forward; `UnitVisual.YAW_FIX["ad"] = 180` so cabs/fronts face the direction of travel (checked against the T-90 gun).
- **Matthew: "keep the original colors from now on."** Roster appearances can set `"original_colors": true`; `UnitVisual.create` then skips the blue/woodland repaint. Set for all five new systems. Existing units unchanged.
- Scenario: Kursk's Skyguard-derived battery is now an S-400; new starting batteries: Moscow S-500, Belgorod Tor-M2, Voronezh Buk-M3, Rostov-on-Don Strela-10 (Russia `starting_force_count` 14). **ChatGPT:** `tests/test_campaign.gd` no longer hard-codes 20 armies; it counts the scenario's units (`_scenario_armies()`).
- Ranges/damage scale Strela-10 1.8/6 → S-500 5.5/14 (balance welcome). All suites pass. Screenshot `docs/review/new_air_defence.png`. Android test build 0.6.

### Claude — 2026-10-09 (Matthew: "units should be only on tracks except air")
- Ground armies now stand on roads, not only travel on them: `LandRoutes.on_road()` (nearest free road point, spacing 0.7 from other armies, on the army's own side of the border via `controller_at`) is used when spawning (start + production) and `beside_on_road()` when splitting (`ArmyStacks.split_selected` / `split_units`). Aircraft and ships unchanged. `UnitSystem.ground_positions()` helper.
- Armies standing on a road through a city were hidden behind the city tap: `main._map_click` now gives an army under the tap priority over the city (city opens from its name tag or elsewhere).
- Tests: `test_map_features.gd` 22/0 (start on roads, own side of border, no stacking); campaign, battle effects, touch 0 failures. Android test build 0.7.

### Claude — 2026-10-09 (Matthew: "take all weapons out of game, have all new ones coming"; "troops start in city or province center")
- **Arsenal archived, not deleted:** `data/archive/weapons_2026-10-09/` holds the previous `equipment.json`, `weapon_showcase.json`, `scenario_regional.json` (with its 24 starting armies) and a copy of `asset_roster.json`. Live `equipment.json` and `weapon_showcase.json` are `[]`; live scenario `units` is `[]` (countries/capitals unchanged). The live roster stays (city buildings use it). Models in `assets/library/` untouched.
- Empty-arsenal fixes: `main._ready` no longer assumes unit #10 exists; `WeaponShowcase` shows "No weapons yet"; `MatchSystem` only eliminates a side after it has fielded armies (`fielded`). `ProductionSystem.catalog` now shares `EquipmentIdentity.catalog`; `GameSession.scenario_path` and `WeaponShowcase.source` are overridable.
- **Tests (ChatGPT):** all suites call `ArsenalFixture.use_archive()` (`tests/arsenal_fixture.gd`) so they keep exercising armies with the archived arsenal. `test_campaign.gd` move check now targets the nearest neighbouring province centre (orders go to centres by road). Review renders: `ARSENAL=archive` env var.
- **Start positions:** ground troops ignore scenario offsets and start at their city/province centre (`LandRoutes.hub_for`), others of the same place line up on the roads beside it; aircraft/ships keep offsets. New check in `test_map_features.gd`.
- When the new weapons arrive: add them to `data/equipment.json`, `data/asset_roster.json` (with `"original_colors": true`), and starting armies to the scenario.
- All four suites pass. Android test build 0.8 (no weapons).

### Claude — 2026-10-09 (Matthew: flat map with the appearance of terrain)
- The map is now totally flat (`TerrainProfile.height()` = `FLAT_HEIGHT` 0.2), Call of War style, so units, roads, cities and flags sit exactly on the ground. The former height function is `TerrainProfile.relief_height()` and only paints: `StrategicMap._subdivide` puts its slope in the vertex normal (rock on slopes) and its altitude in the vertex colour red channel (`terrain.gdshader`: `altitude = COLOR.r * 4.0`, snow caps); the relief texture shading is unchanged.
- All four suites pass. Screenshot `docs/review/flat_map.png`.
- Note: ChatGPT's `Command_of_Nations_Buildings_Handoff.zip` and `Command_of_Nations_Menu_Polish.zip` are in Matthew's Drive but not on this branch; not integrated (awaiting Matthew). The menu polish may overlap Claude's city/research/HUD skin work (`cow_ui.gd`, `city_panel.gd`, `research_panel.gd`, `hud.gd`).


## 2026-10-09 — Seven o’clock owner test map

Merged Claude upstream 51c8e918864ae20ab09d8f6bd3f092fa3423099a into the existing shared branch. Kept the flat map, road/province placement rules and archived obsolete weapons. The live equipment data contains only the four new AA research families representing ten supplied models. Original model colors are preserved. No model binaries are committed.

Added scenes/air_defense_test_map.tscn for owner testing in installed Godot. Ten models form two columns (Russian left, European right), face screen seven o’clock initially, show real range on selection, and can be controlled by selecting their column. AI off, initially paused. Normal movement/combat still changes heading. Test equipment bypasses day availability only by preplacement; normal S-500 research remains Day 18.

After merge: original-model/animation/interception tests 104/0; AA research 46/0; archived campaign 212/0; touch 13/0; battle effects 27/0; building expansion 37/0. Native Godot rendered all ten, checked each forward direction down-left. Updated legacy tests to use the archived arsenal rather than restoring it into the live game.

See docs/AIR_DEFENSE_TEST_MAP.md and docs/review/air_defense/Air_Defense_Seven_Oclock_Test.png. Private owner ZIP includes model assets for local testing, not public Git distribution. Nothing deployed or pushed from this workspace.


## 2026-10-09 — Owner-requested Android app test

Built Command_of_Nations_Air_Defense_Test.apk from bd3a4c3 review source with the private supplied AA and shared warehouse models. The isolated package sets its default scene to air_defense_test_map and uses its own test user-data directory. Android package com.commandofnations.test, versionCode 9, versionName 0.9-air-defense, ARM64, portrait, Compatibility renderer. The source project default campaign scene and existing Android preset are unchanged.

Verified APK ZIP integrity, all ten imported AA models and their imported scenes, review scene script, ARM64 runtime and portrait manifest. apksigner verifies v2 and v3 signatures. Reimported the compact owner project and ran the ten-model facing/control check successfully. APK has not been run on an actual Android device. Existing app signing key was not available in workspace or connected Drive, so this APK uses a newly generated private debug signing key; installation over an older same-package app is not guaranteed. Do not tell the owner to uninstall their app or delete saves as a routine step.

Verified owner Drive APK: https://drive.google.com/file/d/16FdQBk8yYmj3Wn469mnm4Wgk1ZRXT6VJ/view?usp=drivesdk (55,662,578 bytes)
SHA256: 71b06e9daa1a38ce9997ebcbc10df8ef6cb6745e8db180eab088ffa907f8513d
Owner Godot test ZIP: https://drive.google.com/file/d/1m9euv0xHVAPZzE7kCdQ4oOhpSTOckn2Z/view?usp=drivesdk (35,909,021 bytes)
No public Git model files, no deployment or remote push.


## 2026-10-09 — Owner shadow review and road connectivity audit

Replaced broad dark unit shadows with softer contact shadows sized to each fitted model's horizontal bounds, including city shrink. Reduced contact opacity from 0.70 to 0.38, removed the opaque core and large viewer offset. Source +X / game -Z model facing is unchanged. All ten AA fronts still pass the native seven-o'clock review check. Battle-effects suite 27/0; native render had no errors. Preview: docs/review/air_defense/Soft_Contact_Shadows.png. These source changes are not installed on the owner's phone or in the previously provided version9 APK.

Read-only road connectivity audit: 72 province hubs belong to one connected land-road component, all city points are road endpoints, and Kaliningrad region is the only isolated province hub. tests/check_road_connectivity.gd logs component sizes, isolated provinces and city misses. No map/road edits.


## 2026-10-09 — Thin road/path lines, owner request

Reduced visible highway half-width 0.025→0.010 and local province-road half-width 0.022→0.009 (about 60% thinner). Only the rendered ribbons change; graph, centre points and travel routes are unchanged. Owner explicitly requested map line adjustment after sharing a Call of War reference. Native portrait review rendered with no errors and the ten-model heading check passed. Preview docs/review/air_defense/Thin_Road_Lines.png. This is a source preview, not installed on the phone.
