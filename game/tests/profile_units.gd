extends SceneTree
## Owner 2026-10-13: "it's lagging on just my screen with 20 units". Puts 20 armies on screen
## at normal zoom with the clock running and times each per-frame system separately.
##   xvfb-run -a godot --path . --script tests/profile_units.gd
func _initialize() -> void: call_deferred("run")

func timed(label: String, totals: Dictionary, callable: Callable) -> void:
	var t0: = Time.get_ticks_usec()
	callable.call()
	totals[label] = totals.get(label, 0) + Time.get_ticks_usec() - t0

func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.match_rules.ai_enabled = false
	var moscow: Vector2 = game.buildings.city("moscow").point
	# 20 armies around Moscow, a mix of families like a real game.
	var families: Array = EquipmentIdentity.catalog.filter(func(f): return f.country == "russia" and not f.get("retired", false) and f.visual_kind not in ["naval"])
	for i in 20:
		var family: Dictionary = families[i % families.size()]
		var at: = moscow + Vector2.from_angle(i * 0.9) * (0.6 + 0.12 * i)
		game.units._spawn({"id": "p%d" % i, "name": family.name, "country": "russia", "equipment_id": family.id, "level": 1 + i % 5,
			"visual_kind": family.visual_kind, "base_city": "moscow"}, at, Color("ef827c"))
	game.rig.target = Vector3(moscow.x, 0, moscow.y)
	game.rig.distance = 14.0
	game.rig._snap(1.0)
	for i in 60: await process_frame  # let models load
	game.clock.paused = false
	# Take the per-frame systems over so each can be timed.
	var systems: = {"units": game.units, "badges": game.badges, "cities": game.cities, "fog": game.get("fog"), "effects": game.combat_effects, "resource_sites": game.resource_sites, "main": game}
	for key in systems.keys():
		if systems[key] == null or not systems[key].has_method("_process"): systems.erase(key)
		else: systems[key].set_process(false)
	game.clock.set_process(false)
	var totals: = {}
	var frames: = 120
	var delta: = 1.0 / 30.0
	var t_start: = Time.get_ticks_usec()
	var draw_calls: = 0.0
	var primitives: = 0.0
	for f in frames:
		timed("clock (economy, battles, AI, trade)", totals, func(): game.clock.advance(delta))
		for key in systems: timed(key, totals, func(): systems[key]._process(delta))
		await process_frame
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var wall: float = (Time.get_ticks_usec() - t_start) / 1000.0 / frames
	print("PROFILE units=", game.units.units.size(), " visible models=", game.units.units.filter(func(u): return u.node.visible).size())
	var keys: Array = totals.keys()
	keys.sort_custom(func(a, b): return totals[a] > totals[b])
	for key in keys: print("PROFILE  %-40s %7.2f ms/frame" % [key, totals[key] / 1000.0 / frames])
	print("PROFILE  frame wall time (incl. render)   %7.2f ms" % wall)
	print("PROFILE  draw calls %.0f   triangles %.0f" % [draw_calls / frames, primitives / frames])
	quit()
