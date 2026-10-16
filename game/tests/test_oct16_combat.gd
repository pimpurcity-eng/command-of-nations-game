extends SceneTree
## Owner list 2026-10-16 (combat and air): planes attack planes (also parked on their airfield),
## patrols that clearly hurt every unit under them, air defence that shoots patrolling planes,
## 5-second battle animations per exchange of fire, healing an army with gold, the attacker shown
## as the attacker inside an enemy city, and per-army fire control.
##   xvfb-run -a godot --path . --script tests/test_oct16_combat.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
var game
var units: UnitSystem
## Real seconds of play at 1x, in 10-second steps.
func simulate(real_seconds: float) -> void:
	game.clock.paused = false
	var n: = 0
	while real_seconds > 0:
		game.clock.advance(minf(10.0, real_seconds))
		real_seconds -= 10.0
		n += 1
		if n % 10 == 0: await process_frame
	game.clock.paused = true
func put(unit: Dictionary, point: Vector2) -> void:
	for member in units.stacks.members(unit):
		member.node.position = units.surface_position(member, point)
		member.target = point
		member.moving = false
		member.waypoints.clear()
func clear_around(point: Vector2, keep: Array) -> void:
	var stacks: Array = keep.map(func(u): return u.country + ":" + u.stack_id)
	for other in units.units:
		if (other.country + ":" + other.stack_id) in stacks: continue
		var at: = Vector2(other.node.position.x, other.node.position.z)
		if at.distance_to(point) < 8.0:
			if units.air.is_air(other) and other.flight_mode == "grounded": other.health = 0.0
			else: put(other, at + Vector2(70, 70))
	game.match_rules.combat.cooldowns.clear()
	game.match_rules.air_combat.cooldowns.clear()
func ground(plane: Dictionary) -> void:
	plane.flight_mode = "grounded"
	plane.refuel_remaining = 0.0
	plane.flight_used = 0.0
	plane.moving = false
	plane.attack_target = ""
	plane.repeat_target = ""
	plane.health = 100.0
	units.air.position(plane, units.air.base(plane).point)
func hp_lost(unit: Dictionary, before: float) -> float:
	return (before - unit.health) * UnitStats.max_hp(unit) / 100.0
