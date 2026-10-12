# Command of Nations 0.22

Continues the existing game from the earlier 0.21 phone repairs, then incorporates the pending menus/province work and the owner's October 12 originals. Android package `com.commandofnations.test`, version code 22, ARM64, API 24 minimum. Update the existing installation; no routine uninstall or data clearing.

## Included

- Earlier phone fixes retained and rechecked: nation identity, multi-army city orders, missile attack from a paused inspection map, correct launcher muzzle, underground silo shaft, larger bottom unit display and simulation/stack performance changes.
- Finger scrolling for nested menus and both axes of the research tree. Five groups match production buildings, using the illustrated air-defense layout with intermediate optional upgrades. Equipment pictures use models rather than nation flags.
- New campaigns have one starting, middle and best-level unit of every equipment family. This includes the new naval branches. Existing saved armies are preserved.
- Ten naval branches: frigates, destroyers, corvettes, submarines and carriers for each side. Three distinct model eras occupy levels 1/3/5, with systems upgrades between them. Existing frigate/carrier/submarine family IDs remain valid for older saves. European equipment equips Ukraine in this scenario. No American weapons added.
- Supplied barracks, ordnance factory, tank plant, industry, recruitment center, naval base, aircraft factories, city walls, rural airports and train station replace their matching facilities. Aircraft factories and walls have five model levels. Original geometry and colors are retained; fitted/merged visuals limit draw calls.
- Oil, metal and rare-earth originals replace the corresponding resource installations. The supplied food asset is available in the model viewer; a food resource economy has not been introduced.
- City logistics uses the train-station model. Completed nearby friendly stations connect with supplied tracks along existing land routes, without water or hostile crossings. Track instances are batched; construction state restores their network from saves. Rural logistics uses road pieces and retains its existing travel/construction bonus.
- Naval bases and naval production are coastal-only. Provinces can build local industry, forts, roads/logistics and airfields but cannot produce units.
- Original civilian ships, locomotives, wagons, road and railway pieces are in the model viewer. Cargo loading, running trains and complete carrier flight operations remain separate gameplay work.

## Verification and limits

Earlier phone regression: 10 checks. Menu/province regression: 162 checks. New naval/building/rail/save integration: 55 checks. Economy: 13; naval movement/sonar: 125; weapon catalog/models: 1630; aircraft/drone/launcher: 98; new weapons: 245. Campaign, air-defense tree and building suites also pass. Final affected suites re-run after changes. Native portrait renders reviewed for naval research, buildings, stations/tracks and rural construction. Exported assets and native runtime bytes verified, with packaged phone and asset regressions recorded alongside the APK hash and certificate.

These are desktop Godot and packaged-resource checks. Physical Android frame rate/touch testing has not been performed. The wider audit's multiplayer, richer diplomacy, cargo, specialist engineering and other systems are not represented as completed. Existing city building definitions remain available pending the owner's explicit building-cut selection; older construction saves keep their buildings.
