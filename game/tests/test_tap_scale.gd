extends SceneTree
## Fix 11 (owner 2026-10-16, "units easier to tap"): on a phone screen twice the 720 px layout,
## the army tap reach, city reach and tap wobble grow with the screen so they stay finger-sized.
##   xvfb-run -a godot --path . --script tests/test_tap_scale.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(720, 1440)
	root.size = Vector2i(1440, 2880)  # a high-resolution phone: twice the layout
	UnitSystem.force_mobile = true
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var scale: float = TapScale.of(game.units)
	check(absf(scale - 2.0) < 0.05, "tap scale follows the screen (%.2f, expected 2.00)" % scale)
	var at: Vector2 = game.buildings.city("kursk").point
	game.rig.target = Vector3(at.x, 0, at.y)
	game.rig.distance = 20.0
	for i in 90: await process_frame
	# An own army on screen, away from any city so the town does not take the tap.
	var camera: Camera3D = game.rig.camera
	var army: Dictionary = {}
	var armies_seen: = 0
	for group in game.units.stacks.groups():
		var leader: Dictionary = game.units.stacks.leader(group)
		if leader.country != "russia" or not game.units.visible_to_player(leader): continue
		var p: Vector2 = camera.unproject_position(leader.node.global_position + Vector3.UP * 0.2)
		if not Rect2(Vector2(100, 200), Vector2(1240, 2480)).has_point(p): continue
		armies_seen += 1
		if not game.cities.pick_screen(p + Vector2(0, -200)).is_empty(): continue
		army = leader
		break
	check(not army.is_empty(), "found an own army on screen to tap, away from a town (%d on screen)" % armies_seen)
	if not army.is_empty():
		var centre: Vector2 = camera.unproject_position(army.node.global_position + Vector3.UP * 0.2)
		# Step away from the model until the finger is just off it, then 60 real px further:
		# inside the 44 px (x2) reach on this screen, outside the old unscaled 44 px.
		var off: = centre
		while game.units.pick_all_screen(camera, off).any(func(h): return h.inside): off += Vector2(0, -4)
		var tap: = off + Vector2(0, -60)
		var hits: Array = game.units.pick_all_screen(camera, tap)
		check(hits.any(func(h): return game.units.units[h.index].id == army.id), "a tap a fingertip away from the army still picks it")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
