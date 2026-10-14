extends SceneTree
## Owner 2026-10-14: turning guard off left an empty dark panel stuck on screen.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_guard_report.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.show_guard_report("While you were away (2 h):\nKharkiv attacked Belgorod - held.\n3 enemy units destroyed, 1 of yours lost.\nNo provinces lost.")
	for i in 20: await process_frame
	var card: Control = game.guard_popup.get_node("Card")
	print("CARD ", card.position, " ", card.size, " ok=", card.get_global_rect().end.y < 1440 and card.position.y > 0)
	root.get_texture().get_image().save_png(OS.get_environment("BUILDING_PREVIEW_DIR").path_join("Guard_Report.png"))
	quit()
