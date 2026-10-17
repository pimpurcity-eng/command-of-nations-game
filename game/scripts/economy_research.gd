class_name EconomyResearch
extends RefCounted
## National economic technology improves constructed facilities, never creates units.
static var levels: Dictionary = {}
static var _catalog: Array = []
static func catalog() -> Array:
	if not _catalog.is_empty(): return _catalog
	var buildings: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	for country in MapDefinition.countries().map(func(c):return c.id):
		for building in buildings:
			if building.id not in ["industry","recruitment_center","infrastructure","train_station","bunker"]: continue
			var item: Dictionary = building.duplicate(true)
			item.id = "economy_" + building.id + "_" + country
			item.country = country
			item.category = "Economy"
			item.visual_kind = "economy"
			item.family = building.name
			item.name = building.name + " technology"
			item.research_days = [1,3,7,11,16]
			item.research_tiers = []
			for tier in range(1,6):
				item.research_tiers.append({"model":building.get("model_tiers",[""])[mini(tier-1,building.get("model_tiers",[""]).size()-1)],"name":building.name + " · technology " + str(tier),"improvement":"+" + str((tier-1)*5) + "% facility effectiveness"})
			_catalog.append(item)
	return _catalog
static func spec(id: String) -> Dictionary:
	for item in catalog():
		if item.id == id: return item
	return {}
static func factor(country: String, building: String) -> float:
	return 1.0 + 0.05 * maxi(0,int(levels.get("economy_" + building + "_" + country,1))-1)
