extends SceneTree
## Owner 2026-10-13: no white disks in cities; garrison units drawn bigger in cities.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_city_garrison.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var kursk: Vector2 = game.buildings.city("belgorod").point
	game.rig.target = Vector3(kursk.x, 0, kursk.y)
	game.rig.distance = 7.0
	game.rig._snap(1.0)
	for i in 90: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	root.get_texture().get_image().save_png(folder.path_join("City_Garrison.png"))
	quit()
