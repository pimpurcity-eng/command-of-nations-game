class_name ArmyStacks
extends RefCounted
var armies: UnitSystem
var _groups: Dictionary = {}
var _frame: int = -1
var _count: int = -1
func invalidate() -> void:
	_frame = -1
func groups() -> Array:
	if _frame != Engine.get_process_frames() or _count != armies.units.size():
		_groups.clear()
		for unit in armies.units:
			var key: String = unit.country + ":" + unit.stack_id
			if not _groups.has(key): _groups[key] = []
			_groups[key].append(unit)
		_frame = Engine.get_process_frames()
		_count = armies.units.size()
	return _groups.values()
func members(unit: Dictionary) -> Array:
	groups()
	return _groups.get(unit.country + ":" + unit.stack_id, [])
## The strongest unit leads the army and is the model shown on the map (owner 2026-10-13:
## "the strongest unit goes on top"). Rated at full health so the leader does not flip as
## units take damage.
static var _rating: Dictionary = {}
## How strong a unit type is for picking the stack leader (owner: "strongest unit goes on top").
## Its own attack plus defence against every target type at full health, without terrain,
## so urban defence bonuses do not put infantry above tanks.
static func rating(unit: Dictionary) -> float:
	var key: String = str(unit.get("equipment_id", "")) + ":" + str(int(unit.get("level", 1))) + ":" + str(unit.get("country", "")) + ":" + str(EquipmentIdentity.upgrade_factor(unit))
	if not _rating.has(key):
		var fresh: Dictionary = unit.duplicate()
		fresh.health = 100.0
		var combat: = CombatSystem.new()
		var total: = 0.0
		for target in UnitClasses.ALL:
			total += combat.damage_value(fresh, target, false) + combat.damage_value(fresh, target, true)
		_rating[key] = total
	return _rating[key]
func leader(group: Array) -> Dictionary:
	var result: Dictionary = group[0]
	var best: = rating(result)
	for unit in group:
		var value: = rating(unit)
		if value > best + 0.001:
			best = value
			result = unit
	return result
## in_battle: owner 2026-10-15 ("when they're fighting and more units come, they should join") -
## an army that reaches a friendly army already fighting there joins its stack mid-battle.
func join(a: Dictionary, b: Dictionary, in_battle: bool = false) -> bool:
	if a.country != b.country or a.stack_id == b.stack_id: return false
	if armies.air.is_air(a) != armies.air.is_air(b) or armies.is_naval(a) != armies.is_naval(b): return false
	if armies.air.is_air(a) and (a.base_city != b.base_city or a.flight_mode != "grounded" or b.flight_mode != "grounded"): return false
	var first: = members(a)
	var second: = members(b)
	for unit in first + second:
		if (unit.engaged and not in_battle) or (unit.moving and not (in_battle and unit.engaged)) or unit.get("upgrade_remaining", 0.0) > 0 or unit.get("refuel_remaining", 0.0) > 0: return false
	var anchor: = Vector2(a.node.position.x, a.node.position.z)
	var source: = Vector2(b.node.position.x, b.node.position.z)
	if anchor.distance_to(source) > 2.0 or not armies.routes_for(a).clear_segment(anchor, source): return false
	for unit in second:
		unit.fire_mode = a.get("fire_mode", "at_will")
		unit.forced_march = false
		unit.delay_remaining = 0.0
		unit.attack_target = str(a.get("attack_target", "")) if in_battle else ""
		if in_battle:
			unit.moving = a.moving
			unit.waypoints = a.waypoints.duplicate()
		unit.stack_id = a.stack_id
		unit.node.position = a.node.position
		unit.target = a.target if in_battle else anchor
	invalidate()
	return true
func merge_near_selected() -> void :
	if armies.selected < 0: return
	var chosen: Dictionary = armies.units[armies.selected]
	var merged: = false
	for group in groups():
		if join(chosen, group[0]): merged = true
	armies.select_unit(armies.units.find(chosen))
	armies.status_changed.emit("Friendly armies combined" if merged else "Move friendly armies closer and stop them before merging")
