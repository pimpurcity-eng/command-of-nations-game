class_name CombatSystem
extends RefCounted
signal weapon_fired(source: Dictionary, target_unit: Dictionary, effect: String)

const ROUND_SECONDS: = 1800.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const STACK_DAMAGE_LIMIT: = 10
## Distance at which two ground armies are touching and fight hand to hand.
const CLOSE_COMBAT_REACH: = 0.45
const MAX_ROUND_SECONDS: = ROUND_SECONDS * 4
var cooldowns: Dictionary = {}
## The unit's type as a target: one of the six Call of War classes (UnitClasses).
func target_class(unit: Dictionary) -> String:
	return UnitClasses.of(unit)
func shot_effect(unit: Dictionary) -> String:
	if EquipmentIdentity.research_tier(unit.equipment_id, unit.get("level", 1)).has("projectile_model"): return "missile"
	return "missile" if unit.visual_kind == "missile_launcher" else "artillery" if unit.visual_kind in ["artillery", "naval"] else "cannon" if unit.visual_kind == "armor" else "tracer"
## Sim seconds from the order to the blast: about 9 real seconds at 1x for the arm to rise, the
## missile to leave the tube and fly (CombatEffects.raise_and_fire uses the same time).
const NUKE_FLIGHT: = 9.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
## Nuclear missiles on their way: the blast lands when the flight time is over and the launcher,
## whose missile is used up, is gone.
func _nuclear_flights(seconds: float, armies: UnitSystem, damage: Dictionary, resolve_now: bool) -> void:
	for unit in armies.units:
		if not unit.has("nuke_launch") or unit.health <= 0: continue
		unit.nuke_launch.left = float(unit.nuke_launch.left) - seconds
		if float(unit.nuke_launch.left) > 0.0: continue
		var blast: = StrategicWeapons.blast("nuclear", unit.nuke_launch.target, armies.units)
		blast[unit.id] = 1000000.0
		for id in blast:
			if resolve_now: damage[id] = damage.get(id, 0.0) + float(blast[id])
			else:
				for other in armies.units:
					if other.id == id: other.health = maxf(0.0, other.health - float(blast[id]))
		unit.erase("nuke_launch")
static func nuclear(unit: Dictionary) -> bool:
	return str(unit.get("equipment_id", "")).begins_with("strategic_")
func key(group: Array) -> String:
	return group[0].country + ":" + group[0].stack_id
func alive(group: Array) -> Array:
	return group.filter( func(unit: Dictionary): return unit.health > 0)
## All six target classes use the shared role profile, in actual HP per round.
## Country and terrain factors are applied once by potential(), then damage is converted
## to saved condition percentage at the receiving unit. The UI reads these same values.
const HOME_DAMAGE: = 1.15
const HOME_PROTECTION: = 0.85
func damage_value(unit: Dictionary, target_kind: String, defending: bool = false) -> float:
	var target: = UnitClasses.symbol(target_kind) if target_kind not in UnitClasses.ALL else target_kind
	return UnitStats.damage(unit, target, defending)
## Owner 2026-10-16: "sniper should have a bit of range" - snipers pick off targets from a little
## further than close combat (about twice as far), far short of artillery's 2.4.
const SNIPER_RANGE: = 0.9
static func sniper(unit: Dictionary) -> bool:
	return str(unit.get("equipment_id", "")).begins_with("snipers_")
## Units that fire from range: artillery, rocket and missile launchers, warships and snipers.
static func shoots_from_range(unit: Dictionary) -> bool:
	return unit.get("visual_kind", "") in ["artillery", "missile_launcher", "naval"] or sniper(unit)
func ranged_ready(unit: Dictionary) -> bool:
	return not unit.get("moving", false) or unit.get("fire_mode", "at_will") in ["offensive", "aggressive"] or not unit.get("attack_target", "").is_empty()
func attack_reach(unit: Dictionary) -> float:
	if unit.get("upgrade_remaining", 0.0) > 0: return 0.0
	if ranged_ready(unit):
		if unit.visual_kind == "naval": return EquipmentIdentity.spec(unit.equipment_id).get("sea_range", 2.8)
		if unit.visual_kind == "artillery": return 2.4
		if sniper(unit): return SNIPER_RANGE
		if unit.visual_kind == "missile_launcher": return EquipmentIdentity.spec(unit.equipment_id).get("strike_range", 8.0)
	# Close combat: armies on the move, or that were ordered to attack / are already in a
	# battle, keep fighting after they arrive (a stopped attacker used to freeze the battle).
	# Owner 2026-10-13: "units are shooting at each other when they're not even touching" -
	# close combat only when the armies actually meet.
	return CLOSE_COMBAT_REACH if unit.get("moving", false) or not str(unit.get("attack_target", "")).is_empty() or unit.get("engaged", false) else 0.0
func eligible(group: Array, distance: float) -> Array:
	return group.filter( func(unit: Dictionary): return unit.health > 0 and attack_reach(unit) > 0 and attack_reach(unit) + 1e-06 >= distance)
