extends SceneTree
## Owner 2026-10-16 pacing review: slower Call of War marches, own-territory and rail speed,
## game speed on every timer, 30-minute level-1 buildings, 30 min - 2 h level-1 research, every
## unit family (nuclear excepted) researchable by day 6, and victories that explain themselves.
##   xvfb-run -a godot --path . --script tests/test_oct16_pacing.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")

## Real seconds at 1x for `group` to follow `path` from `start`.
func march(units: UnitSystem, group: Array, start: Vector2, path: Array) -> float:
	var seconds: = 0.0
	var previous: = start
	for point in path:
		var length: float = previous.distance_to(point)
		var samples: = maxi(1, ceili(length / 0.1))
		for i in samples: seconds += length / samples / units.stacks.movement_speed(group, previous.lerp(point, (i + 0.5) / samples))
		previous = point
	return seconds * SimulationClock.REAL_SECONDS_PER_SIM_SECOND

func run() -> void:
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	if game.mobile_start != null: game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var units: UnitSystem = game.units
	var kyiv: Dictionary = game.buildings.city("kyiv")
	var kharkiv: Dictionary = game.buildings.city("kharkiv")
	var infantry: Dictionary = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")[0]
	var tank: Dictionary = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "armor")[0]

	# 1. March pace (was 20 min Kyiv-Kharkiv and about 5 min a province for infantry at 1x).
	var path: Array = units.navigation.find_path(kyiv.point, kharkiv.point, "infantry", "ukraine")
	var infantry_time: = march(units, [infantry], kyiv.point, path)
	var tank_time: = march(units, [tank], kyiv.point, units.navigation.find_path(kyiv.point, kharkiv.point, "armor", "ukraine"))
	print("Kyiv-Kharkiv at 1x: infantry %s, tank %s" % [SimulationClock.duration(infantry_time / 120.0, 1.0), SimulationClock.duration(tank_time / 120.0, 1.0)])
	check(infantry_time >= 3.0 * 3600.0 and infantry_time <= 8.0 * 3600.0, "infantry marches Kyiv-Kharkiv in 3-8 real hours at 1x (%.1f h)" % (infantry_time / 3600.0))
	check(tank_time < infantry_time, "armour is faster than infantry")
	var province_minutes: float = 3.0 / units.stacks.movement_speed([infantry], kyiv.point) * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 60.0
	check(province_minutes >= 45.0 and province_minutes <= 150.0, "infantry crosses a 3-unit province in about 1-2 hours at 1x (%d min)" % roundi(province_minutes))
	check(SimulationClock.MOVEMENT_PACE == 1.0 and is_equal_approx(AirOperations.REFUEL_SECONDS * SimulationClock.REAL_SECONDS_PER_SIM_SECOND, 1800.0), "aircraft pace and the 30-minute refuel are unchanged")

	# 2. Own land is faster, enemy land slower; railways double it; the route planner knows.
	var at_home: float = units.stacks.movement_speed([infantry], kharkiv.point)
	var invader: Dictionary = infantry.duplicate()
	invader.country = "russia"
	var abroad: float = units.stacks.movement_speed([invader], kharkiv.point)
	check(is_equal_approx(at_home / abroad, TerrainRules.OWN_TERRITORY_SPEED / TerrainRules.FOREIGN_TERRITORY_SPEED), "own territory +25%%, enemy territory -20%% (%.3f vs %.3f)" % [at_home, abroad])
	check(TerrainRules.territory_label(1.25) == "own territory +25%", "the HUD names the own-territory bonus")
	var factors: Array = units.stacks.speed_factors([infantry], kharkiv.point)
	check(factors.any(func(f): return f[0] == "territory" and is_equal_approx(f[1], 1.25)), "the army panel lists the territory factor")
	check(ArmyStacks.km_per_hour(at_home) > 20.0 and ArmyStacks.km_per_hour(at_home) < 150.0, "army speed reads in km/h (%d km/h)" % roundi(ArmyStacks.km_per_hour(at_home)))
	var trade: TradeNetwork = game.trade
	game.buildings.levels.kyiv.train_station = 1
	game.buildings.levels.kharkiv.train_station = 1
	game.buildings.changed.emit()
	check(trade.rail_factor(kyiv.point, "ukraine") == 2.0, "a rail line between two stations runs through Kyiv")
	var by_rail: float = units.stacks.movement_speed([infantry], kyiv.point)
	TradeNetwork.active = null
	var on_foot: float = units.stacks.movement_speed([infantry], kyiv.point)
	TradeNetwork.active = trade
	check(is_equal_approx(by_rail, on_foot * 2.0), "the train is twice as fast as walking")
	var node: int = units.navigation.graph.get_closest_point(kyiv.point)
	check(is_equal_approx(units.navigation._node_speed(node, "infantry", "ukraine") / units.navigation._node_speed(node, "infantry", ""), TerrainRules.OWN_TERRITORY_SPEED * 2.0), "route planning prefers own land and railways")
	check(RailwayMap.TRACK_WIDTH >= 0.12, "railway tracks are drawn bigger")

	# 3. Game speed shortens every displayed and simulated time.
	infantry.waypoints = path.duplicate()
	infantry.target = kharkiv.point
	infantry.moving = true
	var eta: float = units.travel_time(infantry)
	check(SimulationClock.duration(eta, 1.0) != SimulationClock.duration(eta, 10.0) and SimulationClock.duration(3600.0 / 120.0, 4.0) == "15m 00s", "march ETA follows the game speed")
	infantry.moving = false
	infantry.waypoints.clear()
	game.clock.set_speed(4.0)
	check(SimulationClock.game_speed == 4.0 and VictoryRules.goal_text().contains("1h 30m"), "victory goal hold time shows real time at 4x")
	check(SimulationClock.duration(game.buildings.duration("factory", 1)) == "7m 30s", "a 30-minute factory shows 7m 30s at 4x")
	game.clock.set_speed(1.0)

	# 4. Buildings: level 1 takes 30 minutes at 1x, each later level twice as long.
	for building in game.buildings.catalog:
		if building.get("retired", false): continue
		var minutes: float = game.buildings.duration(building.id, 1) * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 60.0
		check(is_equal_approx(minutes, 30.0), "%s level 1 takes 30 min (%.1f)" % [building.id, minutes])
		if int(building.max_level) > 1: check(is_equal_approx(game.buildings.duration(building.id, 2), 2.0 * game.buildings.duration(building.id, 1)), building.id + " level 2 takes twice as long")

	# 5. Research: level 1 between 30 minutes and 2 hours, later levels longer; day 6 at the latest.
	var research: ResearchSystem = game.research
	var shortest: = INF
	var longest: = 0.0
	for spec in game.production.catalog:
		if spec.get("retired", false): continue
		var hours: float = research.duration(1, spec.id) * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 3600.0
		shortest = minf(shortest, hours)
		longest = maxf(longest, hours)
		check(hours >= 0.5 - 1e-6 and hours <= 2.0 + 1e-6, "%s level-1 research %.2f h" % [spec.id, hours])
		check(research.duration(5, spec.id) > research.duration(1, spec.id), spec.id + " higher levels take longer")
		var role: String = EquipmentEconomy.balance.families.get(str(spec.id), "")
		if role in ["silo", "strategic_missile"]: check(research.unlock_day(spec.id, 1) > 6, spec.id + " nuclear arms stay late")
		else: check(research.unlock_day(spec.id, 1) <= 6, "%s level 1 by day 6 (day %d)" % [spec.id, research.unlock_day(spec.id, 1)])
	check(is_equal_approx(shortest, 0.5) and is_equal_approx(longest, 2.0), "research spans 30 min (basic) to 2 h (advanced) at level 1")
	var ordered: Array = ProductionGroups.by_unlock_day(game.production.catalog.filter(func(s): return s.country == "ukraine"), research)
	var sorted_days: = true
	for i in ordered.size() - 1: sorted_days = sorted_days and research.unlock_day(ordered[i].id, 1) <= research.unlock_day(ordered[i + 1].id, 1)
	check(sorted_days, "research lists still sort by unlock day")

	# 6. Victory: destroying the armies alone no longer wins; the result explains the win.
	var rules: MatchSystem = game.match_rules
	check(is_equal_approx(VictoryRules.DOMINATION_HOLD, VictoryRules.DAY / 4.0), "domination must be held for six game hours")
	rules.at_war = true
	units.at_war = true
	for unit in units.units.filter(func(u): return u.country == "russia"):
		units.units.erase(unit)
		unit.node.queue_free()
	units.selected = -1
	units.command_ids.clear()
	rules.fielded["russia"] = true
	rules.production.jobs = rules.production.jobs.filter(func(j): return rules.production.equipment(j.equipment).country != "russia")
	rules.advance(0.01)
	check(rules.winner.is_empty(), "a country that lost its armies but holds Moscow is not eliminated")
	var moscow: Dictionary = game.buildings.capital("russia")
	for t in game.map.territories:
		if t.id == moscow.sector: t.controller = "ukraine"
	var survivors: Array = rules.production.stockpiles.keys().filter(func(c): return c != "russia" and rules._has_forces(c))
	rules.advance(0.01)
	if survivors.size() == 1: check(rules.winner == "ukraine" and rules.victory_type == "elimination", "armies, production and the capital lost: elimination")
	else: rules.end_match("ukraine", "elimination")
	var text: String = VictoryRules.explain(rules, "ukraine", "elimination")
	check(text.contains("took its capital") and text.contains("Moscow (capital)"), "the result explains the elimination (%s)" % text)
	check(VictoryRules.explain(rules, "ukraine", "domination").contains("enemy victory points"), "a domination result names the victory points")
	game.show_result("ukraine")
	check(game.result_dialog.dialog_text.begins_with("VICTORY") and game.result_dialog.dialog_text.contains("took its capital"), "the result screen says how the match was won")
	rules.victory.domination_held["ukraine"] = VictoryRules.DOMINATION_HOLD * 0.5
	game.refresh_hud()
	check(game.hud.score_label.text.contains("YOU WIN IN") and game.hud.score_label.tooltip_text.contains("Win: hold"), "the top bar shows the goal and the domination countdown (%s)" % game.hud.score_label.text)
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
