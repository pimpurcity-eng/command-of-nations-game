extends SceneTree
## Owner 2026-10-13 (night): enemy turns red at war (also under fog); armies only fight when
## they touch; the city list holds only your own cities (all seven).
##   xvfb-run -a godot --path . --script tests/test_owner_night.gd
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
	var choices: Array = game.hud.city_choices.call()
	check(choices.size() == 7 and choices.all(func(c): return game.production.controlled(game.cities.cities[c[1]], "russia")), "city list: the seven Russian cities only (%d)" % choices.size())
	check(str(choices[0][0]).contains("Capital"), "capital first")
	game.hud.declare_war_requested.emit()
	var hostile: = 0
	for t in game.map.territories:
		if t.playable and t.controller == "ukraine" and game.map.materials[t.id].get_shader_parameter("hostile"): hostile += 1
	check(hostile > 20, "Ukraine turns red the moment war is declared (%d)" % hostile)
	# Armies in Belgorod and Kharkiv do not fight; they are not touching.
	var belgorod: Vector2 = game.buildings.city("belgorod").point
	var kharkiv: Vector2 = game.buildings.city("kharkiv").point
	var ours: Array = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")
	var theirs: Array = game.units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")
	ours[0].node.position = Vector3(belgorod.x, ours[0].node.position.y, belgorod.y)
	theirs[0].node.position = Vector3(kharkiv.x, theirs[0].node.position.y, kharkiv.y)
	ours[0].moving = true
	ours[0].target = belgorod
	var before: float = theirs[0].health
	game.units.fog_enabled = false
	for i in 60: game.clock.paused = false; game.clock.advance(60.0)
	check(theirs[0].health == before, "no fighting between armies a city apart (%.0f%%)" % theirs[0].health)
	# Country traits (owner 2026-10-14): one strength, one weakness, some unlock early.
	var ru: Dictionary = EquipmentIdentity.spec("infantry_russia")
	var ua: Dictionary = EquipmentIdentity.spec("infantry_ukraine")
	check(float(ru.cost.funds) < float(ua.cost.funds), "Russian units are cheaper (%d vs %d)" % [ru.cost.funds, ua.cost.funds])
	check(game.research.rate("russia") < game.research.rate("ukraine"), "but Russia researches slower")
	check(int(EquipmentIdentity.spec("drones_ukraine").cost.funds) < int(EquipmentIdentity.spec("drones_russia").cost.funds) / 0.85, "Ukrainian drones are cheaper")
	check(not CountryTraits.summary("china").is_empty() and not CountryTraits.summary("united_states").is_empty() and not CountryTraits.summary("france").is_empty(), "China, America and Europe have traits ready")
	# Build times (owner 2026-10-14): level 1 about 15 minutes, never over 30; higher levels take longer.
	var minutes: = func(id: String, level: int) -> float: return game.buildings.duration(id, level) * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 60.0
	var slowest: = 0.0
	for building in game.buildings.catalog: slowest = maxf(slowest, minutes.call(building.id, 1))
	# Owner 2026-10-16: every level-1 building takes 30 minutes at 1x.
	check(is_equal_approx(minutes.call("recruitment_center", 1), 30.0) and is_equal_approx(minutes.call("industry", 1), 30.0), "level-1 recruitment and industry take 30 min")
	check(is_equal_approx(minutes.call("barracks", 1), 30.0) and slowest <= 30.0, "no level-1 building takes over 30 minutes")
	check(minutes.call("recruitment_center", 2) > minutes.call("recruitment_center", 1) and minutes.call("recruitment_center", 5) > minutes.call("recruitment_center", 4), "every higher level takes longer")
	# Owner 2026-10-16: every resource starts at the same amount (it was 60,000 money before).
	check(ProductionSystem.START_STOCK.values().all(func(v): return v == ProductionSystem.START_STOCK.funds), "every resource starts at the same amount")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
