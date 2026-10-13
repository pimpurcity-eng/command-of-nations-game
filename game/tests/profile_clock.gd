extends SceneTree
## Times each system the game clock drives (economy, battles, AI, trade, ...) at the Call of
## War start army. The clock dispatches these 10 times a second.
##   xvfb-run -a godot --path . --script tests/profile_clock.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = false
	game.match_rules.declare_war()
	var totals: = {}
	var connections: Array = game.clock.advanced.get_connections()
	var step: = 0.1 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	for i in 100:
		for c in connections:
			var callable: Callable = c.callable
			var label: = str(callable.get_object().get_script().resource_path.get_file() if callable.get_object() != null and callable.get_object().get_script() != null else "?") + ":" + str(callable.get_method())
			var t0: = Time.get_ticks_usec()
			callable.call(step)
			totals[label] = totals.get(label, 0) + Time.get_ticks_usec() - t0
	var keys: Array = totals.keys()
	keys.sort_custom(func(a, b): return totals[a] > totals[b])
	for key in keys: print("CLOCK %-55s %7.2f ms per tick" % [key, totals[key] / 1000.0 / 100.0])
	quit()
