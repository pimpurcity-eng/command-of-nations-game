extends SceneTree
## Apply the small home-screen update before loading any game scripts.
## The existing game pack, model download and music remain the game's assets.
func _initialize() -> void: call_deferred("start_home")
func start_home() -> void:
	var loaded := ProjectSettings.load_resource_pack("home.pck", true)
	if not loaded: push_warning("Home update could not be loaded; opening the existing game")
	var error := change_scene_to_file("res://scenes/startup.tscn")
	if error != OK:
		push_error("Could not open the game: " + error_string(error))
		quit(1)
		return
	if "--homepage-smoke" not in OS.get_cmdline_user_args(): return
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene == null or not "boot_finished" in current_scene: continue
		if not current_scene.boot_finished: continue
		var lobby = current_scene.mobile_start
		var valid: bool = loaded and lobby.has_signal("account_requested") and lobby.catalogue.features.size() == 12
		print("WM_HOME_OVERLAY_READY valid=", valid, " features=", lobby.catalogue.features.size(), " music=", current_scene.audio.music_playing())
		current_scene.queue_free()
		await process_frame
		quit(0 if valid else 1)
		return
	push_error("Home startup exceeded the smoke-test deadline")
	quit(1)
