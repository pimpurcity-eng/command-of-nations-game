class_name GoldWallet
extends RefCounted
## Gold, the premium currency (owner 2026-10-13): every player starts each match with 10,000
## free gold that is only good for that match; more can be bought. Like Call of War, gold
## finishes unit production, construction and research early, and buys resources.
## Prices follow Call of War player guides: about 850 gold to skip 12 hours, and about
## 2,500 gold for 5,000 resources.
const START: = 10000
const PER_HOUR: = 850.0 / 12.0
const MINIMUM: = 20
## Elapsed simulation units per game hour (SimulationClock.REAL_SECONDS_PER_SIM_SECOND = 120).
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
## Gold per unit of each resource bought on the market.
const RESOURCE_PRICE: = {"funds": 0.1, "manpower": 0.5, "food": 0.3, "materials": 0.5, "fuel": 0.5, "electronics": 0.8}
const PACK: = 1000

## Gold to finish `remaining` elapsed units of work now.
static func speedup(remaining: float) -> int:
	return maxi(MINIMUM, ceili(maxf(remaining, 0.0) / HOUR * PER_HOUR))

## Gold for `quantity` of `resource`.
static func resource_price(resource: String, quantity: float) -> int:
	return ceili(float(RESOURCE_PRICE.get(resource, 0.5)) * quantity)

## Gold to pay for a bill of resources outright (a unit or building bought with gold).
static func bill_price(bill: Dictionary) -> int:
	var total: = 0
	for resource in bill: total += resource_price(resource, float(bill[resource]))
	return total
