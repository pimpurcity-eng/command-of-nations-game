# Command of Nations 0.21 — phone repairs

Based on existing 0.20 source, preserving its map and private original weapons. Package com.commandofnations.test, version code 21. Same signing certificate as 0.14–0.20. Install over the existing test app; do not clear saved data.

Changes:
- Inspecting enemy equipment no longer silently changes the player nation in the all-weapons map. Territory relation refresh includes the selected nation.
- Multi-army city-model taps take priority over overlapping army picks. City-label orders preserve and move the selected group.
- Attack orders in the paused all-weapons map start simulation, matching Move. Missile launch markers use the source nose local axis before transforming, including rotated noses; fixed silo launches originate at the surface hatch.
- Fixed silo fitting preserves the source ground plane, placing the underground shaft below terrain rather than raising the entire model into a tower.
- Enlarged selected title, portrait, status and order buttons. Map labels draw behind the HUD.
- Cached equipment lookup and per-frame stack membership; range checks before visibility and polygon checks; spatial neighbours for melee, capture and ranged combat; skip building damage calculations when no damage exists; avoid unchanged shadow mesh rebuilds; skip off-screen rotor/transform updates.
- Strategic simulation dispatches at 10 Hz while preserving accumulated time. Direct clock advancement and combat/reload/economy rates remain unchanged.

Validation: ten source suites passed: phone regression (10), map army selection (10), drone/launcher flight (98), campaign, touch controls, mission markers (413), economy (13), naval movement (53), battle effects, weapon catalog/models (1495). Native 720×1440 renders reviewed. Desktop headless 143-unit workload: unit visual updates ~6.6 ms before / ~1.6 ms after; simulation updates ~246 ms before / ~26 ms after. These measure CPU work in this environment, not Android FPS. Physical Android testing remains unperformed.

The upright object reported in the screenshot was the S3 fixed missile silo, specifically its buried shaft incorrectly lifted above the terrain. No original asset files were discarded.
