# Flagship Russia–Ukraine tutorial repair — 17 October 2026

Matthew asked to retain Claude's version and make it work. This review branch starts at
`585e6356b238804d6d65739ca473b85945d1369a` (`claude/v0.61`), immediately after the
`24a802e` source identified by the builds repository's `web/VERSION` as `0.60-complete`.
The installed Play bundle itself was not retrieved or inspected.

## Agreed teaching flow

1. Owner's opening film, with sound, upright framing and an optional full-frame view.
2. Choose Russia or Ukraine, then Full training or Skip the basics.
3. Optional basics: select tanks, give a Move order, open a city, inspect a unit card,
   research, produce infantry, patrol a drone and queue construction.
4. Supply film. The American ship arrives at Odesa; the European train arrives at Lviv.
5. Required aid lessons: inspect/unload both vehicles and move reinforcements.
6. Required Warfront systems: Guard on, Industry, a real trade route, a station-capacity
   upgrade, inspect a weapon's world price, economic victory, diplomacy, reports, Guard off.
7. Training reward, then continue the full match.

Only the basic controls have a Skip button. Both training choices retain the supply film,
aid arrival and required feature lessons. As before, a film can be skipped without awarding
lesson completion. Section two's progress covers the aid and feature chapters together.

## Confirmed failures and repairs

- **City tap picked an army.** During a city-related lesson, the city model or an overlapping
  garrison badge now opens that city. Ordinary campaign tap cycling is unchanged. A gold
  OPEN [CITY] control, arrow and pulsing ring also open the actual city directly.
- **Move could never finish.** The normal order handler clears army selection after accepting
  an order. Training previously inspected only the current selection. The accepted action is
  now recorded before selection closes; it survives saves and reloads.
- **Missing native film waited forever.** A missing installed file was treated like a pending
  browser pack. It now shows Retry/Continue. Real browser film requests are urgent, have a
  timeout, and recover on retry. Playback stalls have a separate watchdog; background pausing
  is excluded. Films are loaded once on the main thread and completion emits once.
- **Previous game UI blocked the next tutorial.** A new training launch closes old panels,
  clears unfinished orders and removes old combat effects before teaching starts.
- **Phone startup did unnecessary work.** Starting training no longer recreates the complete
  campaign army only to delete it. Phones release old models at a frame boundary and deploy
  the tutorial force within the existing frame budget, updating loading progress.
- **Feature credit was too shallow.** Opening Trade is insufficient: a route must exist.
  The Industry and terminal lessons require real queued/completed construction. World prices
  require selecting a weapon in the actual market selector. In-menu controls pulse without
  blocking input. Guard off waits for its report to close before auto-advancing.

The existing films, captions, camera pan keys, music, realistic models, starting formations,
Russia's economy advantage, per-vehicle manifests and 5+5 aid loadout remain. A level-1 capital
station is ensured for each side so both can practise the route/capacity lessons.

Revision-1 unfinished saves migrate to lesson revision 2. Old menu-only feature credits are
cleared; units and already delivered cargo remain. Validation accepts both revisions.

## Validation

Godot `4.6.3.stable.official.7d41c59c4`:

| Check | Passed | Failed |
|---|---:|---:|
| `test_training_match.gd` | 97 | 0 |
| `test_training_interaction.gd` | 13 | 0 |
| `test_training_cinema.gd` | 23 | 0 |
| `test_city_army_tap_cycle.gd` | 4 | 0 |
| `test_home_button.gd` | 5 | 0 |
| `test_startup_progress.gd` | 8 | 0 |
| Total | 150 | 0 |

The new input regression originally reproduced failed Move completion, city selection and
missing-film recovery. It now also checks stale panels/orders and the garrison badge route.
Cinema checks exercise real decoding, pause/retry/stall handling, web download priority/retry,
and fill/full-frame geometry at 320×640, 720×1440, 720×1560, 1080×2340 and 1440×720.

`capture_training_targets.gd` captures the actual opening/supply films, two-section choice,
animated tank/city guidance, opened city and ship arrival under native OpenGL. Set CAPTURE_DIR;
CAPTURE_ANIMATION=1 also records the city callout and its opened panel as PNG frames.
Original model assets were loaded read-only from asset-only packs of the live game for QA.
Do not load a complete old export pack over the repair: its script remaps would run old code.

The thin source checkout logs the known missing optional rail model in headless logic tests.
Restored-asset captures use the real rail/building/weapon models and can log UID path fallbacks.
These are not physical Android tests, a performance certification or a completed full-match test.

## Integration and release status

No APK/AAB was exported, no Play release uploaded, no website deployed and no live branch merged.
Both films play in source tests and exist in the retrieved live web pack. That does not establish
what is packaged in the owner's installed AAB or reproduce the phone-specific failure.

Apply this repair to the complete release checkout. Preserve all private models, textures,
licensed music, account configuration, signing material and other game features. Do not export
this thin source checkout as a substitute complete APK. Inspect the final Android bundle for both
`.ogv` files and play both with sound on Matthew's Samsung before calling the phone issue fixed.
`export_presets.cfg` was not changed.

This repairs the existing local training flow. Shared online two-player teaching and server-side
commander-level gating are separate work; this change does not implement or certify them.
