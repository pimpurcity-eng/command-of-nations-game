extends SceneTree
## Owner review: Trade screen and a freight train on the map.
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.trade.open_route("russia", "belarus", "fuel")
	game.hud.exchange_requested.emit()
	await shot("Trade_Screen")
	game.trade_panel.hide()
	game.trade.advance(1.0)
	for i in 30: game.trade.advance(4.0)
	var train: Node3D = game.trade.convoys[0].node
	game.rig.target = train.position
	game.rig.distance = 6.0
	game.rig._snap(1.0)
	await shot("Trade_Train")
	quit()
