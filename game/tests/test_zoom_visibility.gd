extends SceneTree
## Owner 2026-10-13: "if you zoom in and zoom back out, some units aren't showing back up" and
## "when I zoom out I can't even see the enemy on my territory". Runs the phone model budget.
##   xvfb-run -a godot --path . --script tests/test_zoom_visibility.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
var game
func shown(unit: Dictionary) -> bool:
	var button: Control = game.badges.buttons.get(unit.id)
	return unit.node.visible or (button != null and button.visible)
func check_all(label: String) -> void:
	var camera: Camera3D = game.rig.camera
	var view: Rect2 = root.get_visible_rect().grow(-120)
	var missing: Array = []
	for group in game.units.stacks.groups():
		var leader: Dictionary = game.units.stacks.leader(group)
		if not game.units.visible_to_player(leader): continue
		var p: Vector3 = leader.node.global_position
		if camera.is_position_behind(p) or not view.has_point(camera.unproject_position(p)): continue
		if not shown(leader): missing.append(leader.id)
	check(missing.is_empty(), label + " - every army on screen is shown (missing %s)" % [missing])
func lightweight_on_screen() -> int:
	var camera: Camera3D = game.rig.camera
	var view: Rect2 = root.get_visible_rect()
	var count: = 0
	for group in game.units.stacks.groups():
		var leader: Dictionary = game.units.stacks.leader(group)
		if not game.units.visible_to_player(leader): continue
		var p: Vector3 = leader.node.global_position
		if camera.is_position_behind(p) or not view.has_point(camera.unproject_position(p)): continue
		if leader.node.get_child(0).get_meta("startup_lightweight", false): count += 1
	return count
func zoom(distance: float) -> void:
	game.rig.distance = distance
	for i in 120: await process_frame
func run() -> void:
	root.size = Vector2i(720, 1440)
	UnitSystem.force_mobile = true
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var at: Vector2 = game.buildings.city("kursk").point
	game.rig.target = Vector3(at.x, 0, at.y)
	# Fix 10 (owner 2026-10-16, "units render earlier when zooming"): between PREPARE_ZOOM and
	# FAR_ZOOM the phone loads the on-screen armies' models while they still show as map tags.
	await zoom(57.0)
	var before: int = lightweight_on_screen()
	await zoom((UnitSystem.FAR_ZOOM + UnitSystem.PREPARE_ZOOM) * 0.5)
	var after: int = lightweight_on_screen()
	print("on-screen armies still waiting for a model: far out %d, just before the model zoom %d" % [before, after])
	check(after == 0, "zooming in towards the model zoom loads every on-screen army's model ahead of time")
	await zoom(UnitSystem.FAR_ZOOM - 2.0)
	check_all("just inside the model zoom")
	await zoom(10.0)
	check_all("zoomed in")
	await zoom(45.0)
	check_all("zoomed out")
	await zoom(10.0)
	check_all("zoomed back in")
	await zoom(45.0)
	await zoom(14.0)
	check_all("zoomed in again")
	# An enemy army on Russian land is visible at any zoom, even far from our armies.
	game.match_rules.declare_war()
	var enemy: Dictionary = game.units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")[0]
	var spot: Vector2 = game.buildings.city("voronezh").point + Vector2(1.5, -1.0)
	enemy.stack_id = "lone_enemy"  # its own army, not one unit pulled out of a stack
	game.units.stacks.invalidate()
	enemy.node.position = Vector3(spot.x, enemy.node.position.y, spot.y)
	check(game.units.navigation.controller_at(spot) == "russia" and game.units.visible_to_player(enemy), "an enemy on our land is always visible")
	game.rig.target = Vector3(spot.x, 0, spot.y)
	await zoom(45.0)
	check(shown(enemy), "and shown when zoomed out")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
