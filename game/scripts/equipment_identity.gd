class_name EquipmentIdentity
extends RefCounted
static var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
static func spec(id: String) -> Dictionary:
	for equipment in catalog:
		if equipment.id == id: return equipment
	return {}
static func resolve(data: Dictionary) -> String:
	if not spec(data.get("equipment_id", "")).is_empty(): return data.equipment_id
	var name: String = data.get("name", "").to_lower()
	for pair in [["leopard", "leopard2"], ["t-90", "t90"], ["t-72", "t72"], ["challenger", "challenger2"], ["oplot", "oplot"], ["cv90", "cv90"], ["bmp", "bmp3"], ["caesar", "caesar"], ["pzh", "pzh2000"], ["msta", "msta"]]:
		if name.contains(pair[0]): return pair[1]
	var russian: bool = data.country == "russia"
	match data.get("visual_kind", "armor"):
		"ifv": return "bmp3" if russian else "cv90"
		"artillery": return "msta" if russian else "caesar"
	return "t72" if russian else "leopard2"
static func title(id: String) -> String:
	var names: = {"armata": "T-14 Armata", "abrams": "M1A2 Abrams", "t72": "T-72B3", "t90": "T-90M", "leopard2": "Leopard 2", "challenger2": "Challenger 2", "oplot": "Oplot", "bmp3": "BMP-3", "cv90": "CV90", "msta": "Msta-S", "caesar": "CAESAR", "pzh2000": "PzH 2000"}
	return names.get(id, spec(id).get("name", "Unknown equipment"))

static func research_tier(id: String, level: int) -> Dictionary:
	var tiers: Array = spec(id).get("research_tiers", [])
	return tiers[clampi(level - 1, 0, tiers.size() - 1)] if not tiers.is_empty() else {}
static func research_title(id: String, level: int) -> String:
	return research_tier(id, level).get("name", title(id))
static func air_defense_range(unit: Dictionary) -> float:
	return float(research_tier(unit.equipment_id, unit.get("level", 1)).get("range", spec(unit.equipment_id).get("aa_range", 2.4)))
