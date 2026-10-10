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
	var city: Dictionary = game.buildings.capital("russia")
	game.city_panel.open(city)
	await capture("City_Building_List")
	var scroller: ScrollContainer = game.city_panel.list.get_parent()
	scroller.scroll_vertical = 570
	await capture("Resource_Building_List")
	scroller.scroll_vertical = 1300
	await capture("Military_Building_List")
	game.city_panel.hide()
	game.production_panel.open(city.name)
	await capture("Production_Menu")
	game.production_panel.hide()
	game.research_panel.open()
	await capture("Research_Menu")
	game.research_panel.hide()
	quit()
