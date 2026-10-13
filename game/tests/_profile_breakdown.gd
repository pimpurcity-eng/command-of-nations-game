extends SceneTree
func _initialize() -> void: call_deferred("run")
func stats() -> Array:
	for i in 3: await process_frame
	return [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)]
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.match_rules.ai_enabled = false
	var moscow: Vector2 = game.buildings.city("moscow").point
	var families: Array = EquipmentIdentity.catalog.filter(func(f): return f.country == "russia" and not f.get("retired", false) and f.visual_kind not in ["naval"])
	for i in 20:
		var family: Dictionary = families[i % families.size()]
		game.units._spawn({"id": "p%d" % i, "name": family.name, "country": "russia", "equipment_id": family.id, "level": 1 + i % 5, "visual_kind": family.visual_kind, "base_city": "moscow"}, moscow + Vector2.from_angle(i * 0.9) * (0.6 + 0.12 * i), Color("ef827c"))
	game.rig.target = Vector3(moscow.x, 0, moscow.y)
	game.rig.distance = 14.0
	game.rig._snap(1.0)
	for i in 60: await process_frame
	var all: Array = await stats()
	print("RENDER all: calls=%d tris=%d" % all)
	for node_name in game.get_children().map(func(c): return c.name):
		var node = game.get_node(NodePath(node_name))
		if not node is Node3D or not node.visible: continue
		node.visible = false
		var s: Array = await stats()
		node.visible = true
		print("RENDER without %-24s calls -%d tris -%d" % [node_name, all[0] - s[0], all[1] - s[1]])
	for node_name in game.map.get_children().map(func(c): return c.name):
		var node = game.map.get_node(NodePath(node_name))
		if not node is Node3D or not node.visible: continue
		node.visible = false
		var s: Array = await stats()
		node.visible = true
		if all[0] - s[0] > 20 or all[1] - s[1] > 20000: print("RENDER without map/%-20s calls -%d tris -%d" % [node_name, all[0] - s[0], all[1] - s[1]])
	# Simulation systems one by one (one 10 Hz tick of game time).
	var seconds: = 0.1 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	game.clock.paused = false
	var parts: = {"units.advance": func(): game.units.advance(seconds), "match_rules.advance": func(): game.match_rules.advance(seconds),
		"production.advance": func(): game.production.advance(seconds), "buildings.advance": func(): game.buildings.advance(seconds),
		"research.advance": func(): game.research.advance(seconds), "trade.advance": func(): game.trade.advance(seconds)}
	for key in parts:
		var t0: = Time.get_ticks_usec()
		for i in 20: parts[key].call()
		print("TICK %-22s %6.2f ms" % [key, (Time.get_ticks_usec() - t0) / 1000.0 / 20])
	var t1: = Time.get_ticks_usec()
	for i in 20: game.clock.advanced.emit(seconds)
	print("TICK %-22s %6.2f ms" % ["all listeners", (Time.get_ticks_usec() - t1) / 1000.0 / 20])
	for c in game.clock.advanced.get_connections(): print("TICK listener ", c.callable.get_object(), " ", c.callable.get_method())
	quit()
