# Original ships, drones and missiles — test update 0.16

The owner's four Weapons ZIPs contain 36 GLBs and 46 PNGs, verified against
`NAVAL_DRONE_MISSILE_ASSETS.json`. Original geometry and paint are unchanged.
Run `python3 tools/install_naval_drone_missiles.py missiles_only.zip ships_only.zip drones_only.zip drones_separated.zip`
to restore them privately. Different existing originals are never overwritten.

32 new live models equip 12 families with five research tiers, Days 1/4/8/12/18:
Russian/European fleets and carriers; Russian submarines; Russian/European mobile
missiles and fixed silos; Russian/European drones; Russian Lancet loitering drones.
European equipment serves Ukraine in this regional scenario. Where an archive has
fewer than five models, later tiers explicitly describe upgrades to that same
original vehicle; there are no invented replacement models. Twelve additional
starting groups retain all previous campaign groups.

Orlan/Lancet use the supplied separated drone-only originals in flight. Combined
launcher/drone models and separate catapults remain private in `reserve/`, excluded
from the phone APK. Missile launch pictures remain original files, but only their
ready pictures are packaged for research. Original model textures are preserved, including the original Tomahawk projectile
models needed by the existing missile combat effects.
After first import, run `python3 tools/configure_phone_previews.py` then import
again: only derived research preview textures are limited to 512 pixels.

Start screen: **ALL WEAPONS · REAL MAP** uses the actual regional terrain, cities,
145 provinces and 165 local roads. Every one of the 101 distinct live original
models appears once as a controllable army. Ships occupy separate sea berths;
aircraft use working friendly airbases, with inspection positions on friendly
playable land inside their operating range. The map starts paused with fog and AI off.
Tap an army of either faction to control it; tap Play to execute orders. Continue
restores a saved test map. Start Campaign restores the normal campaign forces.
Move/Attack orders are explicit; ordinary taps switch inspection to another army,
a city or a province. City name tags also release the previous army selection.

Original models now fit a consistent footprint for their role, preserving their
proportions. Tanks/APCs no longer inherit inconsistent source metre scales;
entering a city no longer changes a model's size. Helicopter/drone rotor animation
runs in the actual UnitSystem update, outside the air-defence-only branch. Original
pivots and local axes are retained. Research upgrades replace live models for all
families, rather than only air defence.

Balance remains provisional. Recon drones have no strike damage at tier 1;
Lancet consumes its drone after one strike. Fixed silos reject movement and use
existing conventional missile combat; no nuclear mechanics are implemented.
Ships use existing sea movement/combat; carriers do not yet launch aircraft and
submarines do not yet have stealth/dive mechanics. No generic new model or altered
paint is introduced. Original archived campaign tests retain their previous
one-army-per-family test setup.

Verification: all eight required native Godot/Xvfb suites plus test_new_weapons,
test_province_connections and test_all_weapons_map. Native real-map screenshots
must be shown before delivering an APK. Models, APKs and signing files stay private.