func split_selected() -> void :
	if armies.selected < 0: return
	var chosen: Dictionary = armies.units[armies.selected]
	var group: = members(chosen)
	if group.size() < 2: return
	for unit in group:
		if unit.engaged or unit.moving or unit.get("upgrade_remaining", 0.0) > 0:
			armies.status_changed.emit("Stop the stack and leave combat before splitting")
			return
	var detached: Dictionary = group[-1]
	var anchor: = Vector2(chosen.node.position.x, chosen.node.position.z)
	var destination: = anchor
	var found: = false
	if not armies.is_naval(chosen):
		# Ground armies split along the road (owner review: units only on roads).
		destination = armies.navigation.beside_on_road(anchor, 0.55, armies.ground_positions(group), chosen.country)
		found = destination.distance_to(anchor) > 0.2
	else:
		for angle in 16:
			var point: = anchor + Vector2.from_angle(angle * TAU / 16.0) * 0.55
			if armies.routes_for(chosen).clear_segment(anchor, point):
				destination = point
				found = true
				break
	if not found:
		armies.status_changed.emit("No nearby navigable space to split this stack")
		return
	detached.stack_id = detached.id + "_split"
	while has_stack(detached.stack_id, detached): detached.stack_id += "_split"
	detached.node.position = armies.surface_position(detached, destination)
	detached.target = destination
	invalidate()
	armies.select_unit(armies.units.find(chosen))
	armies.status_changed.emit("One unit detached from the army stack")
func has_stack(id: String, except_unit: Dictionary) -> bool:
	for unit in armies.units:
		if unit.id != except_unit.get("id", "") and unit.stack_id == id: return true
	return false
func summary(unit: Dictionary) -> String:
	var counts: Dictionary = {}
	var group: = members(unit)
	for member in group:
		var title: = EquipmentIdentity.title(member.equipment_id)
		counts[title] = counts.get(title, 0) + 1
	var descriptions: PackedStringArray = []
	for title in counts: descriptions.append(str(counts[title]) + "× " + title)
	var hp: = UnitStats.group_hp(group)
	return str(group.size()) + " units · " + UnitStats.number(hp.x) + "/" + str(roundi(hp.y)) + " HP · " + ", ".join(descriptions)

func movement_speed(group: Array, point: Variant = null) -> float:
	var speed: = INF
	for unit in group:
		var member_speed: = UnitStats.speed(unit)
		if unit.health < 50: member_speed *= 0.7
		if point != null and unit.visual_kind not in ["fighter", "naval"]: member_speed *= TerrainRules.for_unit(unit, TerrainProfile.sample(point), "speed")
		if unit.get("forced_march", false): member_speed *= 1.5
		speed = minf(speed, member_speed)
	if point != null and armies.air.economy != null and armies.air.economy.buildings != null and not group.is_empty():
		speed *= armies.air.economy.buildings.provinces.movement_factor(point, group[0].country)
	# Rail transport (owner 2026-10-13): twice as fast through friendly provinces with a train station.
	if point != null and TradeNetwork.active != null and not group.is_empty() and group.all(func(u: Dictionary): return u.visual_kind not in ["fighter", "naval"]):
		speed *= TradeNetwork.active.rail_factor(point, group[0].country)
	if not group.is_empty() and group.all(func(u: Dictionary): return u.visual_kind not in ["fighter", "naval"]):
		speed *= SupportRoles.speed_factor(group)
		# Owner 2026-10-16: own/allied land is faster, enemy land slower; land armies march at LAND_PACE.
		if point != null: speed *= TerrainRules.territory_speed(str(group[0].country), land_owner(point), armies.diplomacy)
		return speed * SimulationClock.LAND_PACE
	return speed * SimulationClock.MOVEMENT_PACE

