class_name AirBattleSystem
extends RefCounted
signal weapon_fired(source: Dictionary, target_unit: Dictionary, effect: String)
const ROUND_SECONDS: = CombatSystem.ROUND_SECONDS
## Owner 2026-10-13: air defence fires a missile every 7 minutes at 1x speed. Aircraft only
## passing through take half damage; aircraft attacking or patrolling inside the range take
## full damage.
const AA_INTERVAL: = 7.0 * 60.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const AA_PASSING_FACTOR: = 0.5
static func aa_factor(aircraft: Dictionary) -> float:
	return 1.0 if aircraft.get("flight_mode", "") in ["attack", "patrol"] else AA_PASSING_FACTOR
var cooldowns: Dictionary = {}
func value(unit: Dictionary, name: String, defending: bool = false) -> float:
	var base: float = EquipmentIdentity.spec(unit.equipment_id).get(name, 0.0)
	var scaling: float = 1.0 + 0.12 * (unit.get("level", 1) - 1)
	var tier: Dictionary = EquipmentIdentity.research_tier(unit.equipment_id, unit.get("level", 1))
	base = float(tier.get(name, base))
	if name == "aa_damage" and tier.has("damage"):
		base = tier.damage
		scaling = 1.0
	return TerrainRules.unit_factor(unit, "defense" if defending else "attack") * base * (0.2 + 0.8 * clampf(unit.health / 100.0, 0, 1)) * scaling * EquipmentIdentity.upgrade_factor(unit)
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
			var reach: float = AirOperations.PATROL_RADIUS if patrol else 1.2 if fighter else float(EquipmentIdentity.spec(unit.equipment_id).get("aa_range",2.5)) if unit.visual_kind == "naval" else EquipmentIdentity.air_defense_range(unit)
			var origin: Vector2 = unit.patrol_center if patrol else Vector2(unit.node.position.x, unit.node.position.z)
			var nearest: = INF
			var patrol_targets: Array = []
			var target: Dictionary = {}
			for enemy in armies.units:
				if enemy.health <= 0 or enemy.country == unit.country: continue
				if aa and (enemy.visual_kind != "fighter" or enemy.flight_mode == "grounded"): continue
				var point: = Vector2(enemy.node.position.x, enemy.node.position.z)
				if origin.distance_squared_to(point) > reach * reach: continue
				if not armies.unit_visible(enemy, unit.country): continue
				if unit.get("flight_mode", "") == "attack" and enemy.id != unit.get("attack_target", ""): continue
				if fighter and value(unit, "air_damage" if enemy.visual_kind == "fighter" else "ground_damage") <= 0: continue
				var distance: = origin.distance_to(point)
				if patrol and distance <= reach and Vector2(unit.node.position.x, unit.node.position.z).distance_to(unit.patrol_center) <= AirOperations.PATROL_RADIUS + 0.05: patrol_targets.append(enemy)
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
		for strike in strikes:
			var unit: Dictionary = strike[0]
			var enemy: Dictionary = strike[1]
			if not ready.has(unit.id): continue
			var stat: = "aa_damage" if strike[2] else ("air_damage" if enemy.visual_kind == "fighter" else "ground_damage")
			damage[enemy.id] = damage.get(enemy.id, 0.0) + value(unit, stat) * (aa_factor(enemy) if strike[2] else (0.5 if unit.get("flight_mode", "") == "patrol" else 1.0))
			var missile_loadout: bool = EquipmentIdentity.research_tier(unit.equipment_id, unit.get("level", 1)).has("projectile_model")
			weapon_fired.emit(unit, enemy, "interceptor" if strike[2] else "missile" if missile_loadout else "drone_strike" if EquipmentIdentity.spec(unit.equipment_id).get("role", "") == "drone" else "air_strike")
			if not strike[2] and EquipmentIdentity.spec(unit.equipment_id).get("single_use", false): damage[unit.id] = damage.get(unit.id, 0.0) + unit.health
			if not strike[2]:


				for defender in armies.stacks.members(enemy):
					if defender.visual_kind in ["air_defense","naval"] and defender.health > 0 and value(defender,"aa_damage")>0:
						damage[unit.id] = damage.get(unit.id, 0.0) + value(defender, "aa_damage", true)
						weapon_fired.emit(defender, unit, "interceptor")
			# Owner 2026-10-13: patrolling aircraft also strike every 7 minutes (half damage, above);
			# an attack order hits at full damage and then the aircraft returns to land.
			cooldowns[unit.id] = AA_INTERVAL if strike[2] or unit.get("flight_mode", "") == "patrol" else ROUND_SECONDS
			if unit.get("flight_mode", "") == "attack": armies.air.return_home(unit)
		if resolve_now:
			for id in damage: pending[id] = pending.get(id, 0.0) + damage[id]
		else:
			for unit in armies.units: unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0))
func snapshot() -> Dictionary:
	return cooldowns.duplicate()
func restore(state: Dictionary) -> void :
	cooldowns = state.duplicate()
