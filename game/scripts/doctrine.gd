class_name Doctrine
extends RefCounted
## Military doctrines (Conflict of Nations style). Owner 2026-10-15: "There's going to be four
## doctrines: American, Russian, Chinese and European. Quit making double things" - the doctrine
## is the only national bonus (the old country traits are folded in; CountryTraits reads this).
## The country picks it: Russia is Russian, Ukraine is European.
## Owner: Russia's air defence and rockets are better than Europe's; Europe has the better tanks,
## aircraft and research. Every doctrine has strengths and weaknesses so matches stay even.
const DOCTRINES: = {
	"russian": {"name": "Russian", "plus": "Air defence, rockets, artillery and missiles +15% damage and +5% HP. Units 10% cheaper.", "minus": "Aircraft -10%. Research 10% slower.", "hp_kinds": {"air_defense": 1.05, "artillery": 1.05, "missile_launcher": 1.05},
		"early": "Air defence and missiles 1 day early", "cost": 0.9, "research": 0.9, "early_kinds": ["air_defense", "missile_launcher"], "early_days": 1},
	"european": {"name": "European", "plus": "Tanks and aircraft +10% damage and +8% HP. All armies defend +10%. Research time -15%. Drones 15% cheaper.", "minus": "Air defence and missiles -5%. Production 10% slower. 10% less manpower.", "hp_kinds": {"armor": 1.08, "fighter": 1.08},
		"early": "Drones 2 days early", "research_time": 0.85, "build": 0.9, "manpower": 0.9, "drone_cost": 0.85, "early_roles": ["drone"], "early_days": 2},
	"american": {"name": "American", "plus": "Air power and navy +15% damage and +5% HP. Stealth fighters and bombers.", "minus": "Units 20% more expensive. Ground forces -5%.", "hp_kinds": {"fighter": 1.05, "naval": 1.05},
		"early": "Aircraft 2 days early", "cost": 1.2, "early_kinds": ["fighter"], "early_days": 2},
	"chinese": {"name": "Chinese", "plus": "Builds 25% faster. Units 10% cheaper.", "minus": "Units deal 10% less damage and have 5% less HP.", "hp": 0.95,
		"early": "", "build": 1.25, "cost": 0.9},
}
const DEFAULTS: = {"russia": "russian", "belarus": "russian", "serbia": "russian", "ukraine": "european", "united_states": "american", "poland": "american", "romania": "american", "europe": "european", "china": "chinese"}
const AIR: = ["fighter", "bomber", "drone", "helicopter"]
const ROCKETS: = ["air_defense", "artillery", "missile_launcher"]

static func of(country: String) -> String:
	return DEFAULTS.get(country, "european")

static func info(country: String) -> Dictionary:
	return DOCTRINES[of(country)]

static func summary(country: String) -> String:
	var d: = info(country)
	return d.name + " doctrine: + " + str(d.plus) + "  − " + str(d.minus)

## Combat strength factor for a unit attacking ("attack") or defending ("defense").
static func combat_factor(unit: Dictionary, effect: String) -> float:
	var kind: String = unit.get("visual_kind", "")
	match of(str(unit.get("country", ""))):
		"russian":
			if kind in ROCKETS: return 1.15
			if kind in AIR: return 0.9
		"european":
			var factor: = 1.10 if effect == "defense" else 1.0
			if kind == "armor" or kind in AIR: factor *= 1.10
			elif kind in ["air_defense", "missile_launcher"]: factor *= 0.95
			return factor
		"american":
			if kind in AIR or kind == "naval": return 1.15
			return 0.95
		"chinese":
			return 0.9
	return 1.0

static func research_factor(country: String) -> float:
	var data: = info(country)
	if data.has("research_time"): return 1.0 / float(data.research_time)
	return float(data.get("research", 1.0))

## HP differences use this same doctrine system, never a second set of country bonuses.
static func hp_factor(unit: Dictionary) -> float:
	var d: Dictionary = info(str(unit.get("country", "")))
	return float(d.get("hp", 1.0)) * float(d.get("hp_kinds", {}).get(str(unit.get("visual_kind", "")), 1.0))

## Western aircraft are stealthy (seen only by radar or up close, UnitSystem.unit_visible).
static func stealth(unit: Dictionary) -> bool:
	if of(str(unit.get("country", ""))) != "american" or unit.get("visual_kind", "") not in AIR: return false
	var model: String = EquipmentIdentity.research_tier(str(unit.get("equipment_id","")),int(unit.get("level",1))).get("model","")
	return ["f22","f35","f47","b2a","b21","xq58"].any(func(word):return model.contains(word))

## Saves no longer carry doctrines (older saves with a picked doctrine load with the country's own).
static func snapshot() -> Dictionary:
	return {}

static func restore(_state: Dictionary) -> void:
	pass
