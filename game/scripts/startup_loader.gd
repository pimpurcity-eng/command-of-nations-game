extends Node
## Android boot: keep the opening visible while the world initializes.
## The old 0.23 loader pinned 29 weapon scenes in RAM before creating the entire
## 3D world and 189 starting units; that raised peak memory and startup stalls.
var panel: MobileStartPanel
var audio: GameAudio

func _ready() -> void:
	audio = GameAudio.new()
	add_child(audio)
	audio.play_music("menu_theme")
	panel = MobileStartPanel.new()
	panel.audio = audio
	add_child(panel)
	panel.setup(StrategyTheme.create(), FileAccess.file_exists("user://regional_save.json"))
	panel.layer = 30
	panel.begin_loading()
	await get_tree().process_frame
	var path := "res://scenes/main.tscn"
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
	if get_tree().node_added.is_connected(audio._watch_button):
		get_tree().node_added.disconnect(audio._watch_button)
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
	queue_free()
