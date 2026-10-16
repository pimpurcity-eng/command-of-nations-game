extends SceneTree
## Owner 2026-10-16: "the camera's getting stuck mid-zoom ... it stops for a second, then starts
## again, about halfway". Zooms in and out slowly and reports every slow frame with its zoom.
##   xvfb-run -a godot --path . --script tests/profile_zoom.gd
func _initialize() -> void: call_deferred("run")
func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	if OS.get_environment("MOBILE") == "1": UnitSystem.force_mobile = true
	for i in 60: await process_frame
	for pass_name in ["in", "out", "in again"]:
		var from: float = 57.0 if pass_name != "out" else 5.0
		var to: float = 5.0 if pass_name != "out" else 57.0
		for step in 240:
			game.rig.distance = lerpf(from, to, step / 239.0)
			var start: = Time.get_ticks_usec()
			await process_frame
			var ms: = (Time.get_ticks_usec() - start) / 1000.0
			if ms > 60.0: print("SLOW %s %.0f ms at distance %.1f (rendered %.1f)" % [pass_name, ms, game.rig.distance, game.rig.rendered_distance])
	print("PROFILE DONE")
	quit()
