extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	var game = load("res://scenes/air_defense_test_map.tscn").instantiate()
	root.add_child(game)
	for frame in 24: await process_frame
	assert(game.units.units.size() == 10, "All ten supplied models on the map")
	for unit in game.units.units:
		var visual: Node3D = unit.node.get_child(0)
		assert(not visual.get_meta("missing_original_model", true))
		var start: Vector3 = unit.node.position
		var end: Vector3 = start - visual.global_basis.z.normalized()
		var direction: Vector2 = game.rig.camera.unproject_position(end) - game.rig.camera.unproject_position(start)
		assert(direction.x < 0.0 and direction.y > 0.0, "Cab points toward seven o'clock")
	game.units.select_unit(0)
	assert(GameSession.player_country == "russia", "Russian column is controllable")
	game.units.select_unit(9)
	assert(GameSession.player_country == "ukraine", "European column is controllable")
	print("PASS ten original models face seven o'clock on Godot map")
	var folder: String = OS.get_environment("BUILDING_PREVIEW_DIR")
	if not folder.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder.path_join("Air_Defense_Seven_Oclock_Test.png"))
	quit()
