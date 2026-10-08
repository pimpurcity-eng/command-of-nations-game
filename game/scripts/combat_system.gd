class_name CombatSystem
extends RefCounted
signal weapon_fired(source: Dictionary, target_unit: Dictionary, effect: String)

const ROUND_SECONDS: = 1800.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const STACK_DAMAGE_LIMIT: = 10
const MAX_ROUND_SECONDS: = ROUND_SECONDS * 4
var cooldowns: Dictionary = {}
func key(group: Array) -> String:
	return group[0].country + ":" + group[0].stack_id
func alive(group: Array) -> Array:
	return group.filter( func(unit: Dictionary): return unit.health > 0)
func damage_value(unit: Dictionary, target_kind: String, defending: bool = false) -> float:

	var values: = {"armor": {"armor": 7.0, "ifv": 8.0, "artillery": 6.0, "air_defense": 8.0}, "ifv": {"armor": 4.0, "ifv": 6.0, "artillery": 7.0, "air_defense": 7.0}, "artillery": {"armor": 5.0, "ifv": 7.0, "artillery": 5.0, "air_defense": 6.0}, "air_defense": {"armor": 1.0, "ifv": 2.0, "artillery": 1.0, "air_defense": 2.0}}
	if unit.visual_kind == "missile_launcher":
		return (2.0 if defending else 22.0) * (0.2 + 0.8 * clampf(unit.health / 100.0, 0, 1)) * (1.0 + 0.12 * (unit.get("level", 1) - 1))
	if unit.visual_kind == "naval":
		return (6.0 if target_kind == "naval" else 0.0) * (0.2 + 0.8 * clampf(unit.health / 100.0, 0, 1)) * (1.0 + 0.12 * (unit.get("level", 1) - 1))
	if defending:
		values = {"armor": {"armor": 6.0, "ifv": 7.0, "artillery": 5.0, "air_defense": 7.0}, "ifv": {"armor": 5.0, "ifv": 7.0, "artillery": 6.0, "air_defense": 6.0}, "artillery": {"armor": 2.0, "ifv": 3.0, "artillery": 2.0, "air_defense": 3.0}, "air_defense": {"armor": 2.0, "ifv": 3.0, "artillery": 2.0, "air_defense": 3.0}}
	for role in values: values[role]["missile_launcher"] = values[role].get("artillery", 3.0)
	return values.get(unit.visual_kind, {}).get(target_kind, 0.0) * (0.2 + 0.8 * clampf(unit.health / 100.0, 0, 1)) * (1.0 + 0.12 * (unit.get("level", 1) - 1))
func ranged_ready(unit: Dictionary) -> bool:
	return not unit.get("moving", false) or unit.get("fire_mode", "at_will") in ["offensive", "aggressive"] or not unit.get("attack_target", "").is_empty()
func attack_reach(unit: Dictionary) -> float:
	if unit.get("upgrade_remaining", 0.0) > 0: return 0.0
	if ranged_ready(unit):
		if unit.visual_kind == "naval": return EquipmentIdentity.spec(unit.equipment_id).get("sea_range", 2.8)
		if unit.visual_kind == "artillery": return 2.4
		if unit.visual_kind == "missile_launcher": return EquipmentIdentity.spec(unit.equipment_id).get("strike_range", 8.0)
	return 1.1 if unit.get("moving", false) else 0.0
func eligible(group: Array, distance: float) -> Array:
	return group.filter( func(unit: Dictionary): return unit.health > 0 and attack_reach(unit) > 0 and attack_reach(unit) + 1e-06 >= distance)
func potential(group: Array, target_kind: String, ranged: bool = false, defending: bool = false) -> float:
	var contributions: Array[float] = []
	for unit in group:
		if unit.health <= 0 or (ranged and (unit.visual_kind not in ["artillery", "missile_launcher", "naval"] or not ranged_ready(unit))): continue
		if not defending and unit.get("upgrade_remaining", 0.0) > 0: continue
		contributions.append(damage_value(unit, target_kind, defending) * TerrainRules.unit_factor(unit, "defense" if defending else "attack"))
	contributions.sort()
	contributions.reverse()
	var total: = 0.0
	for i in mini(STACK_DAMAGE_LIMIT, contributions.size()): total += contributions[i]
	return total
