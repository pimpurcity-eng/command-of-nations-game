extends SceneTree
var failures: = 0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(720,1440)
	GameSession.weapons_test = false
	var loader = load("res://scenes/startup.tscn").instantiate()
	root.add_child(loader)
	var captured: = false
	var disabled: = false
	var loading_deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < loading_deadline:
		await process_frame
		if not is_instance_valid(loader): break
		if loader.panel.progress.value > 10 and loader.panel.progress.value < 90:
			disabled = loader.panel.fresh_button.disabled and loader.panel.test_button.disabled
			if not captured and not OS.get_cmdline_user_args().is_empty():
				root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("Start_Loading_Progress.png"))
				captured = true
	check(disabled,"real startup progress, disabled buttons")
	check(not is_instance_valid(loader),"startup completes")
	var game = current_scene
	check(game != null and game.get_script().resource_path == "res://scripts/main.gd","opens real campaign")
	if game != null:
		check(game.mobile_start.progress.value == 100 and not game.mobile_start.fresh_button.disabled,"ready screen completed")
		game.mobile_start.test_button.pressed.emit()
		await process_frame
		check(game.mobile_start.loading,"button starts loading")
		var partial: = false
		var weapons_deadline := Time.get_ticks_msec() + 180000
		while Time.get_ticks_msec() < weapons_deadline:
			await process_frame
			if not game.mobile_start.visible: break
			if game.mobile_start.progress.value > 10 and game.mobile_start.progress.value < 90: partial = true
		check(partial,"weapons preparation shows real progress")
		var expected: Dictionary = {}
		for family in EquipmentIdentity.catalog:
			for tier in family.research_tiers: expected[tier.model] = true
		check(not game.mobile_start.visible and game.units.units.size() == expected.size(),"all current weapons loading completes")
		game.queue_free()
		await process_frame
	print("RESULT failures=",failures)
	quit(0 if failures == 0 else 1)
