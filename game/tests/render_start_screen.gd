extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.content_scale_size = Vector2i.ZERO
	for saved in [false, true]:
		root.size = Vector2i(720,1440)
		var screen := MobileStartPanel.new()
		root.add_child(screen)
		screen.setup(StrategyTheme.create(), saved)
		for i in 8: await process_frame
		check(screen.continue_button.visible == saved, "continue follows saved campaign")
		check(screen.panel.position.y + screen.panel.size.y < 1440, "portrait controls fit")
		check(screen.heading.text == "WARFRONT\nMANDATE", "new branding")
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(out.path_join("Warfront_Start_Saved.png" if saved else "Warfront_Start.png"))
		for size in [Vector2i(360,800), Vector2i(1440,720)]:
			root.size = size
			for i in 8: await process_frame
			check(screen.panel.position.x >= 0 and screen.panel.position.x + screen.panel.size.x <= size.x + 1, "width fits " + str(size))
			check(screen.panel.position.y + screen.panel.size.y < size.y, "height fits " + str(size))
			if saved and size.x == 1440 and DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(out.path_join("Warfront_Start_Landscape.png"))
		var requests := [0]
		var mode := "continue" if saved else "fresh"
		if saved: screen.continue_requested.connect(func(): requests[0] += 1)
		else: screen.fresh_requested.connect(func(): requests[0] += 1)
		screen.request_start(mode)
		screen.request_start(mode)
		for i in 3: await process_frame
		check(requests[0] == 1, "only one launch signal")
		check(screen.fresh_button.disabled and screen.country_picker.disabled and screen.test_button.disabled, "controls locked during loading")
		screen.set_progress(45, "Preparing forces")
		check(screen.progress.value == 45 and screen.loading_label.text == "Preparing forces", "live progress")
		screen.queue_free()
		await process_frame
	print("RESULT failures=", failures)
	quit(0 if failures == 0 else 1)
