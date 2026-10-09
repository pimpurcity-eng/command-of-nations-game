class_name ArmyStacks
extends RefCounted
var armies: UnitSystem
func groups() -> Array:
	var by_id: Dictionary = {}
	for unit in armies.units:
		var key: String = unit.country + ":" + unit.stack_id
		if not by_id.has(key): by_id[key] = []
		by_id[key].append(unit)
	return by_id.values()
func members(unit: Dictionary) -> Array:
	for group in groups():
		if group[0].stack_id == unit.stack_id and group[0].country == unit.country: return group
	return []
func leader(group: Array) -> Dictionary:
	var result: Dictionary = group[0]
	for unit in group:
		if unit.visual_kind == "armor" and result.visual_kind != "armor": result = unit
	return result
func join(a: Dictionary, b: Dictionary) -> bool:
	if a.country != b.country or a.stack_id == b.stack_id: return false
	if armies.air.is_air(a) != armies.air.is_air(b) or armies.is_naval(a) != armies.is_naval(b): return false
	if armies.air.is_air(a) and (a.base_city != b.base_city or a.flight_mode != "grounded" or b.flight_mode != "grounded"): return false
	var first: = members(a)
	var second: = members(b)
	for unit in first + second:
		if unit.engaged or unit.moving or unit.get("upgrade_remaining", 0.0) > 0 or unit.get("refuel_remaining", 0.0) > 0: return false
	var anchor: = Vector2(a.node.position.x, a.node.position.z)
	var source: = Vector2(b.node.position.x, b.node.position.z)
	if anchor.distance_to(source) > 2.0 or not armies.routes_for(a).clear_segment(anchor, source): return false
	for unit in second:
		unit.fire_mode = a.get("fire_mode", "at_will")
		unit.forced_march = false
		unit.delay_remaining = 0.0
		unit.attack_target = ""
		unit.stack_id = a.stack_id
		unit.node.position = a.node.position
		unit.target = anchor
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
	armies.select_unit(armies.units.find(chosen))
	armies.status_changed.emit("One unit detached from the army stack")
func has_stack(id: String, except_unit: Dictionary) -> bool:
	for unit in armies.units:
		if unit.id != except_unit.get("id", "") and unit.stack_id == id: return true
	return false
func summary(unit: Dictionary) -> String:
	var counts: Dictionary = {}
	var health: = 0.0
	var group: = members(unit)
	for member in group:
		var title: = EquipmentIdentity.title(member.equipment_id)
		counts[title] = counts.get(title, 0) + 1
		health += member.health
	var descriptions: PackedStringArray = []
	for title in counts: descriptions.append(str(counts[title]) + "× " + title)
	return str(group.size()) + " units · " + str(int(health)) + "/" + str(group.size() * 100) + " HP · " + ", ".join(descriptions)

func movement_speed(group: Array, point: Variant = null) -> float:
	var speed: = INF
	for unit in group:
		var member_speed: = 1.0 if unit.visual_kind in ["artillery", "missile_launcher"] else (1.6 if unit.visual_kind == "ifv" else (0.9 if unit.visual_kind == "air_defense" else 1.4))
		if unit.visual_kind == "naval": member_speed = EquipmentIdentity.spec(unit.equipment_id).get("sea_speed", 1.2)
		if unit.health < 50: member_speed *= 0.7
		if point != null and unit.visual_kind not in ["fighter", "naval"]: member_speed *= TerrainRules.multiplier(unit.visual_kind, TerrainProfile.sample(point), "speed")
		if unit.get("forced_march", false): member_speed *= 1.5
		speed = minf(speed, member_speed)
	return speed * SimulationClock.MOVEMENT_PACE

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
	armies.select_unit(armies.units.find(leader(detached)))
	return ""
