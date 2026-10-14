extends SceneTree
## Owner 2026-10-14: the starting plane sits at an airport in a province, not in a city.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_start_plane.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var plane: Dictionary = game.units.units.filter(func(x): return x.country == "russia" and x.visual_kind == "fighter")[0]
	game.units.select_unit(game.units.units.find(plane))
	game.rig.target = plane.node.position
	game.rig.distance = 7.0
	game.rig._snap(1.0)
	for i in 90: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("BUILDING_PREVIEW_DIR").path_join("Start_Plane.png"))
	quit()
