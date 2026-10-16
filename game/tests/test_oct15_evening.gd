extends SceneTree
## Owner list 2026-10-15 (evening): waypoint paths, armies joining a battle, simple stand-in models,
## no capture while a city is defended, country names that follow the front, battles you can see,
## aircraft that refuel and strike again, patrols that hurt, times at the current speed, city
## buildings outside the houses.
##   xvfb-run -a godot --path . --script tests/test_oct15_evening.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
var game
func simulate(real_seconds: float) -> void:
	game.clock.paused = false
	while real_seconds > 0:
		game.clock.advance(1.0)
		real_seconds -= 1.0
		if int(real_seconds) % 20 == 0: await process_frame
	game.clock.paused = true
func put(unit: Dictionary, point: Vector2) -> void:
	for member in game.units.stacks.members(unit):
		member.node.position = game.units.surface_position(member, point)
		member.target = point
		member.moving = false
		member.waypoints.clear()
func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	for i in 3: await process_frame
	var units: UnitSystem = game.units
	var mine: Array = units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")
	var theirs: Array = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")

	# 1. Waypoint path: every tap adds a leg, the army stays selected, Done ends it.
	var walker: Dictionary = mine[0]
	var start: = Vector2(walker.node.position.x, walker.node.position.z)
	units.select_unit(units.units.find(walker))
	game.hud.add_destination_requested.emit()
	check(game.order_mode and game.append_order and game.hud.cancel_button.text == "Done", "Waypoint opens path mode with a Done button")
	var stops: Array = []
	for t in game.map.territories:
		if not t.playable or t.controller != "russia" or not game.map.province_hubs.has(t.title): continue
		var h: Vector2 = game.map.province_hubs[t.title]
		if h.distance_to(start) > 1.0 and h.distance_to(start) < 5.0 and stops.all(func(o): return o.distance_to(h) > 1.0): stops.append(h)
	game.player_order(Vector3(stops[0].x, 0, stops[0].y))
	var first_end: Vector2 = walker.target
	check(walker.moving and game.order_mode and units.selected >= 0, "first waypoint: the army moves and stays selected for the next one")
	game.player_order(Vector3(stops[1].x, 0, stops[1].y))
	check(walker.target != first_end and game.order_mode, "second waypoint is added to the path")
	check(walker.waypoints.size() >= 2, "the route holds both legs (%d points)" % walker.waypoints.size())
	game.hud.cancel_order_requested.emit()
	check(not game.order_mode and units.selected < 0 and walker.moving, "Done closes the panel and the army keeps its route")
	put(walker, start)

	# 8. A patrol over enemy armies hurts them (before the test takes any Ukrainian land).
	if not game.match_rules.at_war: game.match_rules.declare_war()
	var hawks: Array = units.units.filter(func(u): return u.country == "ukraine" and units.air.is_air(u))
	if not hawks.is_empty():
		var hawk: Dictionary = hawks[0]
		var victim: Dictionary = mine[4]
		var hawk_base: Vector2 = units.air.base(hawk).point
		# The test took eastern Ukraine above; give the plane's airfield back.
		for t in game.map.territories:
			if t.playable and RegionData.contains(t, hawk_base): game.match_rules.change_control(t, "ukraine")
		var over: = hawk_base + Vector2(0.8, 0.3)
		put(victim, over + Vector2(0.9, 0.0))
		victim.health = 100.0
		hawk.flight_mode = "grounded"
		hawk.refuel_remaining = 0.0
		hawk.flight_used = 0.0
		units.air.position(hawk, hawk_base)
		var flight_error: String = units.air.order(hawk, over, "patrol")
		check(flight_error.is_empty(), "the plane takes off on patrol " + flight_error)
		# Only the plane may hurt the victim: other armies are moved well away.
		for other in units.units:
			if other.stack_id != victim.stack_id and other.stack_id != hawk.stack_id and Vector2(other.node.position.x, other.node.position.z).distance_to(over) < 12.0:
				put(other, Vector2(other.node.position.x, other.node.position.z) + Vector2(60, 60))
		var health_before: float = victim.health
		await simulate(8.0 * 60.0)
		var destroyed: bool = not is_instance_valid(victim.node) or not units.units.has(victim)
		if not is_instance_valid(hawk.node): print("DEBUG hawk lost, health ", hawk.health)
		elif not destroyed: print("DEBUG hawk=", hawk.flight_mode, " hawk_d=", Vector2(hawk.node.position.x, hawk.node.position.z).distance_to(over), " victim_d=", Vector2(victim.node.position.x, victim.node.position.z).distance_to(over), " vis=", units.unit_visible(victim, "ukraine"), " war=", units.at_war, " cd=", game.match_rules.air_combat.cooldowns.get(hawk.id, -1))
		check(destroyed or victim.health < health_before, "a patrolling plane damages enemy armies under its circle (%.1f -> %s)" % [health_before, "destroyed" if destroyed else "%.1f" % victim.health])

	# 2. City labels and capture points: no province centre inside another city's houses.
	var kyiv: Dictionary = {}
	for city in game.cities.cities:
		if city.name == "Kyiv": kyiv = city
	var region: Dictionary = game.map.territories.filter(func(t): return t.playable and t.title == "Kyiv region")[0]
	var hub: Vector2 = game.match_rules.capture_point(region)
	check(hub.distance_to(kyiv.point) >= StrategicMap.CAPITAL_CLEARANCE - 0.01, "Kyiv region is taken outside Kyiv's houses (%.2f from the city)" % hub.distance_to(kyiv.point))

	# 3. A defended city is not taken.
	game.match_rules.declare_war()
	var city_province: Dictionary = game.map.territories.filter(func(t): return t.id == kyiv.sector)[0]
	var city_hub: Vector2 = game.match_rules.capture_point(city_province)
	for unit in units.units:
		if Vector2(unit.node.position.x, unit.node.position.z).distance_to(kyiv.point) < 2.5: put(unit, Vector2(unit.node.position.x, unit.node.position.z) + Vector2(40, 40))
	var defender: Dictionary = theirs[0]
	put(defender, CitySystem.plaza_point(kyiv.point) + Vector2(0.38, 0.2))
	var attacker: Dictionary = mine[1]
	put(attacker, city_hub + Vector2(0.05, -0.32))
	defender.health = 100.0
	attacker.health = 100.0
	var was: String = city_province.controller
	game.match_rules.advance(0.2)
	check(city_province.controller == was, "Kyiv is not taken while its defenders stand in it (holder %s)" % city_province.controller)
	put(defender, Vector2(defender.node.position.x, defender.node.position.z) + Vector2(40, 40))
	game.match_rules.advance(0.2)
	check(city_province.controller == "russia", "with the defenders gone the city is taken")

	# 4. The country name moves with the land it holds.
	var label_before: Vector3 = game.cities.national_labels[1].get_child(0).position
	for t in game.map.territories:
		if t.playable and t.owner == "ukraine" and t.center.x > kyiv.point.x: game.match_rules.change_control(t, "russia")
	await process_frame
	await process_frame
	var label_after: Vector3 = game.cities.national_labels[1].get_child(0).position
	check(label_after.distance_to(label_before) > 0.05, "RUSSIA moves over the captured land (%.2f)" % label_after.distance_to(label_before))
	check(game.cities.national_labels[0].get_child(0).no_depth_test, "country names are drawn on top, so they never flicker")

	# 5. Armies that reach a friendly army in a battle join its stack.
	var front: = start + Vector2(0.3, 0.3)
	var enemy: Dictionary = theirs[1]
	put(enemy, front)
	put(mine[2], front + Vector2(0.4, 0))
	put(mine[3], front + Vector2(0.0, 0.42))
	mine[2].health = 100.0
	mine[3].health = 100.0
	enemy.health = 100.0
	units.advance(0.01)
	units.advance(0.01)
	check(mine[2].stack_id == mine[3].stack_id, "two armies fighting the same enemy side by side become one stack")
	var fighting_leader: Dictionary = units.stacks.leader(units.stacks.members(mine[2]))
	check(fighting_leader.engaged and fighting_leader.has("foe_point"), "the army in battle knows where its enemy stands")

	# 6. The battle shows: shots fly between the armies.
	game.combat_effects._skirmish(2.0)
	game.combat_effects._skirmish(2.0)
	check(game.combat_effects.projectiles.any(func(p): return p.effect == "skirmish"), "armies in battle keep firing at each other")
	put(enemy, front + Vector2(40, 40))
	put(mine[2], start + Vector2(-3, 0))

	# 7. Aircraft: refuel for 30 minutes at 1x, then go back for the same target.
	var planes: Array = units.units.filter(func(u): return u.country == "russia" and units.air.is_air(u))
	check(not planes.is_empty(), "Russia has an aircraft")
	if not planes.is_empty():
		var plane: Dictionary = planes[0]
		check(is_equal_approx(AirOperations.REFUEL_SECONDS * SimulationClock.REAL_SECONDS_PER_SIM_SECOND, 1800.0), "refuelling takes 30 real minutes at 1x")
		var base: Vector2 = units.air.base(plane).point
		var target: Dictionary = theirs[2]
		put(target, base + Vector2(1.5, 0.5))
		target.health = 100.0
		plane.flight_mode = "grounded"
		plane.moving = false
		plane.refuel_remaining = 0.5
		plane.repeat_target = target.id
		units._refuel_crew(plane)
		var crew: Node3D = plane.node.get_node_or_null("RefuelCrew")
		check(crew != null and crew.visible and (crew.get_node("Timer") as Label3D).text.begins_with("REFUELING"), "a refuelling plane shows its fuel truck and the time left")
		units.air.advance(plane, 0.6)
		check(plane.flight_mode == "attack" and plane.attack_target == target.id, "refuelled after a strike, it flies back at the same target")
		units.select_unit(units.units.find(plane))
		units.stop_selected()
		check(str(plane.get("repeat_target", "")).is_empty(), "a new order (Return) ends the repeat strikes")

	check(is_equal_approx(AirBattleSystem.PATROL_DAMAGE, 0.65), "patrols strike at 65% damage")
	# 9. Times follow the game speed.
	game.clock.set_speed(1.0)
	var one: = SimulationClock.duration(15.0)
	game.clock.set_speed(4.0)
	var four: = SimulationClock.duration(15.0)
	check(one == "30m 00s" and four == "7m 30s", "a 30-minute job shows 30m at 1x and 7m 30s at 4x (%s / %s)" % [one, four])
	game.clock.set_speed(1.0)

	# 10. Stand-in models are never empty.
	for kind in ["armor", "ifv", "artillery", "air_defense", "missile_launcher", "infantry", "fighter", "naval"]:
		var model: Node3D = UnitVisual._fallback(Node3D.new(), kind, "")
		check(model.get_child_count() > 0 and UnitVisual.model_bounds(model, 0.0).size.length() > 0.2, "a %s that cannot be loaded yet is drawn as a simple model" % kind)
		model.free()

	# 11. Finished buildings stand outside the houses; the bare square follows the garden.
	check(CitySystem.GARRISON_CLEAR_RADIUS <= 0.5, "the cleared square is garden-sized")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
