class_name AirBattleSystem
extends RefCounted
signal weapon_fired(source: Dictionary, target_unit: Dictionary, effect: String)
const ROUND_SECONDS: = CombatSystem.ROUND_SECONDS
## Owner 2026-10-13: air defence fires a missile every 7 minutes at 1x speed. Aircraft only
## passing through take half damage; aircraft attacking or patrolling inside the range take
## full damage.
const AA_INTERVAL: = 7.0 * 60.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const AA_PASSING_FACTOR: = 0.5
## Owner 2026-10-15 ("the plane patrolling over top of them should be doing damage"): a patrol hits
## enemy armies anywhere under its circle, a whole town included, not only right under its centre.
const PATROL_STRIKE_REACH: = 1.25
## Owner 2026-10-15: "Patrols do 65% damage".
const PATROL_DAMAGE: = 0.65
## Layered air defence (owner 2026-10-14): long-range SAMs (Patriot / S-300 / S-400 family) track only
## big targets - jets, bombers, radar and transport planes, helicopters - and cannot see small drones,
## so drones can hit them unopposed at any level. Short-range air defence (Skyguard / Tor / Pantsir
## family) shoots down drones, helicopters and jets diving in on an attack run, but cannot reach
## high-flying bombers, radar or transport planes, or jets just passing over. Ships cover every layer.
## A family can override this with an "engages" list in equipment.json: drone, low, attack, high.
const SHORT_RANGE_LAYERS: = ["drone", "low", "attack"]
const LONG_RANGE_LAYERS: = ["low", "attack", "high"]
static func air_layer(aircraft: Dictionary) -> String:
	var role: = str(EquipmentIdentity.spec(aircraft.equipment_id).get("role", ""))
	if role == "drone": return "drone"
	if role == "helicopter": return "low"
	if role in ["fighter", ""] and aircraft.get("flight_mode", "") == "attack": return "attack"
	return "high"
static func engages(defender: Dictionary) -> Array:
	var spec: Dictionary = EquipmentIdentity.spec(defender.equipment_id)
	if spec.get("engages") is Array: return spec.engages
	if defender.visual_kind == "naval": return ["drone", "low", "attack", "high"]
	return LONG_RANGE_LAYERS if str(defender.equipment_id).begins_with("patriot") else SHORT_RANGE_LAYERS
static func can_engage(defender: Dictionary, aircraft: Dictionary) -> bool:
	return air_layer(aircraft) in engages(defender)
static func aa_factor(aircraft: Dictionary) -> float:
	return 1.0 if aircraft.get("flight_mode", "") in ["attack", "patrol"] else AA_PASSING_FACTOR
var cooldowns: Dictionary = {}
func value(unit: Dictionary, name: String, defending: bool = false) -> float:
	var target: = "air" if name in ["air_damage", "aa_damage"] else "infantry"
	return UnitStats.damage(unit, target, defending) * TerrainRules.unit_factor(unit, "defense" if defending else "attack")
func strike_value(unit: Dictionary, target: Dictionary, defending: bool = false) -> float:
	return UnitStats.damage(unit, UnitClasses.of(target), defending) * TerrainRules.unit_factor(unit, "defense" if defending else "attack")
func can_defend_air(defender: Dictionary, aircraft: Dictionary) -> bool:
	return (defender.visual_kind in ["air_defense", "naval"] and can_engage(defender, aircraft)) or (defender.visual_kind == "fighter" and defender.get("flight_mode", "grounded") != "grounded")
func contributes(unit: Dictionary, target: Dictionary, armies: UnitSystem) -> bool:
	var group: Array = armies.stacks.members(unit).filter(func(member: Dictionary):
		return member.health > 0 and member.get("upgrade_remaining", 0.0) <= 0 and strike_value(member, target) > 0 and ((member.visual_kind in ["air_defense", "naval"] and can_engage(member, target)) or (member.visual_kind == "fighter" and member.get("flight_mode", "grounded") != "grounded")))
	if group.size() <= CombatSystem.STACK_DAMAGE_LIMIT: return true
	group.sort_custom(func(a: Dictionary, b: Dictionary):
		var first: = strike_value(a, target)
		var second: = strike_value(b, target)
		return str(a.id) < str(b.id) if is_equal_approx(first, second) else first > second)
	return unit in group.slice(0, CombatSystem.STACK_DAMAGE_LIMIT)
