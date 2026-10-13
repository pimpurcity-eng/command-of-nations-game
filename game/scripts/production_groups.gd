class_name ProductionGroups
extends RefCounted
const TITLES := ["Economy", "Aircraft", "Ordnance", "Tanks", "Naval", "Barracks", "Missiles"]  # Missiles: owner 2026-10-13
const BUILDINGS := ["industry", "airbase", "factory", "tank_plant", "naval_base", "barracks", "missile_factory"]
static func index(spec: Dictionary) -> int:
	if spec.get("category", "") == "Economy": return 0
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
const ICONS := ["support", "fighter", "artillery", "armor", "naval", "infantry", "missile_launcher"]
## City-screen tab order like Call of War: Infantry, Ordnance, Tanks, Missiles, Air, Naval.
const CITY_TABS := [5, 2, 3, 6, 1, 4]
const CITY_TITLES := {5: "Infantry", 2: "Ordnance", 3: "Tanks", 6: "Missiles", 1: "Air", 4: "Naval"}
