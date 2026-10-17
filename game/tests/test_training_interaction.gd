extends SceneTree
## Owner 2026-10-17: the tutorial must work through the same taps and orders as the player.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.country_picker.select(0)
	game.city_panel.open(game.buildings.capital("ukraine"))
	game._set_order_mode(true)
	await game.mobile_start.request_start("training")
	var training: TrainingMatch = game.training_match
	check(is_instance_valid(training) and not game.mobile_start.visible, "the real home-screen start signal opens training")
	check(not game.city_panel.visible and not game.order_mode, "old menus and unfinished orders cannot block a new tutorial")
	await create_timer(0.8).timeout
	check(is_instance_valid(training.cinema) and training.cinema.player.is_playing() and training.cinema.position_seconds() > 0.1, "the opening film actually advances after launch")
	check(training.cinema._length > 29.0, "the film progress line uses its full thirty-second duration")
	training.cinema._finish()
	await create_timer(0.4).timeout
	check(game.session.training.phase == "side" and is_instance_valid(training.side_screen), "the film completion signal opens side selection")
	training.choose_side("ukraine", true)
	training.set_process(false)
	for i in 4: await process_frame
	var tank: Dictionary = training._lesson_unit("select")
	var point: Vector2 = game.rig.camera.unproject_position(tank.node.global_position)
	game._map_click(point, false)
	check(game.units.selected >= 0 and game.units.units[game.units.selected].equipment_id == tank.equipment_id, "tapping the highlighted tank selects tanks even in a garrison")
	training.next_step()
	check(training.current_action() == "move", "selecting the tank reaches the move lesson")
	game.hud.move_requested.emit()
	var capital: Dictionary = game.buildings.capital("ukraine")
	game.player_order(game.map.position_at(capital.point))
	check(game.units.selected == -1 and game.units.units.any(func(u): return u.country == "ukraine" and u.visual_kind == "armor" and u.moving), "a real Move order starts the tanks and closes unit controls")
	check(training.action_completed(), "the move lesson remembers a successful order after the game clears selection")
	training.next_step()
	# Probe city selection independently even if the preceding regression failed.
	game.session.training.phase = "basics"
	game.session.training.step = 2
	training.show_step()
	training.focus_objective()
	for i in 4: await process_frame
	point = game.rig.camera.unproject_position(game.map.position_at(capital.point) + Vector3.UP * 0.2)
	game._map_click(point, false)
	check(game.city_panel.visible and game.city_panel.city_id == capital.id and game.units.selected == -1, "one tap on the lesson city opens the city instead of its garrison")
	game.city_panel.hide()
	var garrison: Dictionary = game.units.units.filter(func(u): return u.country == "ukraine" and Vector2(u.node.position.x, u.node.position.z).distance_to(capital.point) <= UnitSystem.CITY_RADIUS)[0]
	game.badges.badge_clicked.emit(game.units.units.find(garrison))
	check(game.city_panel.visible and game.city_panel.city_id == capital.id, "a garrison badge also opens the city during a city lesson")
	game.city_panel.hide()
	training.start_supply_movie()
	training.set_process(true)
	await create_timer(0.8).timeout
	check(is_instance_valid(training.cinema) and training.cinema.player.is_playing() and training.cinema.position_seconds() > 0.1, "the supply film actually advances with the game clock paused")
	var missing := TrainingCinema.new()
	training.root.add_child(missing)
	missing.setup("opening", "res://assets/cinematics/not_in_this_build.ogv", 0.0, true)
	await process_frame
	check(not missing._waiting and missing.message.text != "Loading the film…", "a missing installed film shows a recoverable error instead of waiting forever")
	missing.queue_free()
	print("RESULT TRAINING_INTERACTION checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	quit(1 if failures else 0)
