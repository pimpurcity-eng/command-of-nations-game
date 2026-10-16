extends SceneTree
## Owner 2026-10-16: city resources and the More menu were too small on a phone.
##   SHOT_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_menus_oct16.gd
func _initialize() -> void: call_deferred("run")
func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	for i in 10: await process_frame
	var city: Dictionary = game.buildings.city("poltava")
	game.city_panel.open(city)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("City_Income.png"))
	game.city_panel.hide()
	var popup: PopupMenu = game.hud.navigation_menu.get_popup()
	popup.popup(Rect2i(Vector2i(300, 700), Vector2i(10, 10)))
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("More_Menu.png"))
	quit()