func target(group: Array, groups: Array, armies: UnitSystem = null) -> Array:
	if group[0].visual_kind == "fighter": return []
	if group.all( func(unit: Dictionary): return unit.get("upgrade_remaining", 0.0) > 0): return []
	var origin: = Vector2(group[0].node.position.x, group[0].node.position.z)
	var nearest: = INF
	var result: Array = []
	for candidate in groups:
		if candidate[0].visual_kind == "fighter" or (candidate[0].visual_kind == "naval") != (group[0].visual_kind == "naval"): continue
		var defenders: = alive(candidate)
		if defenders.is_empty() or defenders[0].country == group[0].country: continue
		var point: = Vector2(defenders[0].node.position.x, defenders[0].node.position.z)
		var distance: = origin.distance_to(point)
		if armies != null and not armies.point_visible(point, group[0].country): continue
		var explicit: bool = group[0].get("attack_target", "") in defenders.map( func(unit: Dictionary): return unit.id)
		if group[0].get("fire_mode", "at_will") in ["return", "hold"] and not explicit: continue
		var priority: = 0.0 if explicit else distance
		if not eligible(group, distance).is_empty() and priority < nearest:
			nearest = priority
			result = defenders
	return result
func advance(seconds: float, armies: UnitSystem, pending: Dictionary = {}, resolve_now: bool = false) -> void :
	if not is_finite(seconds) or seconds < 0 or (seconds == 0 and not resolve_now) or not armies.at_war: return
	var groups: = armies.stacks.groups()
	var existing: Dictionary = {}
	for group in groups:
		existing[key(group)] = true
		if not cooldowns.has(key(group)): cooldowns[key(group)] = 0.0
	for id in cooldowns.keys():
		if not existing.has(id): cooldowns.erase(id)
	var remaining: = seconds
	var first: = resolve_now
	while remaining > 0 or first:
		first = false
		var attacks: Array = []
		var wait: = INF
		for group in groups:
			var living: = alive(group)
			if living.is_empty(): continue
			var defenders: = target(living, groups, armies)
			if defenders.is_empty(): continue
			attacks.append([living, defenders, key(group)])
			wait = minf(wait, cooldowns[key(group)])
		if attacks.is_empty():
			for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - remaining)
			break
		var step: = minf(remaining, maxf(0, wait))
		for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - step)
		remaining -= step
		if wait > step: break

		var damage: Dictionary = {}
		for attack in attacks:
			if cooldowns[attack[2]] > 1e-06: continue
			var attackers: Array = attack[0]
			var defenders: Array = attack[1]
			var a: = Vector2(attackers[0].node.position.x, attackers[0].node.position.z)
			var b: = Vector2(defenders[0].node.position.x, defenders[0].node.position.z)
			var distance: = a.distance_to(b)
			var ranged: = distance > 1.1
			var contributors: = eligible(attackers, distance)
			for defender in defenders:
				var strike: = potential(contributors, defender.visual_kind, ranged) / defenders.size()
				damage[defender.id] = damage.get(defender.id, 0.0) + strike
			if not ranged and defenders[0].get("fire_mode", "at_will") != "hold":


				for attacker in attackers:
					var response: = potential(defenders, attacker.visual_kind, false, true) / attackers.size()
					damage[attacker.id] = damage.get(attacker.id, 0.0) + response
			if ranged and defenders[0].get("fire_mode", "at_will") == "return" and cooldowns.get(key(defenders), 0.0) <= 1e-06:
				var answering: = eligible(defenders, distance)
				if not answering.is_empty():
					for attacker in attackers:
						damage[attacker.id] = damage.get(attacker.id, 0.0) + potential(answering, attacker.visual_kind, true) / attackers.size()
					cooldowns[key(defenders)] = ROUND_SECONDS
					for defender in answering: weapon_fired.emit(defender, attackers[0], "artillery")
			var rounds: = 1.0
			for attacker in contributors:
				if attacker.visual_kind in ["artillery", "missile_launcher", "naval"] and ranged_ready(attacker):
					weapon_fired.emit(attacker, defenders[0], "missile" if attacker.visual_kind == "missile_launcher" else "artillery")
				if attacker.visual_kind == "missile_launcher": rounds = maxf(rounds, EquipmentIdentity.spec(attacker.equipment_id).get("reload_rounds", 4.0))
			cooldowns[attack[2]] = ROUND_SECONDS * rounds
		if resolve_now:
			for id in damage: pending[id] = pending.get(id, 0.0) + damage[id]
		else:
			for unit in armies.units: unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0))
func remaining_for(unit: Dictionary) -> float:
	return cooldowns.get(unit.country + ":" + unit.stack_id, 0.0)
func snapshot() -> Dictionary:
	return cooldowns.duplicate()
func restore(state: Dictionary) -> void :
	cooldowns = state.duplicate()
