class_name GoldWallet
extends RefCounted
## Gold, the premium currency (owner 2026-10-13): every player starts each match with 10,000
## free gold that is only good for that match; more can be bought. Like Call of War, gold
## finishes unit production, construction and research early, and buys resources.
## Owner 2026-10-15: CA$10 buys 10,000 gold. Pay for remaining time and only missing
## resources; never charge a paid order's resources twice. All work is measured at 1x.
const START: = 10000
const CURRENCY: = "CAD"
const PURCHASE_GOLD: = 10000
const PURCHASE_CAD_CENTS: = 1000
const PER_HOUR: = 800.0
const MINIMUM: = 1
## Elapsed simulation units per game hour (SimulationClock.REAL_SECONDS_PER_SIM_SECOND = 120).
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
## Gold per unit of each resource bought on the market.
const RESOURCE_PRICE: = {"funds": 1.0, "manpower": 4.0, "food": 1.0, "materials": 2.0, "fuel": 2.0, "electronics": 5.0}
const HACK_PRICE: = {"blackout": 12000, "satellite": 7500, "bank": 7500, "firewall": 5000}
const PACK: = 1000

## Gold to finish `remaining` elapsed units of work now.
static func speedup(remaining: float) -> int:
	if remaining <= 0.0: return 0
	return maxi(MINIMUM, ceili(remaining / HOUR * PER_HOUR))

## Gold for `quantity` of `resource`.
static func resource_price(resource: String, quantity: float) -> int:
	return ceili(float(RESOURCE_PRICE.get(resource, 0.0)) * maxf(0.0, quantity))

## Gold to pay for a bill of resources outright (a unit or building bought with gold).
static func bill_price(bill: Dictionary) -> int:
	var total: = 0
	for resource in bill: total += resource_price(resource, float(bill[resource]))
	return total

static func missing(bill: Dictionary, stock: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for resource in bill: result[resource] = maxf(0.0, float(bill[resource]) - float(stock.get(resource, 0.0)))
	return result

static func quote(remaining: float, bill: Dictionary = {}, stock: Dictionary = {}) -> Dictionary:
	var shortfall: = missing(bill, stock)
	var time: = speedup(remaining)
	var resources: = bill_price(shortfall)
	return {"time":time, "resources":resources, "total":time + resources, "missing":shortfall}

## Called only after the complete gold quote has been paid. Gold covers any shortfall.
static func consume_available(stock: Dictionary, bill: Dictionary) -> void:
	for resource in bill: stock[resource] = maxf(0.0, float(stock.get(resource, 0.0)) - float(bill[resource]))

static func explanation(price: Dictionary) -> String:
	return "%d gold for remaining time + %d gold for missing resources = %d gold" % [price.time, price.resources, price.total]

static func cad_label(gold: int) -> String:
	return "CA$%.2f" % (float(gold) * PURCHASE_CAD_CENTS / PURCHASE_GOLD / 100.0)
