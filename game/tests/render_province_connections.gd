extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.apply_player_country()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	game.rig.set_process(false)
	for entry in [["Kyiv region", "Poltava region", "Central_Province_Roads.png"], ["Lviv region", "Rivne region", "Western_Province_Roads.png"]]:
		var a: Vector2 = game.map.province_hubs[entry[0]]
		var b: Vector2 = game.map.province_hubs[entry[1]]
		var p: Vector2 = a.lerp(b, 0.5)
		game.rig.target = Vector3(p.x, 0, p.y)
		game.rig.distance = 12.0
		game.rig._snap(1.0)
		for i in 10: await process_frame
		root.get_texture().get_image().save_png(output.path_join(entry[2]))
	quit()