func advance(seconds: float, armies: UnitSystem, pending: Dictionary = {}, resolve_now: bool = false) -> void :
	if not is_finite(seconds) or seconds < 0 or (seconds == 0 and not resolve_now) or not armies.at_war: return
	var remaining: = seconds
	var existing: Dictionary = {}
	for unit in armies.units: existing[unit.id] = true
	for id in cooldowns.keys():
		if not existing.has(id): cooldowns.erase(id)
	var first: = resolve_now
	while remaining > 0 or first:
		first = false
		var strikes: Array = []
		var wait: = INF
		for unit in armies.units:
			if unit.health <= 0 or unit.get("upgrade_remaining", 0.0) > 0: continue
			var fighter: bool = unit.visual_kind == "fighter" and unit.get("flight_mode", "grounded") != "grounded"
			var aa: bool = unit.visual_kind == "air_defense" or (unit.visual_kind == "naval" and value(unit,"aa_damage")>0)
			if not fighter and not aa: continue
			var patrol: bool = fighter and unit.flight_mode == "patrol"
			var reach: float = PATROL_STRIKE_REACH if patrol else 1.2 if fighter else float(EquipmentIdentity.spec(unit.equipment_id).get("aa_range",2.5)) if unit.visual_kind == "naval" else EquipmentIdentity.air_defense_range(unit)
			var origin: Vector2 = unit.patrol_center if patrol else Vector2(unit.node.position.x, unit.node.position.z)
			var nearest: = INF
			var patrol_targets: Array = []
			var target: Dictionary = {}
			for enemy in armies.units:
				if enemy.health <= 0 or enemy.country == unit.country: continue
				if not MapDefinition.is_regional() and armies.diplomacy != null and not armies.diplomacy.at_war(unit.country,enemy.country): continue
				if aa and (enemy.visual_kind != "fighter" or enemy.flight_mode == "grounded"): continue
				if aa and not can_engage(unit, enemy): continue
				var point: = Vector2(enemy.node.position.x, enemy.node.position.z)
				if origin.distance_squared_to(point) > reach * reach: continue
				if not armies.unit_visible(enemy, unit.country): continue
				if unit.get("flight_mode", "") == "attack" and enemy.id != unit.get("attack_target", ""): continue
				if fighter and strike_value(unit, enemy) <= 0: continue
				if not contributes(unit, enemy, armies): continue
				var distance: = origin.distance_to(point)
				if patrol and distance <= reach and Vector2(unit.node.position.x, unit.node.position.z).distance_to(unit.patrol_center) <= AirOperations.PATROL_RADIUS + 0.05:
					# One strike per army, with its HP damage shared by the stack, not multiplied by unit count.
					if not patrol_targets.any(func(other: Dictionary): return other.country == enemy.country and other.stack_id == enemy.stack_id): patrol_targets.append(enemy)
				if distance <= reach and distance < nearest:
					nearest = distance
					target = enemy
			if target.is_empty() or (patrol and patrol_targets.is_empty()): continue
			if not cooldowns.has(unit.id): cooldowns[unit.id] = 0.0
			if patrol and not EquipmentIdentity.spec(unit.equipment_id).get("single_use", false):
				for enemy in patrol_targets: strikes.append([unit, enemy, aa])
			else: strikes.append([unit, target, aa])
			wait = minf(wait, cooldowns[unit.id])
		if strikes.is_empty():
			for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - remaining)
			break
		var step: = minf(remaining, maxf(0, wait))
		for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - step)
		remaining -= step
		if wait > step: break
		var ready: Dictionary = {}
		for strike in strikes:
			if cooldowns.get(strike[0].id, 0.0) <= 1e-06: ready[strike[0].id] = true
		var damage: Dictionary = {}
		var answered: Dictionary = {}
		for strike in strikes:
			var unit: Dictionary = strike[0]
			var enemy: Dictionary = strike[1]
			if not ready.has(unit.id): continue
			var victims: Array = [enemy] if strike[2] else armies.stacks.members(enemy).filter(func(v: Dictionary): return v.health > 0)
			var mission: float = aa_factor(enemy) if strike[2] else (PATROL_DAMAGE if unit.get("flight_mode", "") == "patrol" else 1.0)
			for victim in victims:
				var hit: = strike_value(unit, victim) * mission / maxf(1.0, victims.size())
				damage[victim.id] = damage.get(victim.id, 0.0) + UnitStats.condition_damage(victim, hit)
			var missile_loadout: bool = EquipmentIdentity.research_tier(unit.equipment_id, unit.get("level", 1)).has("projectile_model")
			weapon_fired.emit(unit, enemy, "interceptor" if strike[2] else "missile" if missile_loadout else "drone_strike" if EquipmentIdentity.spec(unit.equipment_id).get("role", "") == "drone" else "air_strike")
			if not strike[2] and EquipmentIdentity.spec(unit.equipment_id).get("single_use", false): damage[unit.id] = damage.get(unit.id, 0.0) + unit.health
			if not strike[2]:
				# One defensive volley per squadron/target-stack event. Split it across the
				# attacking aircraft instead of returning the entire stack's fire to each plane.
				var reply_key: String = unit.country + ":" + unit.stack_id + ":" + enemy.country + ":" + enemy.stack_id
				if not answered.has(reply_key):
					answered[reply_key] = true
					var incoming: Dictionary = {}
					for other in strikes:
						if ready.has(other[0].id) and other[0].country == unit.country and other[0].stack_id == unit.stack_id and other[1].country == enemy.country and other[1].stack_id == enemy.stack_id: incoming[other[0].id] = other[0]
					var defenders: Array = armies.stacks.members(enemy).filter(func(d: Dictionary): return d.health > 0 and value(d, "aa_damage", true) > 0 and incoming.values().any(func(a: Dictionary): return can_defend_air(d, a)))
					defenders.sort_custom(func(a: Dictionary, b: Dictionary): return value(a, "aa_damage", true) > value(b, "aa_damage", true))
					for defender in defenders.slice(0, CombatSystem.STACK_DAMAGE_LIMIT):
						var targets: Array = incoming.values().filter(func(a: Dictionary): return can_defend_air(defender, a))
						for aircraft in targets: damage[aircraft.id] = damage.get(aircraft.id, 0.0) + UnitStats.condition_damage(aircraft, value(defender, "aa_damage", true) / maxf(1.0, targets.size()))
						weapon_fired.emit(defender, targets[0], "interceptor")

			# Owner 2026-10-13: patrolling aircraft also strike every 7 minutes (PATROL_DAMAGE, above);
			# an attack order hits at full damage and then the aircraft returns to land.
			cooldowns[unit.id] = AA_INTERVAL if strike[2] or unit.get("flight_mode", "") == "patrol" else ROUND_SECONDS
			if unit.get("flight_mode", "") == "attack":
				# Owner 2026-10-15: after a strike the aircraft lands, refuels and goes back to hit
				# the same target by itself, until it is given another order.
				for member in armies.stacks.members(unit): member.repeat_target = enemy.id
				armies.air.return_home(unit)
		if resolve_now:
			for id in damage: pending[id] = pending.get(id, 0.0) + damage[id]
		else:
			for unit in armies.units: unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0))
func snapshot() -> Dictionary:
	return cooldowns.duplicate()
func restore(state: Dictionary) -> void :
	cooldowns = state.duplicate()
