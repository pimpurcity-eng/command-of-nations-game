extends SceneTree
## Owner review: city screen unit tabs (one card per weapon, only the next research level).
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 20: await process_frame
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
	game.clock.paused = true
	game.city_panel.open(game.buildings.city("moscow"))
	await shot("City_Buildings")
	for index in ProductionGroups.CITY_TABS:
		game.city_panel.show_tab(index)
		await shot("City_" + ProductionGroups.CITY_TITLES[index])
	quit()
