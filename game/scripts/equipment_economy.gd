class_name EquipmentEconomy
extends RefCounted
## Role prices and work at 1x. CountryTraits applies the one doctrine discount afterwards.
## No dependency on EquipmentIdentity: this runs while that shared catalogue is loading.
static var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/unit_balance.json"))
const LEVEL_COST: = 0.20
const LEVEL_WORK: = 0.25
const LEVEL_UPKEEP: = 0.10

static func apply(catalog: Array) -> Array:
	for spec in catalog:
		var role: String = balance.families.get(str(spec.get("id", "")), "")
		if role.is_empty() or spec.get("_economy_applied", false): continue
		var data: Dictionary = balance.profiles[role].economy
		spec["_economy_applied"] = true
		spec["_previous_cost"] = spec.cost.duplicate(true)
		spec["cost"] = data.cost.duplicate(true)
		spec["upkeep"] = data.upkeep.duplicate(true)
		spec["seconds"] = float(data.production_hours) * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
		spec["research_factor"] = float(data.research_factor)
	return catalog

static func cost(spec: Dictionary, level: int = 1) -> Dictionary:
	var result: Dictionary = {}
	for resource in ProductionSystem.RESOURCES:
		result[resource] = ceili(float(spec.get("cost", {}).get(resource, 0.0)) * (1.0 + LEVEL_COST * (clampi(level, 1, 5) - 1)))
	return result

static func duration(spec: Dictionary, level: int = 1) -> float:
	return float(spec.get("seconds", 0.0)) * (1.0 + LEVEL_WORK * (clampi(level, 1, 5) - 1))

static func upkeep(spec: Dictionary, level: int = 1) -> Dictionary:
	var result: Dictionary = {}
	for resource in ProductionSystem.RESOURCES:
		result[resource] = ceili(float(spec.get("upkeep", {}).get(resource, 0.0)) * (1.0 + LEVEL_UPKEEP * (clampi(level, 1, 5) - 1)))
	return result

## Old paid orders refund the resources actually charged under the previous catalogue.
static func previous_cost(spec: Dictionary) -> Dictionary:
	return spec.get("_previous_cost", spec.get("cost", {})).duplicate(true)

static func valid_paid_cost(value: Variant) -> bool:
	if not value is Dictionary: return false
	for resource in value:
		if resource not in ProductionSystem.RESOURCES: return false
		var amount = value[resource]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 0 or amount > 1000000000: return false
	return true
