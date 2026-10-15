class_name Doctrine
extends RefCounted
## Military doctrines (Conflict of Nations style). Owner 2026-10-15: "There's going to be four
## doctrines: American, Russian, Chinese and European. Quit making double things" - the doctrine
## is the only national bonus (the old country traits are folded in; CountryTraits reads this).
## The country picks it: Russia is Russian, Ukraine is European.
## Owner: Russia's air defence and rockets are better than Europe's; Europe has the better tanks,
## aircraft and research. Every doctrine has strengths and weaknesses so matches stay even.
const DOCTRINES: = {
	"russian": {"name": "Russian", "plus": "Air defence, rockets, artillery and missiles +15%. Units 10% cheaper.", "minus": "Aircraft -10%. Research 10% slower.",
		"early": "Air defence and missiles 1 day early", "cost": 0.9, "research": 0.9, "early_kinds": ["air_defense", "missile_launcher"], "early_days": 1},
	"european": {"name": "European", "plus": "Tanks and aircraft +10%. All armies defend +10%. Research 15% faster. Drones 15% cheaper.", "minus": "Air defence and missiles -5%. Production 10% slower. 10% less manpower.",
		"early": "Drones 2 days early", "research": 1.15, "build": 0.9, "manpower": 0.9, "drone_cost": 0.85, "early_roles": ["drone"], "early_days": 2},
	"american": {"name": "American", "plus": "Air power and navy +15%. Stealth fighters and bombers.", "minus": "Units 20% more expensive. Ground forces -5%.",
		"early": "Aircraft 2 days early", "cost": 1.2, "early_kinds": ["fighter"], "early_days": 2},
	"chinese": {"name": "Chinese", "plus": "Builds 25% faster. Units 10% cheaper.", "minus": "Units 10% weaker.",
		"early": "", "build": 1.25, "cost": 0.9},
}
const DEFAULTS: = {"russia": "russian", "ukraine": "european", "united_states": "american", "united_kingdom": "european", "france": "european", "germany": "european", "poland": "european", "europe": "european", "china": "chinese"}
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
	return float(info(country).get("research", 1.0))

## Western aircraft are stealthy (seen only by radar or up close, UnitSystem.unit_visible).
static func stealth(unit: Dictionary) -> bool:
	return of(str(unit.get("country", ""))) == "american" and unit.get("visual_kind", "") in AIR

## Saves no longer carry doctrines (older saves with a picked doctrine load with the country's own).
static func snapshot() -> Dictionary:
	return {}

static func restore(_state: Dictionary) -> void:
	pass
