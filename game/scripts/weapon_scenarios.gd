class_name WeaponScenarios
extends RefCounted
## Weapons range test maps (owner 2026-10-14): one small scenario per kind of unit, the two
## sides facing each other at the front, instead of every weapon on one map.

const LIST: = [
	{"id": "armor", "title": "Tanks & armour", "status": "Tanks and armoured vehicles"},
	{"id": "artillery", "title": "Artillery & rockets", "status": "Artillery, mortars and rocket launchers"},
	{"id": "air", "title": "Planes & air defence", "status": "Planes, helicopters and the air defence that shoots them"},
	{"id": "drones", "title": "Drones & missiles", "status": "Drones and missile launchers"},
	{"id": "navy", "title": "Navy", "status": "Warships at sea"},
	{"id": "support", "title": "Support vehicles", "status": "Supply, recovery, engineer and bridge vehicles"},
	{"id": "all", "title": "All weapons", "status": "Every original weapon on the real campaign map"},
]

static func title(id: String) -> String:
	for scenario in LIST:
		if scenario.id == id: return scenario.status
	return LIST[-1].status

static func includes(id: String, family: Dictionary) -> bool:
	var kind: String = family.get("visual_kind", "")
	var category: String = family.get("category", "")
	var rockets: bool = str(family.id).begins_with("rockets")
	match id:
		"armor": return kind == "armor" or kind == "ifv"
		"artillery": return kind == "artillery" or (kind == "missile_launcher" and rockets)
		"air": return kind == "air_defense" or (kind == "fighter" and category != "Drones")
		"drones": return (kind == "fighter" and category == "Drones") or (kind == "missile_launcher" and not rockets)
		"navy": return kind == "naval"
		"support": return kind == "support"
	return true
