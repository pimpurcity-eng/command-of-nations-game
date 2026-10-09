extends SceneTree
## Portrait screenshots of the city and research screens (review aid).
##   godot --path . --script tests/render_panels.gd -- <out_dir>
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
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
	for city in game.cities.cities:
		if city.name == "Moscow": game.city_panel.open(city)
	await shot(out + "/panel_city.png")
	game.city_panel.hide()
	game.hud.research_requested.emit()
	await shot(out + "/panel_research.png")
	if game.research_panel.has_method("show_category"):
		game.research_panel.show_category(0)
		await shot(out + "/panel_research_tree.png")
	quit()
