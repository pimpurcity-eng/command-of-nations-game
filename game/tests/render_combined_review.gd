extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(out: String,name: String) -> void:
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(out.path_join(name))
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(720,1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	await shot(out,"Warfront_Opening_Final.png")
	game.mobile_start.hide()
	game.research_panel.open()
	await shot(out,"Research_Six_Groups.png")
	game.research_panel.show_category(2)
	await shot(out,"Research_Three_Models.png")
	game.research_panel.hide()
	game.city_panel.open(game.buildings.city("moscow"))
	await shot(out,"City_Buildings.png")
	game.city_panel.hide()
	game.rig.target = game.map.position_at(GeographicProjection.project(36.08,52.96))
	game.rig.distance = 11
	game.rig._snap(1.0)
	for unit in game.units.units:
		if unit.country == "russia" and unit.visual_kind == "armor": unit.health = 47
	await shot(out,"Unit_Health_Levels.png")
	game.rig.target = game.map.position_at(GeographicProjection.project(35.5,45.4))
	game.rig.distance = 22
	game.rig._snap(1.0)
	await shot(out,"Coastline_Review.png")
	quit()
