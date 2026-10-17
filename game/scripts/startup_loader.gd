extends Node
## Android boot: keep the opening visible while the world initializes.
## The old 0.23 loader pinned 29 weapon scenes in RAM before creating the entire
## 3D world and 189 starting units; that raised peak memory and startup stalls.
var panel: MobileStartPanel
var audio: GameAudio

func _ready() -> void:
	get_viewport().disable_3d = true
	# One music player for the whole game (owner: the start song played twice). It lives on the
	# root so it survives this loader and the campaign reuses it instead of starting a second copy.
	audio = GameAudio.new()
	audio.name = "GameAudio"
	get_tree().root.add_child.call_deferred(audio)
	await audio.ready
	audio.play_music("menu_theme")
	panel = MobileStartPanel.new()
	panel.audio = audio
	add_child(panel)
	panel.setup(StrategyTheme.create(), FileAccess.file_exists(MapDefinition.save_path()))
	panel.layer = 30
	panel.begin_background_loading()
	await get_tree().process_frame
	var path := MapDefinition.scene_path()
	if ResourceLoader.load_threaded_request(path) != OK:
		panel.set_progress(0, "Unable to load campaign. Please restart.")
		push_error("Could not start main scene request")
		return
	var fraction: Array = []
	while ResourceLoader.load_threaded_get_status(path, fraction) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var amount: float = float(fraction[0]) if not fraction.is_empty() else 0.0
		panel.set_progress(35.0 * amount, "Loading game")
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		panel.set_progress(panel.progress.value, "Unable to load campaign. Please restart.")
		return
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		panel.set_progress(panel.progress.value, "Unable to load campaign. Please restart.")
		return
	panel.set_progress(40, "Preparing map")
	await get_tree().process_frame
	var game = scene.instantiate()
	game.boot_progress.connect(func(done: int, total: int):
		if is_instance_valid(panel):
			panel.set_progress(40.0 + 55.0 * float(done) / maxi(total, 1), "Preparing armies")
	)
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	# A signal emitted during synchronous _ready() must never be awaited late.
	if not game.boot_finished:
		await game.boot_ready
	panel.set_progress(100, "Ready")
	print("BOOT ready after ", Time.get_ticks_msec(), " ms")
	# Hand the player's choices to the game's own home screen and carry out a start they
	# already chose while the map was loading.
	game.mobile_start.country_picker.select(panel.country_picker.selected)
	game.mobile_start._show_nation()
	if not panel.pending_start.is_empty():
		var mode: = panel.pending_start
		game.mobile_start.layer = panel.layer + 1
		game.mobile_start.request_start(mode)
	if "--startup-smoke" in OS.get_cmdline_user_args():
		panel.hide()
		print("WF_SMOKE READY")
		for i in 4: await get_tree().process_frame
		var point: Vector2 = game.mobile_start.fresh_button.get_global_rect().get_center()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = true
		get_viewport().push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		get_viewport().push_input(click, true)
		for i in 8: await get_tree().process_frame
		if game.mobile_start.visible or game.clock.paused:
			print("WF_SMOKE FAIL Start button did not open campaign")
		else:
			print("WF_SMOKE MAP_OPEN units=", game.units.units.size())
			var until := Time.get_ticks_msec() + 30000
			while Time.get_ticks_msec() < until: await get_tree().process_frame
			print("WF_SMOKE MAP_RUNNING time=", game.clock.elapsed)
	queue_free()
