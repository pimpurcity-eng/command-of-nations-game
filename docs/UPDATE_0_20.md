# Command of Nations 0.20 — consolidated test update

Date: 12 October 2026. Based on pending weapon source commit 5ee023a, retaining the existing game, original models and portrait Compatibility renderer. Package com.commandofnations.test; version code 20. Private Android test build, not a store release.

## Included

- Pending non-American weapons: 58 equipment families, 143 distinct controllable tier models, 181 gallery entries; revised ships and new infantry/support/aircraft/launchers.
- Existing phone fixes included: drone/ship model selection, shared helicopter/drone flight and rotor motion, launch points, larger selected unit/city headings, Ukraine idle headings toward Russia, fixed patrol markers for all aircraft and missile target reticles without missile routes.
- Movement pace 3 instead of the older 10: 70% slower travel, with production/research clock timing unchanged. Accepted orders still require Play in the paused campaign; all-weapons inspection orders start simulation automatically.
- Shore taps within 0.30 map units snap onto nearby water. Routes still reject land crossings. Naval/submarine movement and selection checks pass.
- Missile visual flight lasts 2.4–4 real seconds with a more visible exhaust; damage/reload timing remains separate.
- Ukraine modernization charges Ukraine's resources. New infantry/support saves validate; aircraft endurance validation follows the family range rather than an obsolete fixed limit.
- Cities earn funds/manpower plus their main commodity; selected rural provinces have commodity sites. Rural provinces also produce baseline funds/manpower. City specialties no longer receive a second site-income stream.
- Occupation output 25% for cities and rural sites, multiplied by morale. Resource installations stay inside their province; resource badges remain visible at strategic zoom. Farmland is no longer assigned to manpower.
- Daily army upkeep: funds 10% of production cost/day, fuel 8%, manpower 2%. These are initial game balance values, not real military costs. All-weapons inspection mode is exempt. Stockpiles cannot go negative; shortages are shown in the supply exchange, and insufficient resources hold production.
- Province morale is saved. Conquest sets 25%; daily recovery moves 15% toward a target of 100 for core provinces or 80 for occupied provinces, reduced by 20 while that country's capital is lost. Low-morale occupied provinces without a garrison have a seeded 20% daily revolt chance during war. All parts of a logical province change control together.
- Morale below 80 reduces production/construction speed, with a 25% speed floor. Out-of-combat units on friendly territory, and naval units, recover 15% of missing HP at day change; airborne units do not.
- Surface ships, submarines and carriers have different naval damage. Surface escorts/submarines have sonar; submarine detection requires sonar rather than ordinary sight. Surface ships have ground bombardment and air defense; carriers have defensive air weapons. Carrier flight operations remain unfinished.
- A-50U has a larger scouting radius; infantry/support now have explicit terrain modifiers. Hold-fire units retain melee defensive fire.
- City/hourly resource displays share the actual income calculation. Supply exchange shows net income after upkeep. Removed obsolete research-center speed description; national research remains independent, with two slots.
- Restored original city/building assets and missing derived weapon pictures. Export retains model texture dependencies; interface thumbnails are limited for phone use, while source originals are retained.

## Validation

Source suites cover weapon catalog/models, all-weapons map, drone/helicopter/launcher behavior, naval movement/sonar/counters, economy/ownership/modernization/saves, patrol/missile markers, headings and wrapping, buildings, combat effects, touch controls, startup loading, map army selection, phone feedback, accounts, campaign and province roads. Native 720×1440 renders reviewed for ships, aircraft and an actual missile launch. Final release metadata and packaged-resource checks are recorded in RELEASE_VALIDATION.json.

The APK uses the original certificate, SHA256 0289d3b051ee5e71dd25bc707b459f0a1e5413faea920069aa8636dc95b84bf0, and can update ChatGPT builds 0.14–0.19. Do not routinely uninstall or clear data. Android 7/API 24 minimum, ARM64. Physical Android testing has not been performed in this environment.

## Still outstanding from the wider audit

This is not full Call of War parity. Shared multiplayer/hosting, player trading, coalitions and richer diplomacy, victory-point scoring, building damage, cross-class combat distribution, detailed supply penalties, food, complete carrier air operations, cargo/paradrops, specialist repair/bridging/mine-clearing and espionage remain separate work. Morale/counters are a simplified modern-game ruleset, not a claim to reproduce every Call of War formula. The campaign still wins by three opposing city captures or elimination. No American weapons were added to the playable roster. Existing archived assets remain private for later work.
