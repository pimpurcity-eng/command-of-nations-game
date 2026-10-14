extends SceneTree
## Owner 2026-10-14: bigger start army - garrisons in every city and infantry in the provinces.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_start_army.gd
func _initialize() -> void: call_deferred("run")
func shot(game, at: Vector2, distance: float, name: String) -> void:
	game.rig.target = Vector3(at.x, 0, at.y)
	game.rig.distance = distance
	game.rig._snap(1.0)
	for i in 90: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("BUILDING_PREVIEW_DIR").path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var border: Vector2 = (game.buildings.city("belgorod").point + game.buildings.city("kharkiv").point) / 2.0
	await shot(game, border, 26.0, "Start_Army_Border")
	await shot(game, game.buildings.city("belgorod").point, 8.0, "Start_Army_City")
	quit()