func potential(group: Array, target_kind: String, ranged: bool = false, defending: bool = false) -> float:
	var contributions: Array[float] = []
	for unit in group:
		if unit.health <= 0 or (ranged and (not shoots_from_range(unit) or not ranged_ready(unit))): continue
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
	var reach: = 0.0
	for member in group: reach = maxf(reach, attack_reach(member))
	if reach <= 0.0: return []
	var coastal: bool = group.any(func(member): return EquipmentIdentity.spec(member.equipment_id).get("targets_naval", false))
	var shore: bool = group.any(func(member):return EquipmentIdentity.spec(member.equipment_id).get("shore_bombardment",false))
	for candidate in groups:
		if candidate[0].visual_kind == "fighter" or candidate[0].country == group[0].country: continue
		if (candidate[0].visual_kind == "naval") != (group[0].visual_kind == "naval") and not (coastal and candidate[0].visual_kind == "naval") and not (shore and group[0].visual_kind == "naval"): continue
		var defenders: = alive(candidate)
		if defenders.is_empty() or defenders[0].country == group[0].country: continue
		var point: = Vector2(defenders[0].node.position.x, defenders[0].node.position.z)
		var distance: = origin.distance_to(point)
		if distance > reach + 1e-06: continue
		if armies != null and not armies.unit_visible(defenders[0], group[0].country): continue
		var explicit: bool = group[0].get("attack_target", "") in defenders.map( func(unit: Dictionary): return unit.id)
		if group[0].get("fire_mode", "at_will") in ["return", "hold"] and not explicit: continue
		var priority: = 0.0 if explicit else distance
		if not eligible(group, distance).is_empty() and priority < nearest:
			nearest = priority
			result = defenders
	return result
func advance(seconds: float, armies: UnitSystem, pending: Dictionary = {}, resolve_now: bool = false) -> void :
	if not is_finite(seconds) or seconds < 0 or (seconds == 0 and not resolve_now) or not armies.at_war: return
	_nuclear_flights(seconds, armies, pending, resolve_now)
	var groups: = armies.stacks.groups()
	var spatial: Dictionary = {}
	for group in groups:
		var cell: = Vector2i(floori(group[0].node.position.x / 4.0), floori(group[0].node.position.z / 4.0))
		if not spatial.has(cell): spatial[cell] = []
		spatial[cell].append(group)
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
			var reach: = 0.0
			for unit in living: reach = maxf(reach, attack_reach(unit))
			if reach <= 0.0: continue
			var origin: = Vector2(living[0].node.position.x, living[0].node.position.z)
			var low: = Vector2i(floori((origin.x-reach)/4.0),floori((origin.y-reach)/4.0))
			var high: = Vector2i(floori((origin.x+reach)/4.0),floori((origin.y+reach)/4.0))
			var candidates: Array = []
			for x in range(low.x,high.x+1):
				for y in range(low.y,high.y+1): candidates.append_array(spatial.get(Vector2i(x,y), []))
			var defenders: = target(living, candidates, armies)
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
			var ranged: = distance > CLOSE_COMBAT_REACH + 0.05  # beyond touching: snipers, guns and launchers
			var contributors: = eligible(attackers, distance)
			var attackers_home: = _home(armies, attackers[0])
			var defenders_home: = _home(armies, defenders[0])
			for defender in defenders:
				var strike: = potential(contributors, target_class(defender), ranged) / defenders.size()
				strike *= (HOME_DAMAGE if attackers_home else 1.0) * (HOME_PROTECTION if defenders_home else 1.0)
				damage[defender.id] = damage.get(defender.id, 0.0) + UnitStats.condition_damage(defender, strike)
			if not ranged:
				for attacker in attackers:
					var response: = potential(defenders, target_class(attacker), false, true) / attackers.size()
					response *= (HOME_DAMAGE if defenders_home else 1.0) * (HOME_PROTECTION if attackers_home else 1.0)
					damage[attacker.id] = damage.get(attacker.id, 0.0) + UnitStats.condition_damage(attacker, response)
				for defender in defenders:
					if potential([defender], attackers[0].visual_kind, false, true) > 0:
						weapon_fired.emit(defender, attackers[0], shot_effect(defender))
			if ranged and defenders[0].get("fire_mode", "at_will") == "return" and cooldowns.get(key(defenders), 0.0) <= 1e-06:
				var answering: = eligible(defenders, distance)
				if not answering.is_empty():
					for attacker in attackers:
						damage[attacker.id] = damage.get(attacker.id, 0.0) + UnitStats.condition_damage(attacker, potential(answering, target_class(attacker), true) / attackers.size())
					cooldowns[key(defenders)] = ROUND_SECONDS
					for defender in answering: weapon_fired.emit(defender, attackers[0], shot_effect(defender))
			var rounds: = 1.0
			for attacker in contributors:
				# Owner 2026-10-15: a nuclear missile is fired once - the launcher and its missile
				# are used up - and the blast hurts every army around the target.
				if nuclear(attacker):
					if not attacker.has("nuke_launch"):
						attacker["nuke_launch"] = {"target": b, "left": NUKE_FLIGHT}
						weapon_fired.emit(attacker, defenders[0], "nuke")
					continue
				if potential([attacker], target_class(defenders[0]), ranged) > 0:
					weapon_fired.emit(attacker, defenders[0], shot_effect(attacker))
				if attacker.visual_kind == "missile_launcher": rounds = maxf(rounds, EquipmentIdentity.spec(attacker.equipment_id).get("reload_rounds", 4.0))
			cooldowns[attack[2]] = ROUND_SECONDS * rounds
		if resolve_now:
			for id in damage: pending[id] = pending.get(id, 0.0) + damage[id]
		else:
			for unit in armies.units: unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0))
## True when the army stands on land its own country holds (Call of War Home Defence).
func _home(armies: UnitSystem, unit: Dictionary) -> bool:
	return armies != null and armies.navigation != null and armies.navigation.terrain != null and armies._land_owner(unit) == unit.country
func remaining_for(unit: Dictionary) -> float:
	return cooldowns.get(unit.country + ":" + unit.stack_id, 0.0)
func snapshot() -> Dictionary:
	return cooldowns.duplicate()
func restore(state: Dictionary) -> void :
	cooldowns = state.duplicate()
