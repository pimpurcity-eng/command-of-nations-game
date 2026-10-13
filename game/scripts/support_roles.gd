class_name SupportRoles
extends RefCounted
## What the support units do (owner 2026-10-13: "engineers, bridge layers need a category and
## building ... add medic to heal troops on battle"). Rates are per game hour; one game hour is
## HOUR elapsed clock units (the clock runs in 2-minute units, real time at 1x).
##  * Field medics: heal every unit in their army, also during battle (infantry fastest).
##  * Recovery vehicles: repair the vehicles in their army.
##  * Supply trucks: slowly restore the whole army and remove forced-march wear.
##  * Combat engineers: the army digs in anywhere, twice as fast.
##  * Bridge layers: the army crosses rivers and rough ground faster (+25% speed).
##  * Hospitals (city or province, 5 levels): +2 health per hour per level to your armies there.
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const MEDIC_PER_LEVEL: = 2.0
const RECOVERY_PER_LEVEL: = 2.0
const SUPPLY_PER_LEVEL: = 0.6
const HOSPITAL_PER_LEVEL: = 2.0
const HOSPITAL_RADIUS: = 1.3
const BRIDGE_SPEED: = 1.25
const VEHICLES: = ["armor", "ifv", "artillery", "air_defense", "missile_launcher", "support"]

static func role(unit: Dictionary) -> String:
	return str(EquipmentIdentity.spec(str(unit.get("equipment_id", ""))).get("role", ""))

## Highest level of a support role in the army (0 when absent).
static func level_in(group: Array, wanted: String) -> int:
	var best: = 0
	for unit in group:
		if unit.get("health", 0.0) > 0 and role(unit) == wanted: best = maxi(best, int(unit.get("level", 1)))
	return best

static func speed_factor(group: Array) -> float:
	return BRIDGE_SPEED if level_in(group, "bridge") > 0 else 1.0

static func entrench_factor(group: Array) -> float:
	return 2.0 if level_in(group, "engineer") > 0 else 1.0

static func prevents_march_wear(group: Array) -> bool:
	return level_in(group, "supply") > 0

## Healing from medics, recovery vehicles, supply trucks and hospitals.
static func heal(armies: UnitSystem, buildings: BuildingSystem, seconds: float) -> void:
	if seconds <= 0 or armies == null: return
	var hours: float = seconds / HOUR
	var hospitals: Array = []  # [point, level, country]
	if buildings != null:
		for place in buildings.economy.cities:
			var level: int = buildings.level(place.id, "hospital")
			if level > 0: hospitals.append([place.point, level, buildings.economy.controller(place)])
		for id in buildings.provinces.levels:
			var level: int = buildings.provinces.level(id, "hospital")
			if level <= 0: continue
			var place: Dictionary = buildings.provinces.place(id)
			if not place.is_empty(): hospitals.append([place.point, level, buildings.economy.controller(place)])
	for group in armies.stacks.groups():
		var medic: = level_in(group, "medic")
		var recovery: = level_in(group, "recovery")
		var resting: bool = not group[0].get("moving", false)
		var supply: = level_in(group, "supply") if resting else 0
		for unit in group:
			if unit.health <= 0 or unit.health >= 100.0: continue
			var rate: = 0.0
			if medic > 0: rate += MEDIC_PER_LEVEL * medic * (1.5 if unit.visual_kind == "infantry" else 1.0)
			if recovery > 0 and unit.visual_kind in VEHICLES and not unit.get("engaged", false): rate += RECOVERY_PER_LEVEL * recovery
			rate += SUPPLY_PER_LEVEL * supply
			if unit.visual_kind not in ["fighter", "naval"] and not hospitals.is_empty():
				var at: = Vector2(unit.node.position.x, unit.node.position.z)
				var best: = 0
				for h in hospitals:
					if h[2] == unit.country and at.distance_to(h[0]) <= HOSPITAL_RADIUS: best = maxi(best, h[1])
				rate += HOSPITAL_PER_LEVEL * best
			if rate > 0: unit.health = minf(100.0, unit.health + rate * hours)
