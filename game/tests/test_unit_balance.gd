extends SceneTree
## Full live roster at every research level, plus real combat damage, counters, terrain,
## health persistence, nuclear stack survivability and patrol damage distribution.
var checks: = 0
var failures: Array[String] = []
var armies: UnitSystem
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); print("FAIL ", text)
func _initialize() -> void: call_deferred("run")
func make_unit(id: String, name: String, position: Vector2 = Vector2.ZERO) -> Dictionary:
	var unit: = UnitStats.specimen(id)
	unit.merge({"id": name, "name": name, "stack_id": name, "node": Node3D.new(), "moving": false,
		"engaged": false, "attack_target": "", "fire_mode": "at_will", "flight_mode": "grounded",
		"waypoints": [], "forced_march": false, "delay_remaining": 0.0, "target": position})
	unit.node.position = Vector3(position.x, 0, position.y)
	return unit
func reset(units: Array) -> void:
	for unit in armies.units: unit.node.free()
	armies.units = units
	armies.stacks.invalidate()
func run() -> void:
	armies = UnitSystem.new()
	armies.stacks.armies = armies
	armies.air.armies = armies
	armies.at_war = true
	armies.fog_enabled = false
	var hp_values: = {}
	for family in EquipmentIdentity.catalog:
		check(UnitStats.balance.families.has(family.id), "explicit profile: " + family.id)
		for country in ["russia", "ukraine", "united_states", "china"]:
			var previous_hp: = 0.0
			for level in range(1, 6):
				var unit: = UnitStats.specimen(family.id, level, country)
				var label: = "%s %s L%d" % [family.id, country, level]
				var hp: = UnitStats.max_hp(unit)
				hp_values[hp] = true
				check(is_finite(hp) and hp > previous_hp, "HP grows at each level: " + label)
				previous_hp = hp
				for target in UnitClasses.ALL:
					for defending in [false, true]:
						var damage: = UnitStats.damage(unit, target, defending)
						check(is_finite(damage) and damage >= 0, "finite damage: " + label + " vs " + target)
				for terrain in TerrainRules.rules:
					for effect in ["speed", "attack", "defense"]:
						var factor: = TerrainRules.for_unit(unit, terrain, effect)
						check(is_finite(factor) and factor > 0, "valid terrain: " + label)
				unit.health = 37.5
				var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(unit))
				check(is_equal_approx(UnitStats.current_hp(roundtrip), hp * 0.375), "old saved condition retained: " + label)
	check(hp_values.size() > 30, "HP values vary across roles, doctrines and levels")
	var infantry: = UnitStats.specimen("infantry_russia")
	var tank: = UnitStats.specimen("tanks_russia")
	var light: = UnitStats.specimen("light_tank_russia")
	var aa: = UnitStats.specimen("skyguard_russia")
	check(UnitStats.max_hp(tank) > UnitStats.max_hp(light) and UnitStats.max_hp(light) > UnitStats.max_hp(infantry), "MBT > light tank > infantry durability")
	check(UnitStats.condition_damage(tank, 5) < UnitStats.condition_damage(infantry, 5), "equal HP hit removes less condition from a tank")
	check(UnitStats.damage(infantry, "infantry", true) > UnitStats.damage(infantry, "infantry"), "infantry favours defence")
	check(UnitStats.damage(tank, "heavy") > UnitStats.damage(light, "heavy"), "MBT beats light tank against heavy armour")
	check(TerrainRules.for_unit(tank, "urban", "attack") < TerrainRules.for_unit(tank, "plains", "attack") and TerrainRules.for_unit(tank, "urban", "defense") < 1.0, "tank urban attack and defence penalties")
	check(TerrainRules.for_unit(infantry, "urban", "defense") > 1.0, "infantry city defence bonus")
	check(TerrainRules.for_unit(UnitStats.specimen("special_forces_russia"), "mountains", "attack") > TerrainRules.for_unit(infantry, "mountains", "attack"), "special forces have their own difficult-terrain advantage")
	check(UnitStats.damage(UnitStats.specimen("snipers_russia"), "heavy") == 0, "snipers cannot destroy heavy armour")
	for id in ["drones_russia", "il76md_russia", "a50u_russia", "transport_heli_russia", "cargo_russia", "tankers_russia", "medic_russia"]:
		for target in UnitClasses.ALL: check(UnitStats.damage(UnitStats.specimen(id), target) == 0, id + " remains unarmed")
	var combat: = CombatSystem.new()
	check(combat.potential([aa], "air") > combat.potential([UnitStats.specimen("skyguard_ukraine")], "air"), "Russian air-defence advantage")
	check(combat.potential([UnitStats.specimen("tanks_ukraine")], "heavy") > combat.potential([tank], "heavy"), "European tank advantage")
	check(combat.potential([UnitStats.specimen("fighters_ukraine")], "air") > combat.potential([UnitStats.specimen("fighters_russia")], "air"), "European aircraft advantage")
	check(combat.potential([UnitStats.specimen("rockets_russia")], "infantry") > combat.potential([UnitStats.specimen("rockets_ukraine")], "infantry"), "Russian rocket advantage")
	check(UnitStats.damage(UnitStats.specimen("submarines_russia"), "naval") > UnitStats.damage(UnitStats.specimen("submarines_russia"), "submarine"), "submarine surface-ship specialization")
	check(UnitStats.damage(UnitStats.specimen("fleet_russia"), "submarine") > UnitStats.damage(UnitStats.specimen("corvettes_russia"), "submarine"), "frigate anti-submarine advantage")
	# A real close-combat event subtracts the same HP shown by potential().
	var point: Vector2 = GeographicProjection.load_cities()[0].point
	var attacker: = make_unit("tanks_russia", "a", point)
	var defender: = make_unit("infantry_ukraine", "d", point + Vector2(0.1, 0))
	attacker.attack_target = "d"
	reset([attacker, defender])
	var expected: = combat.potential([attacker], "infantry")
	var before: = UnitStats.current_hp(defender)
	combat.advance(0, armies, {}, true) # resolve_now returns pending, leaving health untouched.
	combat.cooldowns.clear()
	combat.advance(0.001, armies)
	check(is_equal_approx(before - UnitStats.current_hp(defender), expected), "real combat loses displayed HP, not percent damage")
	defender.health = 37.5
	var saved: Array = JSON.parse_string(JSON.stringify(armies.snapshot()))
	check(is_equal_approx(float(saved[1].health), 37.5) and is_equal_approx(UnitStats.current_hp(saved[1]), UnitStats.max_hp(defender) * 0.375), "real snapshot preserves old damaged units")
	# Strength applies damage efficiency once; an additional 50% multiplier was a UI bug.
	var strong: = ArmyDetailsPanel.strength(defender)
	var strongest: = 0.0
	for target in UnitClasses.ALL: strongest = maxf(strongest, combat.potential([defender], target, false, true))
	check(is_equal_approx(strong, strongest), "strength agrees with combat at partial health")
	# Naval and air-defence events use exactly the same target HP conversion as land combat.
	var escort: = make_unit("fleet_russia", "escort", point)
	var cargo: = make_unit("cargo_ukraine", "cargo", point + Vector2(1.6, 0))
	reset([escort, cargo])
	combat = CombatSystem.new()
	var naval_pending: = {}
	combat.advance(0, armies, naval_pending, true)
	check(is_equal_approx(float(naval_pending.get("cargo", 0)) * UnitStats.max_hp(cargo) / 100.0, combat.potential([escort], "naval")), "naval HP damage matches card")
	var battery: = make_unit("skyguard_russia", "battery", point)
	var passing: = make_unit("helicopters_ukraine", "passing", point + Vector2(1.6, 0))
	passing.flight_mode = "fly"
	reset([battery, passing])
	var aa_pending: = {}
	var air_defence: = AirBattleSystem.new()
	air_defence.advance(0, armies, aa_pending, true)
	check(is_equal_approx(float(aa_pending.get("passing", 0)) * UnitStats.max_hp(passing) / 100.0, air_defence.value(battery, "aa_damage") * AirBattleSystem.AA_PASSING_FACTOR), "passing aircraft receives half AA HP damage")
	var medic: = make_unit("medic_russia", "medic", point)
	var patient: = make_unit("infantry_russia", "patient", point)
	patient.health = 50.0; medic.stack_id = "aid"; patient.stack_id = "aid"
	reset([medic, patient])
	var patient_before: = UnitStats.current_hp(patient)
	SupportRoles.heal(armies, null, SupportRoles.HOUR)
	check(is_equal_approx(UnitStats.current_hp(patient) - patient_before, SupportRoles.MEDIC_PER_LEVEL * 1.5), "medic heals actual HP rather than percentage")
	# Patrol attacks one stack once and hits each of its members.
	var plane: = make_unit("strike_russia", "plane", point)
	plane.flight_mode = "patrol"; plane.patrol_center = point; plane.patrol_phase = 0.0
	var first: = make_unit("infantry_ukraine", "d1", point)
	var second: = make_unit("infantry_ukraine", "d2", point)
	first.stack_id = "target"; second.stack_id = "target"
	reset([plane, first, second])
	var air: = AirBattleSystem.new()
	var pending: = {}
	air.advance(0, armies, pending, true)
	var hp_hit: = float(pending.get("d1", 0)) * UnitStats.max_hp(first) / 100.0 + float(pending.get("d2", 0)) * UnitStats.max_hp(second) / 100.0
	# Owner 2026-10-16: a patrol hits every unit of the army at 65% of its attack damage.
	check(is_equal_approx(hp_hit, air.strike_value(plane, first) * AirBattleSystem.PATROL_DAMAGE + air.strike_value(plane, second) * AirBattleSystem.PATROL_DAMAGE), "patrol hits each unit of the army at 65% of attack damage")
	check(is_equal_approx(float(pending.get("d1", 0)), float(pending.get("d2", 0))), "patrol shares damage evenly across equal units")
	# A squadron does not multiply the target's defensive volley by its plane count.
	var squadron: Array = []
	for i in 2:
		var jet: = make_unit("strike_russia", "jet%d" % i, point)
		jet.stack_id = "squadron"; jet.flight_mode = "patrol"; jet.patrol_center = point
		squadron.append(jet)
	var sam: = make_unit("patriot_ukraine", "sam", point)
	squadron.append(sam)
	reset(squadron)
	air = AirBattleSystem.new()
	air.cooldowns.sam = 100.0 # isolate point defence from its separate periodic AA shot.
	pending = {}
	air.advance(0, armies, pending, true)
	var returned_hp: = 0.0
	for i in 2: returned_hp += float(pending.get("jet%d" % i, 0)) * UnitStats.max_hp(armies.units[i]) / 100.0
	check(is_equal_approx(returned_hp, air.value(sam, "aa_damage", true)), "two planes share one SAM defensive volley")
	# The air stack uses the same strongest-ten limit as ground potential().
	var many: Array = []
	for i in 11:
		var jet: = make_unit("strike_russia", "many%d" % i, point)
		jet.stack_id = "many"; jet.flight_mode = "patrol"; jet.patrol_center = point
		many.append(jet)
	var target: = make_unit("infantry_ukraine", "large_target", point)
	many.append(target)
	reset(many)
	air = AirBattleSystem.new(); pending = {}
	air.advance(0, armies, pending, true)
	check(is_equal_approx(float(pending.get("large_target", 0)) * UnitStats.max_hp(target) / 100.0, 10 * air.strike_value(armies.units[0], target) * AirBattleSystem.PATROL_DAMAGE), "11-plane stack deals only its strongest ten contributions")
	var layered: Array = []
	for i in 10:
		var long_range: = make_unit("patriot_russia", "long%d" % i, point)
		long_range.stack_id = "layered"
		layered.append(long_range)
	var short_range: = make_unit("skyguard_russia", "short", point)
	short_range.stack_id = "layered"; layered.append(short_range)
	var scout: = make_unit("drones_ukraine", "scout", point)
	scout.flight_mode = "fly"; layered.append(scout)
	reset(layered)
	air = AirBattleSystem.new(); pending = {}
	air.advance(0, armies, pending, true)
	check(float(pending.get("scout", 0)) > 0, "ineligible long-range SAMs do not suppress short-range drone defence in a large mixed stack")
	# Blast pool is now HP; large stacks still survive while lone armies are destroyed.
	var blast_units: Array = []
	for i in 14:
		var unit: = make_unit("infantry_ukraine", "blast%d" % i, point)
		unit.stack_id = "large"
		blast_units.append(unit)
	reset(blast_units)
	var blast: = StrategicWeapons.blast("nuclear", point, armies.units)
	check(blast.size() == 14 and float(blast.blast0) < 100, "14-unit infantry stack survives nuclear pool")
	armies.units[0].stack_id = "alone"
	blast = StrategicWeapons.blast("nuclear", point, armies.units)
	check(float(blast.blast0) >= 100, "lone infantry is destroyed by nuclear pool")
	reset([])
	armies.free()
	print("RESULT UNIT_BALANCE checks=", checks, " families=", EquipmentIdentity.catalog.size(), " levels=5 doctrines=4 failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
