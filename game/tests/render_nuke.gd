extends SceneTree
## Owner 2026-10-13: "make the nuclear bomb amazing".
##   BUILDING_PREVIEW_DIR=/dir xvfb-run -a godot --path . --script tests/render_nuke.gd
func _initialize() -> void: call_deferred("run")
var game
func wait(seconds: float) -> void:
	var end: = Time.get_ticks_msec() + int(seconds * 1000)
	var last: = Time.get_ticks_msec()
	while Time.get_ticks_msec() < end:
		var now: = Time.get_ticks_msec()
		game.combat_effects.advance_visual(minf((now - last) / 1000.0, 1.0))
		last = now
		await process_frame
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.units.fog_enabled = false
	var at: Vector2 = game.buildings.city("kursk").point + Vector2(1.5, 1.0)
	var ground: = Vector3(at.x, game.map.elevation(at), at.y)
	game.rig.target = ground + Vector3(0, 0, 2.0)
	game.rig.distance = 18.0
	game.rig._snap(1.0)
	await wait(0.5)
	game.combat_effects.nuke(ground, 1.6)
	var out: = OS.get_environment("BUILDING_PREVIEW_DIR")
	for step in [[2.0, "Nuke_1"], [3.0, "Nuke_2"], [4.0, "Nuke_3"]]:
		await wait(step[0])
		root.get_texture().get_image().save_png(out.path_join(step[1] + ".png"))
	quit()
