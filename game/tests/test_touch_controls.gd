extends SceneTree
## Touch-control checks in portrait (540x1200), driven by real InputEventScreenTouch/Drag
## events through Input.parse_input_event, as a phone would send them.
##   godot --path . --script tests/test_touch_controls.gd [-- <screenshot_dir>]
var failures: Array[String] = []
var shots: = ""
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func frames(count: int = 2) -> void:
	for i in count: await process_frame
## Test positions are in the game's (scaled, portrait) coordinates; a phone reports raw
## window pixels, so convert like a real touch would arrive.
func to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos
func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event: = InputEventScreenTouch.new()
	event.index = index
	event.position = to_window(pos)
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)
func drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event: = InputEventScreenDrag.new()
	event.index = index
	event.position = to_window(pos)
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	await frames(1)
func tap(pos: Vector2) -> void:
	await touch(0, pos, true)
	await touch(0, pos, false)
	await frames(2)
func snap(name: String) -> void:
	if shots.is_empty(): return
	await frames(6)
	root.get_texture().get_image().save_png(shots + "/" + name + ".png")
func run() -> void:
	ArsenalFixture.use_archive()  # live arsenal is empty until the new weapons arrive
	var args: = OS.get_cmdline_user_args()
	if args.size() > 0: shots = args[0]
	root.size = Vector2i(540, 1200)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.mobile_start.hide()
	game.apply_player_country()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	var focus: Vector3 = game.map_position(36.6, 50.3)
	game.rig.target = Vector3(focus.x, 0, focus.z)
	game.rig.distance = 14
	game.rig._snap(1.0)
	await frames(4)
	check(get_root().get_window().content_scale_size.x < get_root().get_window().content_scale_size.y or ProjectSettings.get_setting("display/window/handheld/orientation") == 1, "portrait orientation configured")
	await snap("touch_1_map")

	# 1. Tap an army to select it.
	var camera: Camera3D = game.rig.camera
	var target: = -1
	var best: = INF
	for i in game.units.units.size():
		var unit: Dictionary = game.units.units[i]
		if unit.country != "russia" or not unit.node.visible: continue
		var on_screen: = camera.unproject_position(unit.node.global_position)
		var distance: = on_screen.distance_to(root.get_visible_rect().size * 0.5)
		if distance < best:
			best = distance
			target = i
	check(target >= 0, "a Russian army is on screen")
	var army_point: = camera.unproject_position(game.units.units[target].node.global_position)
	game.units.selected = -1
	await tap(army_point)
	check(game.units.selected >= 0 and game.units.units[game.units.selected].stack_id == game.units.units[target].stack_id, "tap selects the army")
	check(game.hud.action_row.visible and not game.hud.nav_row.visible, "army sheet with order buttons replaces the tab bar")
	await snap("touch_2_selected")

	# 2. Move order: Move button, then tap a destination; the path is drawn.
	game.hud.move_requested.emit()
	check(game.order_mode, "Move enters destination mode")
	await tap(army_point + Vector2(-120, 160))
	var unit: Dictionary = game.units.units[game.units.selected]
	check(unit.moving, "tapping a destination issues the move")
	check(game.units.route.visible and game.units.route.mesh != null, "movement path is drawn")
	await snap("touch_3_path")
	var start: Vector3 = unit.node.position
	game.units.advance(0.5)
	check(unit.node.position.distance_to(start) > 0.01, "army moves along its path")

	# 3. One-finger drag pans the map.
	var before: Vector3 = game.rig.target
	await touch(0, Vector2(270, 700), true)
	for step in 6: await drag(0, Vector2(270 + step * 20, 700 + step * 10), Vector2(20, 10))
	await touch(0, Vector2(390, 760), false)
	check(game.rig.target.distance_to(before) > 0.2, "one-finger drag pans the map")
	check(game.units.selected >= 0, "dragging does not drop the selection")

	# 4. Two-finger pinch zooms.
	var distance_before: float = game.rig.distance
	await touch(0, Vector2(220, 600), true)
	await touch(1, Vector2(320, 600), true)
	for step in 6:
		await drag(0, Vector2(220 - step * 15, 600), Vector2(-15, 0))
		await drag(1, Vector2(320 + step * 15, 600), Vector2(15, 0))
	await touch(0, Vector2(145, 600), false)
	await touch(1, Vector2(395, 600), false)
	check(game.rig.distance < distance_before * 0.8, "pinch out zooms in")
	check(game.units.selected >= 0, "pinch does not trigger a tap")

	# 5. No floating identification labels: tags carry only a count.
	var labelled: = 0
	for button in game.badges.buttons.values():
		if button.visible and not button.text.is_valid_int(): labelled += 1
	check(labelled == 0, "unit tags show counts only, no names over units")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