func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	game.clock.paused = true
	game.clock.set_speed(1.0)
	game.match_rules.ai_enabled = false
	for i in 3: await process_frame
	units = game.units
	game.match_rules.declare_war()
	var air: AirBattleSystem = game.match_rules.air_combat
	var plane: Dictionary = units.units.filter(func(u): return u.country == "russia" and units.air.is_air(u))[0]
	var foe_plane: Dictionary = units.units.filter(func(u): return u.country == "ukraine" and units.air.is_air(u))[0]
	var base: Vector2 = units.air.base(plane).point

	# 1. Attacking an enemy plane parked on its airfield: the order is accepted and it is hit.
	ground(plane)
	ground(foe_plane)
	var parked_at: = base + Vector2(1.6, 0.2)
	units.air.position(foe_plane, parked_at)
	clear_around(base, [plane, foe_plane])
	var flying_copy: Dictionary = foe_plane.duplicate()
	flying_copy.flight_mode = "fly"
	check(air.strike_value(plane, foe_plane) >= air.strike_value(plane, flying_copy) and air.strike_value(plane, foe_plane) > 0, "a plane on the ground is a sitting target (%.2f HP a strike, %.2f in the air)" % [air.strike_value(plane, foe_plane), air.strike_value(plane, flying_copy)])
	check(units.air.target_near(parked_at + Vector2(0.3, 0.0), "russia").get("id", "") == foe_plane.id, "an attack on the airfield picks the plane parked there")
	units.select_unit(units.units.find(plane))
	units.command_ids.assign([plane.id])
	check(units.attack_many(foe_plane) == 1 and plane.flight_mode == "attack" and plane.attack_target == foe_plane.id, "the attack order on an enemy plane is accepted")
	var foe_before: float = foe_plane.health
	await simulate(120.0)
	check(foe_plane.health < foe_before, "the parked enemy plane is damaged (%.1f -> %.1f)" % [foe_before, foe_plane.health])
	check(hp_lost(foe_plane, foe_before) >= air.strike_value(plane, foe_plane) * 0.9, "the strike does real damage (%.2f HP)" % hp_lost(foe_plane, foe_before))

	# 1b. ...and one in the air.
	ground(plane)
	foe_plane.health = 100.0
	foe_plane.flight_mode = "fly"
	units.air.position(foe_plane, parked_at)
	foe_plane.target = parked_at
	foe_plane.waypoints = [parked_at]
	game.match_rules.air_combat.cooldowns.clear()
	units.select_unit(units.units.find(plane))
	units.command_ids.assign([plane.id])
	check(units.attack_many(foe_plane) == 1, "the attack order on an enemy plane in the air is accepted")
	foe_before = foe_plane.health
	for i in 12:
		# Hold the enemy plane in place over the spot.
		foe_plane.flight_mode = "fly"
		units.air.position(foe_plane, parked_at)
		foe_plane.moving = false
		foe_plane.waypoints = [parked_at]
		await simulate(10.0)
	check(foe_plane.health < foe_before, "the enemy plane in the air is damaged (%.1f -> %.1f)" % [foe_before, foe_plane.health])
	ground(foe_plane)
	foe_plane.health = 0.0

	# 2. A patrol over an enemy army hits every unit in it, each at 65% of the attack damage, every 7 minutes.
	ground(plane)
	var infantry: Array = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")
	var victims: Array = [infantry[0], infantry[1]]
	var over: = base + Vector2(1.2, -0.6)
	for v in victims:
		v.stack_id = "oct16_victims"
		v.health = 100.0
	units.stacks.invalidate()
	put(victims[0], over + Vector2(0.4, 0.0))
	clear_around(over, [plane, victims[0]])
	var flight: String = units.air.order(plane, over, "patrol")
	check(flight.is_empty(), "the plane takes off on patrol " + flight)
	await simulate(60.0)
	for v in victims: v.health = 100.0
	game.match_rules.air_combat.cooldowns.erase(plane.id)
	await simulate(15.0 * 60.0)
	var expected: float = air.strike_value(plane, victims[0]) * AirBattleSystem.PATROL_DAMAGE
	var each: Array = victims.map(func(v): return hp_lost(v, 100.0))
	print("patrol hits: per strike %.2f HP, lost %s" % [expected, str(each)])
	check(each.all(func(h): return h >= expected * 2.0 - 0.01), "after 15 minutes every unit of the army took at least two patrol hits (%s HP each, %.2f a hit)" % [str(each), expected])
	check(is_equal_approx(AirBattleSystem.PATROL_DAMAGE, 0.65), "a patrol hit is 65% of an attack hit")

	# 3. Air defence shoots a plane patrolling over it; Hold fire stops it, Return fire still shoots a patrol.
	var sites: Array = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "air_defense")
	var site: Dictionary = sites[0]
	for v in victims: put(v, over + Vector2(60, -60))
	put(site, over + Vector2(0.5, 0.3))
	site.health = 100.0
	clear_around(over, [plane, site])
	check(AirBattleSystem.can_engage(site, plane), "short-range air defence can reach a patrolling jet")
	plane.health = 100.0
	game.match_rules.air_combat.cooldowns.clear()
	await simulate(60.0)
	check(plane.health < 100.0, "air defence damages the patrolling plane (%.1f%%)" % plane.health)
	ground(plane)
	plane.flight_mode = "patrol"
	units.air.position(plane, over + Vector2(AirOperations.PATROL_RADIUS, 0.0))
	plane.patrol_center = over
	plane.moving = true
	plane.waypoints = [over + Vector2.from_angle(0.3) * AirOperations.PATROL_RADIUS]
	plane.target = plane.waypoints[0]
	site.fire_mode = "hold"
	game.match_rules.air_combat.cooldowns.clear()
	var pending: = {}
	air.advance(0, units, pending, true)
	check(not pending.has(plane.id), "air defence on Hold fire does not shoot")
	site.fire_mode = "return"
	pending = {}
	air.advance(0, units, pending, true)
	check(pending.has(plane.id), "air defence on Return fire shoots a plane patrolling over it")
	plane.flight_mode = "fly"
	game.match_rules.air_combat.cooldowns.clear()
	pending = {}
	air.advance(0, units, pending, true)
	check(not pending.has(plane.id), "air defence on Return fire lets a plane just passing go")
	site.fire_mode = "at_will"
	put(site, over + Vector2(60, 60))
	ground(plane)

	# 4. Battle: the army that moves in is the attacker, even on land its country took.
	var mine: Array = units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")
	var attacker: Dictionary = mine[0]
	var defender: Dictionary = infantry[2]
	var front: = base + Vector2(-2.0, 1.0)
	put(defender, front)
	put(attacker, front + Vector2(0.9, 0.0))
	clear_around(front, [attacker, defender])
	attacker.health = 100.0
	defender.health = 100.0
	units.select_unit(units.units.find(attacker))
	units.command_ids.assign([attacker.id])
	check(units.attack_many(defender) == 1, "the infantry is ordered to attack")
	for i in 400:
		units.advance(0.05)
		if attacker.engaged: break
	check(attacker.engaged and defender.engaged, "the armies meet in battle")
	check(attacker.get("battle_role", "") == "attacker" and defender.get("battle_role", "") == "defender", "the army that moved in is the attacker (%s / %s)" % [attacker.get("battle_role", ""), defender.get("battle_role", "")])
	check(CombatSystem.battle_label(attacker, "russia") == "ATTACKING", "the attacker reads ATTACKING even on its own country's land")
	check(not game.match_rules.combat._home(units, attacker), "the attacker gets no home defence bonus")

	# 5. War animation: about 5 seconds per exchange of fire, then the armies stand still.
	var effects: CombatEffects = game.combat_effects
	for u in units.units: u.erase("fire_burst")
	effects.projectiles.filter(func(p): return p.effect == "skirmish").map(func(p): return p.node.queue_free())
	effects.projectiles = effects.projectiles.filter(func(p): return p.effect != "skirmish")
	for i in 8: effects._skirmish(0.5)
	check(not effects.projectiles.any(func(p): return p.effect == "skirmish"), "no shooting animation between rounds")
	effects.on_shot(attacker, defender, "tracer")
	check(is_equal_approx(float(attacker.get("fire_burst", 0.0)), CombatEffects.BURST_SECONDS) and is_equal_approx(float(defender.get("fire_burst", 0.0)), CombatEffects.BURST_SECONDS), "an exchange of fire starts a %.0f-second battle animation on both sides" % CombatEffects.BURST_SECONDS)
	# The camera is far from this battle in the test: show the armies as if zoomed in on them.
	var leaders: Array = [units.stacks.leader(units.stacks.members(attacker)), units.stacks.leader(units.stacks.members(defender))]
	for lead in leaders: lead.node.visible = true
	for i in 4: effects._skirmish(0.5)
	check(effects.projectiles.any(func(p): return p.effect == "skirmish"), "tracers fly during the burst")
	for i in 7: effects._skirmish(0.5)
	check(float(attacker.get("fire_burst", 0.0)) <= 0.0, "after 5 seconds the animation stops until the next shot")
	var before_quiet: int = effects.projectiles.size()
	for i in 4: effects._skirmish(0.5)
	check(effects.projectiles.size() <= before_quiet, "no new tracers once the burst is over")
	put(attacker, front + Vector2(-50, 0))
	put(defender, front + Vector2(-50, 40))

	# 6. Heal an army with gold.
	var patient: Dictionary = mine[1]
	units.select_unit(units.units.find(patient))
	for member in units.stacks.members(patient): member.health = 100.0
	check(GoldWallet.heal_price(game.production, units.stacks.members(patient)) == 0, "an army at full health costs nothing to heal")
	patient.health = 75.0
	var quarter: = GoldWallet.heal_price(game.production, units.stacks.members(patient))
	patient.health = 50.0
	var half: = GoldWallet.heal_price(game.production, units.stacks.members(patient))
	check(quarter > 0 and absi(half - 2 * quarter) <= 2, "the heal price grows with the health lost (%d for 25%%, %d for 50%%)" % [quarter, half])
	check(half <= int(ceil(GoldWallet.unit_value(game.production, patient))), "healing never costs more than the unit is worth")
	game.show_stack_info()
	var panel: ArmyDetailsPanel = game.stack_dialog
	check(panel.heal_button != null and is_instance_valid(panel.heal_button) and panel.heal_button.visible, "a damaged army of yours shows the gold heal button")
	var gold_before: = int(game.production.gold.russia)
	panel.heal_button.pressed.emit()
	check(is_equal_approx(patient.health, 100.0), "the gold button heals the army to full")
	check(int(game.production.gold.russia) == gold_before - half, "the heal costs its quoted gold (%d)" % (gold_before - int(game.production.gold.russia)))
	game.production.gold.russia = 0
	patient.health = 50.0
	check(not GoldWallet.heal_army(game.production, units, "russia", patient.id).is_empty() and patient.health == 50.0, "without enough gold nothing is healed")
	game.production.gold.russia = gold_before
	check(not GoldWallet.heal_army(game.production, units, "ukraine", patient.id).is_empty(), "nobody can heal another country's army")
	patient.health = 100.0

	# 7. Fire control per army: Fire at will, Return fire, Hold fire.
	var guns: Array = units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "artillery")
	if not guns.is_empty():
		var gun: Dictionary = guns[0]
		var gun_at: = front + Vector2(10, 10)
		put(gun, gun_at)
		var mark: Dictionary = infantry[3]
		put(mark, gun_at + Vector2(1.5, 0))
		clear_around(gun_at, [gun, mark])
		units.select_unit(units.units.find(gun))
		game.show_stack_info()
		var hold_button: Button = panel.content.find_child("Fire_hold", true, false)
		check(hold_button != null, "the army panel lists the fire control choices")
		if hold_button != null: hold_button.pressed.emit()
		check(units.stacks.members(gun).all(func(m): return m.fire_mode == "hold"), "Hold fire is set on the whole army from the panel")
		var combat: CombatSystem = game.match_rules.combat
		check(combat.target(units.stacks.members(gun), units.stacks.groups(), units).is_empty(), "on Hold fire the artillery does not open fire on an enemy in range")
		units.set_fire_mode("return", [gun])
		check(combat.target(units.stacks.members(gun), units.stacks.groups(), units).is_empty(), "on Return fire it waits to be attacked")
		units.set_fire_mode("at_will", [gun])
		check(not combat.target(units.stacks.members(gun), units.stacks.groups(), units).is_empty(), "on Fire at will it opens fire by itself")
		units.set_fire_mode("hold", [gun])
		var saved: Array = units.snapshot()
		var entry: Array = saved.filter(func(e): return e.id == gun.id)
		check(not entry.is_empty() and entry[0].fire_mode == "hold", "fire control is saved with the army")
		units.set_fire_mode("at_will", [gun])
	check("fire_mode" in preload("res://scripts/net/match_server.gd").UNIT_OPS, "online, fire control is an army order the server accepts")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
