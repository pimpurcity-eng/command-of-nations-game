class_name ProductionGroups
extends RefCounted
const TITLES := ["Economy", "Aircraft", "Ordnance", "Tanks", "Naval", "Barracks"]
const BUILDINGS := ["industry", "airbase", "factory", "tank_plant", "naval_base", "barracks"]
static func index(spec: Dictionary) -> int:
	if spec.get("category", "") == "Economy": return 0
	if spec.get("visual_kind", "") == "naval": return 4
	if spec.get("visual_kind", "") == "fighter": return 1
	if spec.get("category", "") in ["Armor", "Mechanized"]: return 3
	if spec.get("category", "") == "Infantry": return 5
	return 2
static func building(spec: Dictionary) -> String:
	return "missile_factory" if spec.get("category", "") == "Missiles" else BUILDINGS[index(spec)]
static func title(spec: Dictionary) -> String: return TITLES[index(spec)]
