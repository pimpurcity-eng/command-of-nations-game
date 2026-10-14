class_name CountryTraits
extends RefCounted
## National traits (owner 2026-10-14, Call of War style): every country has one strength and one
## weakness, and some get certain weapons before the others. They stack with the doctrines.
##   Russia   + units 15% cheaper            - research 15% slower        tanks & missiles 1 day early
##   China    + builds 25% faster            - units 10% weaker
##   America  + weapons 15% stronger         - units 20% more expensive   aircraft & missiles 2 days early
##   Europe   + research 20% faster          - production 15% slower      air defence 2 days early
##   Ukraine  + drones 15% cheaper           - 15% less manpower          drones 2 days early
const TRAITS: = {
	"russia": {"name": "Russia", "plus": "Units 15% cheaper", "minus": "Research 15% slower", "early": "Tanks and missiles 1 day early",
		"cost": 0.85, "research": 0.85, "early_kinds": ["armor", "missile_launcher"], "early_days": 1},
	"china": {"name": "China", "plus": "Builds 25% faster", "minus": "Units 10% weaker", "early": "",
		"build": 1.25, "combat": 0.9},
	"united_states": {"name": "America", "plus": "Weapons 15% stronger", "minus": "Units 20% more expensive", "early": "Aircraft and missiles 2 days early",
		"combat": 1.15, "cost": 1.2, "early_kinds": ["fighter", "missile_launcher"], "early_days": 2},
	"europe": {"name": "Europe", "plus": "Research 20% faster", "minus": "Production 15% slower", "early": "Air defence 2 days early",
		"research": 1.2, "build": 0.85, "early_kinds": ["air_defense"], "early_days": 2},
	"ukraine": {"name": "Ukraine", "plus": "Drones 15% cheaper", "minus": "15% less manpower", "early": "Drones 2 days early",
		"drone_cost": 0.85, "manpower": 0.85, "early_roles": ["drone"], "early_days": 2},
}
## Countries that count as Europe for traits.
const EUROPE: = ["united_kingdom", "france", "germany", "poland", "europe"]

static func of(country: String) -> Dictionary:
	if country in EUROPE: return TRAITS.europe
	return TRAITS.get(country, {})

static func summary(country: String) -> String:
	var traits: = of(country)
	if traits.is_empty(): return ""
	var text: String = "+ " + str(traits.plus) + "  ·  − " + str(traits.minus)
	if not str(traits.get("early", "")).is_empty(): text += "  ·  " + str(traits.early)
	return text

static func build_factor(country: String) -> float: return float(of(country).get("build", 1.0))
static func research_factor(country: String) -> float: return float(of(country).get("research", 1.0))
static func combat_factor(country: String) -> float: return float(of(country).get("combat", 1.0))
static func manpower_factor(country: String) -> float: return float(of(country).get("manpower", 1.0))

## Applied once to the weapons catalogue when it loads: prices and research days per country.
static func apply(catalog: Array) -> Array:
	for family in catalog:
		if not family is Dictionary: continue
		var traits: = of(str(family.get("country", "")))
		if traits.is_empty() or family.get("_traits_applied", false): continue
		family["_traits_applied"] = true
		var factor: = float(traits.get("cost", 1.0))
		if str(family.get("role", "")) == "drone": factor *= float(traits.get("drone_cost", 1.0))
		if factor != 1.0 and family.get("cost") is Dictionary:
			for resource in family.cost: family.cost[resource] = roundi(float(family.cost[resource]) * factor)
		var early: bool = str(family.get("visual_kind", "")) in traits.get("early_kinds", []) or str(family.get("role", "")) in traits.get("early_roles", [])
		if early and family.get("research_days") is Array and not family.get("starter", false):
			var days: Array = family.research_days
			for i in days.size(): days[i] = maxi(1, int(days[i]) - int(traits.get("early_days", 0)))
	return catalog
