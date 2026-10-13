extends SceneTree
## Owner 2026-10-13: infantry vehicles are Infantry and air defence is Ordnance; four units
## and four buildings per city queue; guard mode (sleep defence) defends but never attacks.
##   xvfb-run -a godot --path . --script tests/test_guard_queue.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	# Groups.
	check(ProductionGroups.index(EquipmentIdentity.spec("apcs_russia")) == 5 and ProductionGroups.building(EquipmentIdentity.spec("apcs_russia")) == "barracks", "infantry vehicles are Infantry, built in the barracks")
	check(ProductionGroups.index(EquipmentIdentity.spec("patriot_russia")) == 2 and ProductionGroups.index(EquipmentIdentity.spec("skyguard_ukraine")) == 2, "air defence is Ordnance")
	check(ProductionGroups.index(EquipmentIdentity.spec("tanks_russia")) == 3, "tanks stay Tanks")
	# Queues: four units, four buildings.
	for resource in ProductionSystem.RESOURCES: game.production.stockpiles.russia[resource] = 1000000
	for i in 4: check(game.production.schedule("infantry_russia", "Moscow").is_empty(), "unit order %d queues" % (i + 1))
	check(not game.production.schedule("infantry_russia", "Moscow").is_empty(), "a fifth unit order is refused")
	var queued: = 0
	for id in ["industry", "barracks", "tank_plant", "factory", "missile_factory"]:
		if game.buildings.schedule("moscow", id).is_empty(): queued += 1
	check(queued == 4, "four buildings queue, the fifth is refused (%d)" % queued)
	# Guard mode.
	var rules: MatchSystem = game.match_rules
	game.hud.guard_requested.emit()
	check(rules.guarded("russia") and game.hud.guard_button.text == "GUARD ON", "the GUARD button turns sleep defence on")
	check(rules.snapshot().guards == ["russia"], "guard mode is saved")
	var guard: DefenceAI = rules.guards.russia
	check(guard.decide(game.units, game.production.cities, game.production, 5.0).is_empty(), "at peace the guard does nothing")
	rules.declare_war()
	game.units.fog_enabled = false
	var kursk: Dictionary = game.buildings.city("kursk")
	var enemy: Dictionary = {}
	for u in game.units.units:
		if u.country == "ukraine" and u.visual_kind in ["armor", "ifv", "infantry"]: enemy = u
	var spot: Vector2 = kursk.point + Vector2(1.2, 0.4)
	for attempt in 12:
		if game.units.navigation.controller_at(spot) == "russia": break
		spot = kursk.point + Vector2.from_angle(attempt * 0.6) * 1.4
	enemy.node.position = Vector3(spot.x, enemy.node.position.y, spot.y)
	enemy.moving = false
	var before: Array = game.units.units.filter(func(u): return u.country == "russia" and u.moving).map(func(u): return u.id)
	guard.timer = 0.0
	var said: = guard.decide(game.units, game.production.cities, game.production, 5.0)
	var responders: Array = game.units.units.filter(func(u): return u.country == "russia" and u.moving and not u.id in before)
	check(not responders.is_empty(), "an enemy inside Russia makes the guard send defenders (" + said + ")")
	check(responders.all(func(u): return game.units.navigation.controller_at(u.target) == "russia" and u.waypoints.all(func(p): return game.units.navigation.controller_at(p) == "russia")), "defenders never leave Russian land")
	check(game.units.units.filter(func(u): return u.country == "russia" and u.moving).size() - before.size() <= DefenceAI.MAX_RESPONDERS * 2, "only a few armies respond")
	var saved: = rules.snapshot()
	rules.set_guard("russia", false)
	check(not rules.guarded("russia") and game.hud.guard_button.text == "GUARD", "guard can be switched off")
	rules.restore(saved)
	check(rules.guarded("russia"), "loading a save restores guard mode")
	# An away player under guard is defended, not sent on the attack.
	rules.set_ai_countries(["russia", "ukraine"])
	check(rules.seat_ai.has("russia") and rules.guarded("russia"), "a guarded seat keeps the defence AI")
	print("FAILURES ", failures)
	quit(1 if failures > 0 else 0)
