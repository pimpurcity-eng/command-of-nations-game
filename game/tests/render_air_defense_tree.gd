extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in 8: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	game.research_panel.open()
	game.research_panel.show_category(4)
	game.research_panel.selected_id = "patriot_russia"
	game.research_panel.selected_level = 3
	game.research_panel._refresh()
	await capture("Russian_Air_Defense_Tree")
	quit()
