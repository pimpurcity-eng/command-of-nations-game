extends SceneTree
## Owner 2026-10-13: "Ukraine didn't go red when I declared war" (playing Russia).
##   BUILDING_PREVIEW_DIR=/dir PLAY_AS=russia xvfb-run -a godot --path . --script tests/render_war_colours.gd
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("BUILDING_PREVIEW_DIR").path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = OS.get_environment("PLAY_AS") if not OS.get_environment("PLAY_AS").is_empty() else "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var at: Vector2 = game.buildings.city("kharkiv").point
	game.rig.target = Vector3(at.x, 0, at.y)
	game.rig.distance = 40.0
	game.rig._snap(1.0)
	await shot("War_Before_" + GameSession.player_country)
	game.hud.declare_war_requested.emit()
	await shot("War_After_" + GameSession.player_country)
	var hostile: = 0
	for t in game.map.territories:
		if t.playable and t.controller != GameSession.player_country and game.map.materials[t.id].get_shader_parameter("hostile"): hostile += 1
	print("WAR hostile territories: ", hostile, " at_war=", game.match_rules.at_war)
	quit()
