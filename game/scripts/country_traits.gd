class_name CountryTraits
extends RefCounted
## Owner 2026-10-15 ("quit making double things"): there are no separate country traits any more.
## Prices, build speed, manpower and early weapons come from the country's doctrine (Doctrine).
static func of(country: String) -> Dictionary:
	return Doctrine.info(country)

static func summary(country: String) -> String:
	return Doctrine.summary(country)

static func build_factor(country: String) -> float: return float(of(country).get("build", 1.0))
static func manpower_factor(country: String) -> float: return float(of(country).get("manpower", 1.0))

## Applied once to the weapons catalogue when it loads: prices and research days per country.
static func apply(catalog: Array) -> Array:
	for family in catalog:
		if not family is Dictionary or str(family.get("country", "")).is_empty(): continue
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
