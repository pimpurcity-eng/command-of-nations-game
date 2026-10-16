extends SceneTree
## Owner 2026-10-16: changing game speed must affect actual work and movement, not just labels.
var failures := 0
var checks := 0
var baseline: Dictionary = {}
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	for speed in SimulationClock.SPEEDS:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		if not game.boot_finished: await game.boot_ready
		game.mobile_start.hide()
		game.clock.set_process(false)
		game.clock.paused = true
		game.match_rules.ai_enabled = false
		game.clock.set_speed(speed)
		for country in game.production.stockpiles:
			for resource in ProductionSystem.RESOURCES: game.production.stockpiles[country][resource] = 1.0e9
		var city: Dictionary = game.buildings.capital("russia")
		var infantry: Dictionary = game.production.catalog.filter(func(s): return s.country == "russia" and s.visual_kind == "infantry" and not s.get("retired", false))[0]
		game.research.levels[infantry.id] = 1
		for building in infantry.get("building_requirements", {}): game.buildings.levels[city.id][building] = infantry.building_requirements[building]
		check(game.production.enqueue(infantry.id, city.name).is_empty(), "production starts at %sx" % speed)
		check(game.buildings.enqueue(city.id, "industry", "russia").is_empty(), "construction starts at %sx" % speed)
		var research: Dictionary = game.production.catalog.filter(func(s): return s.country == "russia" and s.id != infantry.id and game.research.reason(s.id, 1, "russia").is_empty())[0]
		check(game.research.start(research.id, 1, "russia").is_empty(), "research starts at %sx" % speed)
		var army: Dictionary = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")[0]
		game.units.select_unit(game.units.units.find(army))
		var start: Vector3 = army.node.position
		var goal: Vector2 = Vector2(start.x, start.z)
		for hub in game.map.province_hubs.values():
			if hub.distance_to(goal) > 0.5 and game.units.navigation.controller_at(hub) == "russia":
				goal = hub
				break
		check(game.units.order(Vector3(goal.x, 0, goal.y)), "movement starts at %sx" % speed)
		game.clock.paused = false
		# Ten real clock dispatches; all speeds advance exactly one game-clock second.
		for tick in 10: game.clock.advance(12.0 / speed)
		game.clock.paused = true
		var actual := {"production": float(game.production.jobs[0].progress), "building": float(game.buildings.jobs[0].progress), "research": float(game.research.jobs[0].progress), "movement": army.node.position.distance_to(start), "time": game.clock.elapsed}
		check(actual.production > 0 and actual.building > 0 and actual.research > 0 and actual.movement > 0, "actual work and movement advance at %sx" % speed)
		if baseline.is_empty(): baseline = actual.duplicate()
		for key in baseline: check(is_equal_approx(actual[key], baseline[key]), "%s uses the same scaled clock at %sx" % [key, speed])
		var job: Dictionary = game.buildings.jobs[0]
		var left: float = game.buildings.construction_time(city.id, "industry", 1, job.progress)
		game.clock.paused = false
		game.clock.advance((left - 0.001) * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / speed)
		check(game.buildings.level(city.id, "industry") == 0, "building remains unfinished just before its shown deadline at %sx" % speed)
		game.clock.advance(0.002 * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / speed)
		check(game.buildings.level(city.id, "industry") == 1, "building completes at the shown deadline at %sx" % speed)
		game.clock.paused = true
		game.queue_free()
		await process_frame
	print("RESULT SPEED_CONSISTENCY checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
