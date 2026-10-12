# Command of Nations — menus, research and province construction candidate

Based on the existing signed 0.21 game. This is a verified source candidate; no new APK has been delivered. The owner's additional ships and building-removal choices are still pending, so the next install should combine the whole batch.

## Changes

- A single touch gesture handler supports vertical/horizontal research swipes, nested production lists, construction lists and the other scrollable menus. A drag cancels the underlying button press; taps retain normal actions.
- Research and production share five groups: Barracks (infantry), Tank Plant (tanks and mechanized vehicles), Support Factory (artillery, air defence, missiles and ground support), Airbase (all aircraft and drones), Naval Base (surface ships, submarines and carriers). Equipment prerequisites match those buildings. No city building types were removed pending the owner's review.
- Every research group uses the original large illustrated air-defence card layout. The branch headings and cards share one scroll surface so they remain aligned horizontally. Existing five model tiers are retained with their individual day gates. Four smaller optional upgrades appear between the model tiers; each improves the corresponding model's national combat effectiveness by 6%, consumes a normal research slot, has its own cost/day/time, and is saved. Existing repeated-model tier upgrades are retained too.
- Equipment, research, production and map-list pictures use original model previews. Nation flags are no longer fallback equipment images. Actual ownership flags remain ownership indicators.
- New campaigns start three units of every current equipment family at levels 1, 3 and 5 (174 units across both nations). Air units have friendly home bases and ships start on water. Starting top-tier units do not unlock later production research. Existing saves keep their own armies.
- Inland city screens hide naval-base construction, and naval production is omitted for inland cities. Rules still reject inland naval buildings and sea-unit production without a coast/port.
- Selecting a province changes the bottom Produce tab to Construct. Rural provinces offer local industry, fortifications, roads/logistics and airfields; cities retain the production buildings. Province construction has costs, timers, queues, refunds, occupation/morale holds, save validation and map visuals. Provinces cannot enter city production queues or create units.
- Local industry increases rural currency/manpower and commodity income; forts protect the hub; logistics accelerates rural ground travel and construction; completed airfields support aircraft basing and refuelling. These are this game's explicit initial balance rules, not a claim to copy either reference game's exact numbers.

## Reference review

Call of War groups mobile research by the corresponding production buildings and supports swiping the tree in both directions. Its current construction model separates city production buildings from rural local industry, airstrips and fortifications. Conflict of Nations has a context-sensitive army/province bar and a separate rural construction list (outposts, airfields, local industry and logistics). Those interface and eligibility patterns informed this change. Old wiki cost tables are not treated as current balance numbers.

Sources:
- https://wiki.callofwar.com/wiki/RESEARCH
- https://wiki.callofwar.com/wiki/BUILDINGS
- https://wiki.callofwar.com/wiki/CONSTRUCTION_%26_PRODUCTION
- https://wiki.conflictnations.com/User_Interface
- https://wiki.conflictnations.com/Provinces

## Validation

Ten suites passed: menu/province/touch/upgrades, campaign, economy, building expansion, air-defence progression, new-weapon behavior, drone/launcher flight, naval movement, weapon catalog/models and previous phone regressions. New checks exercise real input events over cards/lists, starting tiers for all families, flag-free equipment images, rural construction and actual income/map visuals, aircraft-base availability, old-save compatibility, invalid-state rejection and upgrade combat effects. Native 720×1440 render previews are included. Physical Android touch/performance testing has not been performed.

New ships: Weapons folder checked; latest observed ship archive was ships_v3_russia_europe.zip from 11 October, already present in the existing weapon batch. No later ship upload was observed at this checkpoint.
