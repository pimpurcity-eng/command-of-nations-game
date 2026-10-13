extends SceneTree
## Owner review: main menus at phone size.
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	var capital: Dictionary = game.buildings.capital("russia")
	game.city_panel.open(capital)
	await shot("Screen_City")
	game.city_panel.hide()
	game.production_panel.open(capital.name)
	await shot("Screen_Production")
	game.production_panel.hide()
	game.research_panel.open()
	await shot("Screen_Research_Overview")
	game.research_panel.hide()
	game.open_campaign("victory")
	await shot("Screen_Campaign")
	quit()
