extends SceneTree
## Owner 2026-10-13: gold (10,000 per match), Call of War sized economy, no province flags.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_gold.gd
func _initialize() -> void: call_deferred("run")
var game
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var moscow: Dictionary = game.buildings.city("moscow")
	game.rig.target = Vector3(moscow.point.x, 0, moscow.point.y)
	game.rig.distance = 22.0
	game.rig._snap(1.0)
	await shot("Gold_Map")
	game.hud.gold_requested.emit()
	await shot("Gold_Panel")
	game.gold_panel.hide()
	game.production.schedule("infantry_russia", moscow.name)
	game.buildings.schedule(moscow.id, "industry")
	game.city_panel.open(moscow)
	await shot("Gold_City")
	quit()
