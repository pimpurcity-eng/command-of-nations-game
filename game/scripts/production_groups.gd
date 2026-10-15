class_name ProductionGroups
extends RefCounted
const TITLES := ["Economy", "Aircraft", "Ordnance", "Tanks", "Naval", "Barracks", "Missiles", "Drones", "Support"]  # Missiles, Drones, Support: owner 2026-10-13
const BUILDINGS := ["industry", "airbase", "factory", "tank_plant", "naval_base", "barracks", "missile_factory", "drone_factory", "support_depot"]
static func index(spec: Dictionary) -> int:
	if spec.get("category", "") == "Economy": return 0
	if spec.get("category", "") == "Drones": return 7
	if spec.get("category", "") == "Support" and spec.get("visual_kind", "") == "support": return 8
	if spec.get("visual_kind", "") == "naval": return 4
	if spec.get("visual_kind", "") == "fighter": return 1
	# Owner 2026-10-13: infantry vehicles (APCs/IFVs) are Infantry; air defence is Ordnance.
	if spec.get("category", "") in ["Infantry", "Mechanized"]: return 5
	if spec.get("category", "") == "Armor": return 3
	if spec.get("category", "") == "Missiles": return 6
	return 2
static func building(spec: Dictionary) -> String:
	return BUILDINGS[index(spec)]
static func title(spec: Dictionary) -> String: return TITLES[index(spec)]
## Unit-type silhouette for each group's tab and banner (Call of War style).
const ICONS := ["support", "fighter", "artillery", "armor", "naval", "infantry", "missile_launcher", "drone", "medic"]
## City-screen tab order like Call of War: Infantry, Ordnance, Tanks, Missiles, Air, Drones, Naval, Support.
const CITY_TABS := [5, 2, 3, 6, 1, 7, 4, 8]
const CITY_TITLES := {5: "Infantry", 2: "Ordnance", 3: "Tanks", 6: "Missiles", 1: "Air", 7: "Drones", 4: "Naval", 8: "Support"}
## Families the owner retired (e.g. mine clearing) stay loadable but are never offered.
static func offered(spec: Dictionary) -> bool: return not spec.get("retired", false)

## Consistent naval order in research and production; carriers are the last column.
static func before(a: Dictionary, b: Dictionary) -> bool:
	if index(a) != index(b): return index(a) < index(b)
	if index(a) == 4:
		var order := {"corvettes": 0, "fleet": 1, "destroyers": 2, "submarines": 3, "cargo": 4, "tankers": 5, "carriers": 6}
		var left: int = order.get(str(a.id).get_slice("_", 0), 3)
		var right: int = order.get(str(b.id).get_slice("_", 0), 3)
		if left != right: return left < right
	if a.category == "Air defense" and b.category == "Air defense": return a.get("aa_range", 0.0) < b.get("aa_range", 0.0)
	if a.category == "Air defense" or b.category == "Air defense": return a.category == "Air defense"
	return a.category < b.category if a.category != b.category else a.name < b.name