## Map units per simulation second as game km per game hour (1 map unit = 40 game km,
## 1 game hour = 30 simulation seconds).
static func km_per_hour(speed: float) -> float:
	return speed * 40.0 * 86400.0 / 24.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND

## Who controls the land at `point` (cached on a 0.05 grid until provinces change hands).
var _owner_memo: Dictionary = {}
var _owner_revision: = -1
func land_owner(point: Vector2) -> String:
	if armies.navigation == null or armies.navigation.terrain == null: return ""
	if _owner_revision != armies.terrain_revision or _owner_memo.size() > 50000:
		_owner_memo.clear()
		_owner_revision = armies.terrain_revision
	var key: = Vector2i(roundi(point.x * 20.0), roundi(point.y * 20.0))
	if not _owner_memo.has(key): _owner_memo[key] = armies.navigation.controller_at(point)
	return _owner_memo[key]

## The parts of the march speed at `point` for the army panel: [label, factor] pairs.
func speed_factors(group: Array, point: Vector2) -> Array:
	var result: Array = []
	if group.is_empty() or group.any(func(u: Dictionary): return u.visual_kind in ["fighter", "naval"]): return result
	var terrain_name: = TerrainProfile.sample(point)
	var slowest: = INF
	for unit in group: slowest = minf(slowest, TerrainRules.for_unit(unit, terrain_name, "speed"))
	result.append([terrain_name, slowest])
	result.append(["territory", TerrainRules.territory_speed(str(group[0].country), land_owner(point), armies.diplomacy)])
	if armies.air.economy != null and armies.air.economy.buildings != null:
		result.append(["roads", armies.air.economy.buildings.provinces.movement_factor(point, group[0].country)])
	if TradeNetwork.active != null: result.append(["railway", TradeNetwork.active.rail_factor(point, group[0].country)])
	if group.any(func(u: Dictionary): return u.get("forced_march", false)): result.append(["forced march", 1.5])
	return result

func split_units(ids: Array[String]) -> String:
	if armies.selected < 0: return "Select an army first"
	var chosen: Dictionary = armies.units[armies.selected]
	if chosen.country != GameSession.player_country: return "Choose your own army"
	var group: = members(chosen)
	var detached: Array = []
	for unit in group:
		if unit.id in ids: detached.append(unit)
	if detached.is_empty() or detached.size() >= group.size(): return "Select some units and leave at least one in the original army"
	if group.any( func(unit: Dictionary): return unit.engaged or unit.get("upgrade_remaining", 0.0) > 0 or unit.get("refuel_remaining", 0.0) > 0): return "Leave combat and finish refueling or upgrades before splitting"
	var anchor: = Vector2(chosen.node.position.x, chosen.node.position.z)
	var point: = anchor
	if not armies.air.is_air(chosen):
		var found: = false
		if not armies.is_naval(chosen):
			point = armies.navigation.beside_on_road(anchor, 0.55, armies.ground_positions(group), chosen.country)
			found = point.distance_to(anchor) > 0.2
		else:
			for angle in 16:
				var candidate: = anchor + Vector2.from_angle(angle * TAU / 16.0) * 0.55
				if armies.routes_for(chosen).clear_segment(anchor, candidate): point = candidate;found = true;break
		if not found: return "No navigable space beside this army"
	else:
		if chosen.flight_mode != "grounded": return "Land aircraft before splitting the squadron"
	var id: String = detached[0].id + "_split"
	while has_stack(id, {}): id += "_split"
	for unit in detached:
		unit.stack_id = id
		unit.moving = false
		unit.waypoints.clear()
		unit.target = point
		unit.attack_target = ""
		unit.firing_halt = false
		unit.delay_remaining = 0.0
		unit.forced_march = false
		unit.node.position = armies.surface_position(unit, point)
		if armies.air.is_air(unit): armies.air.position(unit, point)
	invalidate()
	armies.select_unit(armies.units.find(leader(detached)))
	return ""
