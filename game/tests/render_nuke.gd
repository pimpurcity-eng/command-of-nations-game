extends SceneTree
## Owner 2026-10-13: "make the nuke amazing" - warning, blast, mushroom cloud, ruins, fallout.
##   BUILDING_PREVIEW_DIR=/dir xvfb-run -a godot --path . --script tests/render_nuke.gd
func _initialize() -> void: call_deferred("run")
var game
var shots: Array = []
func wait(seconds: float) -> void:
	# Steps the effects by real time (this machine renders slowly), up to 0.25 s a frame.
	var left: = seconds
	var last: = Time.get_ticks_msec()
	while left > 0.0:
		await process_frame
		var now: = Time.get_ticks_msec()
		var dt: = minf(minf((now - last) / 1000.0, 0.25), left)
		last = now
		game.combat_effects.advance_visual(dt)
		left -= dt
func shot(name: String) -> void:
	await process_frame
	var path: String = OS.get_environment("BUILDING_PREVIEW_DIR").path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.units.fog_enabled = false
	game.clock.paused = false
	game.clock.set_process(false)
	var city: Dictionary = game.buildings.city("kharkiv")
	var at: Vector2 = city.point
	var ground: = Vector3(at.x, game.map.elevation(at), at.y)
	game.rig.target = ground + Vector3(0, 0, 1.0)
	game.rig.distance = 16.0
	game.rig._snap(1.0)
	await wait(0.3)
	game.combat_effects.nuke_warning(5.0)
	await wait(0.4)
	await shot("Nuke_0_warning")
	await wait(4.8)
	game.combat_effects.nuke(ground, 1.6, 100000.0)
	for id in game.match_rules.nuclear_aftermath(at, 1.6): game.cities.devastate(id)
	game.nuke_cinematic(ground)
	await wait(0.15)
	await shot("Nuke_1_flash")
	await wait(1.6)
	await shot("Nuke_2_fireball")
	await wait(3.0)
	await shot("Nuke_3_mushroom")
	await wait(4.0)
	await shot("Nuke_4_cloud")
	await wait(30.0)
	await shot("Nuke_5_ruins_fallout")
	print("NUKE kharkiv buildings after: ", game.buildings.levels[city.id])
	quit()
