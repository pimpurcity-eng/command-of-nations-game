class_name AirOperations
extends RefCounted

const ALTITUDE: = 1.5
const PATROL_RADIUS: = 0.7
const REFUEL_SECONDS: = 1800.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
var _armies_ref: WeakRef
var armies: UnitSystem:
	get: return _armies_ref.get_ref() if _armies_ref != null else null
	set(value): _armies_ref = weakref(value)
var economy: ProductionSystem
func is_air(unit: Dictionary) -> bool:
	return unit.visual_kind == "fighter"
func configure(unit: Dictionary, data: Dictionary) -> void :
	if not is_air(unit): return
	unit.base_city = data.get("base_city", "moscow" if unit.country == "russia" else "kyiv")
	unit.flight_mode = data.get("flight_mode", "grounded")
	unit.flight_used = data.get("flight_used", 0.0)
	unit.refuel_remaining = data.get("refuel_remaining", 0.0)
	unit.patrol_phase = data.get("patrol_phase", 0.0)
	var saved = data.get("patrol_center", [unit.target.x, unit.target.y])
	unit.patrol_center = Vector2(saved[0], saved[1])
	position(unit, Vector2(data.get("position", [unit.node.position.x, unit.node.position.z])[0], data.get("position", [unit.node.position.x, unit.node.position.z])[1]))
func base(unit: Dictionary) -> Dictionary:
	if economy != null:
		for place in economy.cities:
			if place.id == unit.base_city: return place
	for place in GeographicProjection.load_cities():
		if place.id == unit.base_city: return place
	return {}
func available(place: Dictionary, country: String = "") -> bool:
	return not place.is_empty() and economy != null and economy.controlled(place, country) and economy.buildings != null and economy.buildings.level(place.id, "airbase") > 0
func radius(unit: Dictionary) -> float:
	var result: = float(EquipmentIdentity.spec(unit.equipment_id).get("air_range", 14.0))
	for member in armies.stacks.members(unit): result = minf(result, EquipmentIdentity.spec(member.equipment_id).get("air_range", 14.0))
	return result
func budget(unit: Dictionary) -> float:
	return radius(unit) * 3.0
func order(unit: Dictionary, destination: Vector2, mode: String = "fly") -> String:
	if unit.get("upgrade_remaining", 0.0) > 0: return "Modernization in progress"
	if unit.refuel_remaining > 0: return "Aircraft is refueling"
	for member in armies.stacks.members(unit):
		if member.get("refuel_remaining", 0.0) > 0 or member.get("upgrade_remaining", 0.0) > 0: return "A squadron member is refueling or modernizing"
	var place: = base(unit)
	if not available(place, unit.country): return "Recover the home airbase or return to another friendly airbase"
	var extra: = PATROL_RADIUS if mode == "patrol" else 0.0
	if place.point.distance_to(destination) + extra > radius(unit): return "Outside operating range; choose a closer destination or another airbase"
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	if unit.flight_used + point.distance_to(destination) + destination.distance_to(place.point) + 1.0 > budget(unit): return "Insufficient flight endurance; return and refuel"
	if mode not in ["fly", "patrol"]: return "Unknown flight order"
	unit.attack_target = ""
	unit.flight_mode = mode
	unit.patrol_center = destination
	unit.patrol_phase = 0.0
	unit.target = destination
	unit.waypoints = [destination]
	unit.moving = true
	unit.engaged = false
	position(unit, point)
	return ""
func return_home(unit: Dictionary) -> void :
	unit.attack_target = ""
	var place: = base(unit)
	if not available(place, unit.country):
		var nearest: = INF
		if economy != null:
			for candidate in economy.cities:
				if not available(candidate, unit.country): continue
				var distance: float = candidate.point.distance_to(Vector2(unit.node.position.x, unit.node.position.z))
				if distance < nearest:
					nearest = distance
					place = candidate
		if available(place, unit.country): unit.base_city = place.id
	if place.is_empty(): return
	unit.flight_mode = "return"
	unit.target = place.point
	unit.waypoints = [place.point]
	unit.moving = true
