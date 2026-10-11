# Pending weapon batch — October 11

This is source work for the existing Godot game. No new installer was built or released.

Imported the owner's Weapons folder, including the revised `ships_v3_russia_europe.zip`.
The revised ships take precedence over the earlier models. New families are visible in
production and national research: fighters, infantry, support vehicles, light artillery,
transport/radar aircraft, advanced tanks and coastal missile launchers. Small arms and
standalone cruise missile bodies are also available in the Weapons model viewer.

European-service F-16 and E-7 models were excluded because they are American aircraft.
American M113 and M270 models were removed from playable research tiers; supplied
European alternatives fill those tiers. American tank and aircraft stand-ins and the
Tomahawk projectile fallback are no longer used. The American weapons folder was not read.

Coastal missiles target ships. Aircraft and ship missile loadouts use the supplied flight
models. Infantry has ground combat values. Support vehicles are unarmed, producible,
selectable and movable; dedicated repair, bridge-building, transport and radar mechanics
are not implemented by this model-import batch.

All flying units retain shared flight orders and fixed patrol markers. Missile launchers
retain target markers without route lines. Movement pace is 3.0 rather than 10.0, carrying
forward the owner's pending slower-1× change without altering the economy clock.

Validation: model/catalog regression 1,495 checks passed; expanded mission-marker and
facing regression 413 checks passed; bottom-selection heading regression 8 checks passed.
Checks are headless, not visual or phone validation. Submarine movement and final ship
appearance on the phone remain open items before the next installer batch.
