# Warfront Mandate: WW3 — 0.23

New cinematic native Godot opening with portrait/landscape layouts, country selection, Continue/New Campaign, all-weapons range, actual loading progress, music/sound switches, doctrine and language settings. The 3D world stops drawing behind the opaque opening. Application and Android launcher names use Warfront Mandate. Existing Android package and signing certificate remain unchanged.

Claude work integrated from `6fb592203a9b2599dab5a6e9cc6f0e57e7afd793`: 37 original synthesized effects and menu/battle themes; diplomacy, peace/right of way/shared vision/coalitions and local chat; victory types and scoreboard; battle reports/newspaper; entrenchment, retreat, annexation; doctrine/stealth/radar and strategic weapons; local achievements/medals, tutorial and attack alerts; translation support and account-client progression/leaderboard/deletion. This remains a single-player regional game. Supabase migrations 002/003 are provided, not deployed by this change; live account progression/leaderboard requires a configured backend. Europe and world maps remain excluded.

## Owner rules

- Three starting units per military family, levels 1/3/5. Aircraft stay in the starting force without an airport; they are parked until an airport is constructed. The all-weapons test range permits aircraft operation without constructing an airport.
- Six research categories: Economy, Aircraft, Ordnance, Tanks, Naval and Barracks. Military models occur at levels 1/3/5, upgrades at 2/4. Research days vary by branch. Older optional refinements remain loadable for existing saves; they no longer add extra rows to the new tree. Economic research improves existing facilities by 5% per technology level above level 1.
- Cities: industry, recruitment, train station, Capitol, barracks, tank plant, ordnance factory, missile factory, airport, coastal naval base, bunkers and roads. Only capitals begin with one train station. Other buildings start at zero. Retired financial/material/electronics/fuel/research buildings are hidden from new construction while old saves retain compatibility.
- Provinces allow industry, roads, bunkers, airfields, train stations and coastal naval bases; they never produce units. Missile factory is a separate construction/production requirement and temporarily uses the supplied ordnance-building model pending its dedicated model.
- Production lists cities controlled by the player. Enemy city silhouettes stay visible; construction inventory and military/economic facilities require vision. Unit health bars and integer levels appear on the map, and red attack arcs are removed.
- Water masks are regenerated from the actual province geometry. Ships use the same visible land geometry, validate movement segments, and stop/replan blocked saved routes. Ocean shading has a matching shoreline distance gradient.

## Validation

| Area | Checks | Result |
| --- | ---: | --- |
| Opening | 20 | Passed |
| Startup | 7 | Passed |
| Owner rules | 280 | Passed |
| Menu and provinces | 162 | Passed |
| Phone regressions | 10 | Passed |
| Audio | 15 | Passed |
| Victory | 19 | Passed |
| Frontline | 14 | Passed |
| Diplomacy | 21 | Passed |
| Doctrine and strategic weapons | 21 | Passed |
| Progression | 17 | Passed |
| Accounts | 28 | Passed |
| Naval movement | 125 | Passed |

Native Godot Compatibility rendering inspected separately for the opening, six research groups, model/upgrade tree, city buildings, unit health and coast. No physical Android device was available for this build. The signed APK verifies with v2/v3 signatures and the existing certificate. All 3,160 exported entries match the APK byte-for-byte; classes.dex and both ARM64 libraries match 0.22 unchanged. Android version code 23, name 0.23-warfront-ww3, package com.commandofnations.test and launcher label Warfront Mandate were verified. Packaged owner-rule checks are recorded separately.

## Optimized files checked

The three Drive archives in “Optomized” are valid and contain 385 GLBs. There are 261 unambiguous filename matches with current private assets: 307,593,160 bytes versus 164,982,120 bytes, about 46% smaller; mesh definitions fall from 103,104 to 784. These are metadata comparisons, not measured phone FPS. No optimized replacements or American units were added; matching bounds, paint, pivots and animations still need visual validation before replacement.