func rebase(unit: Dictionary, place: Dictionary) -> String:
	if armies.stacks.members(unit).any( func(member: Dictionary): return member.flight_mode != "grounded" or member.refuel_remaining > 0 or member.get("upgrade_remaining", 0.0) > 0): return "Land, refuel and finish upgrades before rebasing"
	if not available(place, unit.country): return "Choose a controlled friendly airbase"
	if base(unit).point.distance_to(place.point) > radius(unit): return "New airbase is outside operating range"
	unit.base_city = place.id
	unit.flight_mode = "return"
	unit.target = place.point
	unit.waypoints = [place.point]
	unit.moving = true
	return ""
func position(unit: Dictionary, point: Vector2) -> void :
	unit.node.position = armies.terrain.position_at(point) + Vector3.UP * (0.15 if unit.flight_mode == "grounded" else ALTITUDE)
func flight_speed(unit: Dictionary) -> float:
	var result: = INF
	for member in armies.stacks.members(unit): result = minf(result, EquipmentIdentity.spec(member.equipment_id).get("air_speed", 3.0))
	return result * SimulationClock.MOVEMENT_PACE
func advance(unit: Dictionary, seconds: float) -> void :
	unit.engaged = false
	if unit.flight_mode == "grounded":
		if economy != null and not available(base(unit), unit.country):
			unit.health = 0
			return
		unit.refuel_remaining = maxf(0, unit.refuel_remaining - seconds)
		return
	if unit.flight_mode == "attack":
		var target: = armies.find_id(unit.get("attack_target", ""))
		if target.is_empty() or target.health <= 0: return_home(unit)
		elif armies.point_visible(Vector2(target.node.position.x, target.node.position.z), unit.country):
			var destination: = Vector2(target.node.position.x, target.node.position.z)
			if base(unit).point.distance_to(destination) > radius(unit): return_home(unit)
			else: unit.target = destination;unit.waypoints = [destination];unit.moving = true
	var remaining: float = seconds * flight_speed(unit)
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	while remaining > 0 and unit.flight_mode != "grounded":
		var place: = base(unit)
		if unit.flight_mode != "return" and ( not available(place, unit.country) or unit.flight_used + point.distance_to(place.point) + 1.0 >= budget(unit)):
			return_home(unit)
		if unit.waypoints.is_empty(): unit.waypoints = [unit.target]
		var goal: Vector2 = unit.waypoints[0]
		var distance: = point.distance_to(goal)
		var step: = minf(minf(remaining, distance), 0.3)
		point = point.move_toward(goal, step)
		position(unit, point)
		remaining -= step
		unit.flight_used += step
		if unit.flight_used > budget(unit) + 0.001:
			unit.health = 0
			armies.status_changed.emit("Aircraft lost after exhausting its flight endurance")
			break
		if point.distance_to(goal) > 0.001: continue
		unit.waypoints.pop_front()
		if unit.flight_mode == "return":
			if not available(place, unit.country):
				unit.health = 0
				armies.status_changed.emit("Aircraft lost: no friendly airbase available")
				break
			unit.flight_mode = "grounded"
			unit.moving = false
			unit.flight_used = 0.0
			unit.refuel_remaining = REFUEL_SECONDS / economy.buildings.rate(place.id, "airbase")
			armies.status_changed.emit(unit.name + " landed · refueling")
		elif unit.flight_mode == "attack":
			unit.moving = false
			break
		elif unit.flight_mode == "fly":
			return_home(unit)
		else:
			unit.patrol_phase = fmod(unit.patrol_phase + PI / 4, TAU)
			unit.target = unit.patrol_center + Vector2.from_angle(unit.patrol_phase) * PATROL_RADIUS
			unit.waypoints = [unit.target]
	position(unit, point)
	if unit.flight_mode == "grounded": unit.refuel_remaining = maxf(0, unit.refuel_remaining - remaining / flight_speed(unit))
	armies._update_heading(unit)
func snapshot(unit: Dictionary) -> Dictionary:
	return {"base_city": unit.base_city, "flight_mode": unit.flight_mode, "flight_used": unit.flight_used, "refuel_remaining": unit.refuel_remaining, "patrol_center": [unit.patrol_center.x, unit.patrol_center.y], "patrol_phase": unit.patrol_phase}
