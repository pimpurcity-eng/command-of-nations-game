extends SceneTree
## Native portrait review of the live campaign and its helicopter research tree.
## Pass an output directory after --. No saved match or source asset is modified.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "user://new-weapons-review"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(540, 1200)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.apply_player_country()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	var heli: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "helicopters_russia")[0]
	var centre: = Vector2(heli.node.position.x, heli.node.position.z)
	game.units.air.order(heli, centre + Vector2(0.4, 0.2), "patrol")
	game.units.air.advance(heli, 0.04)
	game.units.select_unit(game.units.units.find(heli))
	game.rig.target = heli.node.position
	game.rig.distance = 6.0
	game.rig._snap(1.0)
	game.rig.set_process(false)  # Screenshot capture has no real pointer; avoid edge panning.
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(output.path_join("Live_Helicopter.png"))
	game.research_panel.open()
	game.research_panel.show_category(ResearchPanel.CATEGORIES.find("Helicopters"))
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(output.path_join("Helicopter_Research.png"))
	game.research_panel.show_category(ResearchPanel.CATEGORIES.find("Artillery"))
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(output.path_join("Artillery_Research.png"))
	quit()
