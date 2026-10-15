# Transport market and gameplay review — 15 October 2026

Source implementation on `codex/transport-market-review`, based on `claude/v0.26-fixes` at `886c89a`. This is not a deployed web or Android release.

## Owner's transport rules

- Cargo ships and oil tankers have separate national Naval research lines, five levels each. Each line reuses one research artwork across all five levels. Capacities are 30/60/90/120/150 load slots (100 resource units per slot), constrained by the departure port's level. Tankers carry fuel; container ships carry other cargo and equipment.
- Trains use the departure city's completed train-station level: 12/24/36/48/60 load slots. Moscow level 5 can load more than another city at level 1. The receiving station must exist but does not cap the origin's load.
- A railway is created only between two completed city stations over accessible land. Rural province stations do not create railway endpoints. A bilateral trade deal can connect national railways; closed borders and water block the route. The route chooser weights visible hostile threats; it does not inspect hidden armies.
- Cargo aircraft have smaller capacity, 2/4/6/8/10 slots from the departure airbase. Equipment weighs 4 slots for heavy armour, 2 for aircraft, 1 for other equipment.
- Market offers reserve actual resources or an existing idle unit. Infantry and strategic nuclear launchers cannot be sold. Minimum equipment price uses resource-valued replacement cost and research level. No copy of sold equipment stays in the seller's army.
- Buyer funds are held until delivery. On arrival, cargo or equipment transfers, preserving equipment health and research level, and the seller receives payment. Destroyed cargo is lost; buyer funds return. Captured terminals, lost access and embargoes hold delivery.
- Hostile forces can damage trains, ships and aircraft in sight and within their applicable weapon range. A visible player shipment can be inspected on the map and intercepted with selected forces using Attack; war must already be declared. Intercept orders move to the observed shipping lane, rather than magically track an unseen vessel.
- Neutral supply contracts are paid imports rather than free resources. Paid imports and market shipments survive saves. Net export receipts count toward economic income; circular purchases/sales cancel rather than create money or victory income.

## Existing assets and artwork

The owner's `Weapons/civilian_ships_train.zip` was retrieved from connected Drive and inspected. It contains the original locomotive, seven train components, three container ships (Feeder/Panamax/ULCV) and three oil tankers (Coastal/Aframax/VLCC). Original GLBs were restored locally into `game/assets/library/transport/` for build/test inputs. They are not added to public source control. The existing private build asset restoration must retain them.

Five research levels use the existing three models at levels 1/2, 3/4 and 5. Original model colours and meshes are preserved. Two new standalone research artworks were generated with the built-in image-generation tool and packaged as WebP assets: `civil_cargo_ship.webp` and `civil_oil_tanker.webp`. Prompt themes: one civilian container ship / one oil tanker, cinematic three-quarter bow view at sea, entire vessel visible, no writing or logos. The model-to-picture manifest maps all supplied civilian ship variants to their respective shared artwork.

## Review changes

- Economic victory: double the country's starting productive income, keep 250,000 funds and the capital, and maintain those conditions for seven days. This removes the 80% world-income monopoly requirement. Baseline, partial income windows and countdowns persist through saves.
- The tutorial offers Economy and Military openings. Economy players skip the compulsory attack instruction.
- Guard mode already suppresses offensive AI takeover in the inspected branch; that existing protection was retained.
- Online seats derive from the loaded campaign rather than a fixed two-country server list. This does not load or certify a 100-player map.
- Market, trade orders and ownership checks run on the authoritative server; convoy snapshots respect visibility and hide enemy origin/destination. Client ticks reuse player-shipment visual nodes.

## Validation and remaining work

- `tests/test_transport_market.gd`: 61 focused checks pass, no runtime script errors. Tests cover escrow, loss/refund, actual tank ownership/health/tier transfer, reloads, terminal capacity, rail access, sea routing, interdiction damage, enemy information filtering, economic victory, both naval trees and market/research controls.
- Godot 4.5.1 parsed the main scene script, both network scripts, research panel, trade panel and tutorial successfully. The project normally targets Godot 4.6, so release validation must use the normal engine/build pipeline.
- The browser playtest was blocked by this environment's unavailable WebGL2. No completed human-style game round, phone visual/performance test, Android build, full scene regression or live deployment is claimed.
- Run the existing full game regression and a real two-player reconnect/Guard/trade session with the private original asset set before shipping. Balance the provisional load-slot numbers and economic target with playtests.
