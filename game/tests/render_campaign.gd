extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 800)
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene = game
	await process_frame; await process_frame
	root.get_texture().get_image().save_png("/workspace/scratch/9cc4c8c712c9/recovery-tests/start-screen.png")
	game.mobile_start.hide(); game.apply_player_country()
	game.clock.paused = true; game.units.fog_enabled = false
	game.rig.distance = 24; game.rig._snap(1.0)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png("/workspace/scratch/9cc4c8c712c9/recovery-tests/ukraine-map.png")
	game.populate_weapons_test(); game.apply_player_country()
	game.rig.target = Vector3(0, 0, 5); game.rig.distance = 26; game.rig._snap(1.0)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png("/workspace/scratch/9cc4c8c712c9/recovery-tests/weapons-test-map.png")
	root.size = Vector2i(390, 844)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png("/workspace/scratch/9cc4c8c712c9/recovery-tests/phone-test-map.png")
	quit()
