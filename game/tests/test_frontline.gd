extends SceneTree
## Entrenchment, retreat and annexation (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_frontline.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var rules: MatchSystem = game.match_rules
	var units: UnitSystem = game.units
	# Entrenchment.
	var tank: Dictionary = {}
	for unit in units.units:
		if unit.country == "russia" and unit.visual_kind == "armor" and not unit.moving: tank = unit
	var hub: Vector2 = Vector2.INF
	for title in game.map.province_hubs:
		var h: Vector2 = game.map.province_hubs[title]
		for t in game.map.territories:
			if t.title == title and t.controller == "russia" and (hub == Vector2.INF or h.distance_to(Vector2(tank.node.position.x, tank.node.position.z)) < hub.distance_to(Vector2(tank.node.position.x, tank.node.position.z))): hub = h
	tank.node.position = Vector3(hub.x, tank.node.position.y, hub.y)
	var before: = TerrainRules.unit_factor(tank, "defense")
	rules._update_entrenchment(MatchSystem.ENTRENCH_TIME * 0.5)
	check(not tank.entrenched, "an army needs time to dig in")
	rules._update_entrenchment(MatchSystem.ENTRENCH_TIME * 0.6)
	check(tank.entrenched and is_equal_approx(TerrainRules.unit_factor(tank, "defense"), before * MatchSystem.ENTRENCH_BONUS), "an army dug in at a province centre defends 25% harder")
	check(is_equal_approx(TerrainRules.unit_factor(tank, "attack"), TerrainRules.unit_factor(tank, "attack")) and TerrainRules.unit_factor(tank, "attack") < TerrainRules.unit_factor(tank, "defense"), "entrenchment helps defence, not attack")
	tank.moving = true
	rules._update_entrenchment(1.0)
	check(not tank.entrenched, "moving out ends entrenchment")
	tank.moving = false
	# Retreat.
	rules.declare_war()
	units.select_unit(units.units.find(tank))
	tank.engaged = true
	tank.health = 80.0
	game.retreat_selected()
	check(tank.moving and tank.fire_mode == "hold" and is_equal_approx(tank.health, 72.0), "retreating under fire costs 10% health, holds fire and moves off")
	var goal: Vector2 = tank.target
	var friendly_goal: bool = game.map.territories.any(func(t: Dictionary): return t.controller == "russia" and game.map.province_hubs.get(t.title, Vector2.INF).distance_to(goal) < 0.01)
	check(friendly_goal, "the army retreats to a friendly province centre")
	# Annexation.
	var city: Dictionary = {}
	for c in rules.cities:
		if c.country == "Ukraine" and not c.get("capital", false) and city.is_empty(): city = c
	var province: Dictionary = {}
	for t in game.map.territories:
		if t.id == city.sector: province = t
	province.controller = "russia"
	game.map.update_relations(true)
	var economy: ProductionSystem = game.production
	var funds_before: float = economy.stockpiles.russia.funds
	economy.earned.clear()
	economy.advance(10.0)
	var occupied_income: float = economy.earned.russia.get("materials", 0.0)
	game.map.selected_id = province.id
	economy.stockpiles.russia.funds = 50.0
	game.annex_selected()
	check(rules.annexation.jobs.is_empty(), "annexing needs enough funds")
	economy.stockpiles.russia.funds = 100000.0
	game.annex_selected()
	check(rules.annexation.jobs.has(province.id) and economy.stockpiles.russia.funds < 100000.0, "annexing a captured province costs funds and starts a one-day job")
	rules.annexation.advance(Annexation.ANNEX_TIME * 0.5, game.map.territories)
	check(not rules.annexation.annexed.has(province.id), "annexation takes a full day")
	rules.annexation.advance(Annexation.ANNEX_TIME * 0.6, game.map.territories)
	check(rules.annexation.annexed.get(province.id, "") == "russia", "after a day the province is annexed")
	economy.earned.clear()
	economy.advance(10.0)
	var annexed_income: float = economy.earned.russia.get("materials", 0.0)
	check(annexed_income > occupied_income, "annexed land produces more than occupied land (%.2f > %.2f)" % [annexed_income, occupied_income])
	check(not game.map._occupied(province), "annexed land loses its occupation stripes")
	var saved: = rules.snapshot()
	rules.annexation.restore({})
	rules.restore(saved)
	check(rules.annexation.annexed.get(province.id, "") == "russia", "annexations are saved")
	province.controller = "ukraine"
	rules.annexation.advance(1.0, game.map.territories)
	check(not rules.annexation.annexed.has(province.id), "losing the province ends the annexation")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
