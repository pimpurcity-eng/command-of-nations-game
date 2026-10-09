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
