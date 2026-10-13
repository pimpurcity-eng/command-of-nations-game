extends SceneTree
## Owner 2026-10-13: better explosions, bombs from aircraft and an amazing nuclear blast.
##   BUILDING_PREVIEW_DIR=/dir xvfb-run -a godot --path . --script tests/render_effects.gd
func _initialize() -> void: call_deferred("run")
var game
func frames(n: int) -> void:
	for i in n:
		game.combat_effects.advance_visual(1.0 / 30.0)
		await process_frame
func shot(name: String) -> void:
	root.get_texture().get_image().save_png(OS.get_environment("BUILDING_PREVIEW_DIR").path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.units.fog_enabled = false
	var at: Vector2 = game.buildings.city("kursk").point + Vector2(1.5, 1.0)
	var ground: Vector3 = Vector3(at.x, game.map.elevation(at), at.y)
	game.rig.target = ground
	game.rig.distance = 6.0
	game.rig._snap(1.0)
	await frames(10)
	game.combat_effects.explode(ground, true)
	game.combat_effects.explode(ground + Vector3(0.8, 0, 0.3), false)
	await frames(6)
	await shot("FX_Explosion_early")
	await frames(20)
	await shot("FX_Explosion_late")
	for i in 3: game.combat_effects.launch(ground + Vector3(-1.2 + i * 0.2, 1.8, 0), ground + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), "bomb")
	await frames(20)
	await shot("FX_Bombs_falling")
	await frames(30)
	await shot("FX_Bombs_hit")
	game.rig.distance = 22.0
	game.rig._snap(1.0)
	game.combat_effects.nuke(ground, 1.6)
	await frames(4)
	await shot("FX_Nuke_flash")
	await frames(45)
	await shot("FX_Nuke_fireball")
	await frames(90)
	await shot("FX_Nuke_mushroom")
	quit()
