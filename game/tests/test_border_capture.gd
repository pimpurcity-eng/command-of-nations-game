extends SceneTree
## Owner 2026-10-14: "When I went onto the Ukrainian territory, I never declared war. It never
## switched over. When I declared war, it still never switched over."
##   xvfb-run -a godot --path . --script tests/test_border_capture.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
var game
func simulate(real_seconds: float) -> void:
	game.clock.paused = false
	while real_seconds > 0:
		game.clock.advance(1.0)
		real_seconds -= 1.0
		if real_seconds as int % 30 == 0: await process_frame
	game.clock.paused = true
func run() -> void:
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var rules = game.match_rules
	var donetsk: Dictionary = game.map.territories.filter(func(t): return t.playable and "Donetsk" in str(t.title) and t.controller == "ukraine")[0]
	var hub: Vector2 = rules.capture_point(donetsk)
	# Clear Ukrainian armies out of the province so the march is unopposed.
	for unit in game.units.units:
		if unit.country == "ukraine" and Vector2(unit.node.position.x, unit.node.position.z).distance_to(hub) < 2.0:
			unit.node.position += Vector3(30, 0, 30)
	var army: Dictionary = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")[0]
	check(not rules.at_war, "the match starts at peace")
	# Walk the army to the province centre (as the player's move order does).
	army.node.position = Vector3(hub.x + 0.05, army.node.position.y, hub.y)
	army.moving = false
	await simulate(2.0)
	check(rules.at_war, "marching onto Ukrainian land declares war")
	await simulate(15.0)
	var now: Dictionary = game.map.territories.filter(func(t): return t.id == donetsk.id)[0]
	check(now.controller == "russia", "Donetsk switches to Russia about 10 seconds after the army arrives (now %s)" % now.controller)
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
