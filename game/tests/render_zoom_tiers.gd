extends SceneTree
## Owner review: armies at far / middle / close zoom (symbols → models → health bars).
##   xvfb-run -a godot --path . --script tests/render_zoom_tiers.gd   (PNG folder: BUILDING_PREVIEW_DIR)
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 40: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	if game.tutorial != null: game.tutorial.finish()
	game.clock.paused = true
	var moscow: = GeographicProjection.project(37.62, 55.75)
	for zoom in [[40.0, "Zoom_Far"], [16.0, "Zoom_Middle"], [7.0, "Zoom_Close"]]:
		game.rig.target = Vector3(moscow.x, 0, moscow.y + 1.0)
		game.rig.distance = zoom[0]
		game.rig._snap(1.0)
		await shot(zoom[1])
	quit()
