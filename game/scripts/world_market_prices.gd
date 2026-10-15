class_name WorldMarketPrices
extends RefCounted
## One price book per match, shared by every country. Only delivered, paid trades count.
## Net demand means buying goods back around a circle cannot pump their minimum price.
const BASE: = {"food":1.0,"materials":2.0,"electronics":5.0,"fuel":2.0}
const MAX_DEMAND: = 1.5
var net: Dictionary = {}  # item -> country -> net received quantity
var elapsed: = 0.0

static func item(unit: Dictionary) -> String:
	return "equipment:" + str(unit.get("equipment_id","")) + ":" + str(int(unit.get("level",1)))

func factor(key: String) -> float:
	var demand: = 0.0
	for quantity in net.get(key,{}).values(): demand += maxf(0.0,float(quantity))
	var reference: = 1.0 if key.begins_with("equipment:") else 1000.0
	return 1.0 + clampf(demand / reference * 0.05,0.0,MAX_DEMAND)

func resource(cargo: String) -> float:
	return float(BASE.get(cargo,0.0)) * factor(cargo)

func equipment(unit: Dictionary) -> int:
	var spec: = EquipmentIdentity.spec(str(unit.get("equipment_id","")))
	var bill: = EquipmentEconomy.cost(spec, int(unit.get("level", 1)))
	var total: = 0.0
	for cargo in bill:
		var value: float = 1.0 if cargo == "funds" else 3.0 if cargo == "manpower" else resource(cargo)
		total += float(bill[cargo]) * value
	return maxi(1,ceili(total * factor(item(unit))))

func record(seller: String, buyer: String, cargo: String, amount: float, unit: Dictionary) -> void:
	if seller == buyer: return
	var key: String = cargo if unit.is_empty() else item(unit)
	var quantity: float = amount if unit.is_empty() else 1.0
	if not net.has(key): net[key] = {}
	net[key][seller] = float(net[key].get(seller,0.0)) - quantity
	net[key][buyer] = float(net[key].get(buyer,0.0)) + quantity

func advance(seconds: float) -> void:
	elapsed += maxf(0.0,seconds)
	if elapsed < VictoryRules.DAY / 24.0: return
	# Demand fades back toward the base over time, in game-time rather than UI refreshes.
	var decay: = exp(-elapsed / VictoryRules.DAY)
	for key in net:
		for country in net[key]: net[key][country] *= decay
	elapsed = 0.0

func snapshot() -> Dictionary:
	return {"net":net.duplicate(true),"elapsed":elapsed}

func restore(state: Dictionary) -> void:
	net = state.get("net",{}).duplicate(true)
	elapsed = float(state.get("elapsed",0.0))
