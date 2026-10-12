class_name ProductionGroups
extends RefCounted
const TITLES: = ["Barracks", "Tank Plant", "Support Factory", "Airbase", "Naval Base"]
const BUILDINGS: = ["barracks", "tank_plant", "factory", "airbase", "naval_base"]
static func index(spec: Dictionary) -> int:
 if spec.get("visual_kind", "") == "naval": return 4
 if spec.get("visual_kind", "") == "fighter": return 3
 if spec.get("category", "") in ["Armor", "Mechanized"]: return 1
 if spec.get("category", "") == "Infantry": return 0
 return 2
static func building(spec: Dictionary) -> String: return BUILDINGS[index(spec)]
static func title(spec: Dictionary) -> String: return TITLES[index(spec)]
