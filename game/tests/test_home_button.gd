extends SceneTree
## Owner 2026-10-15: "Have a button to go back to homescreen or player profile."
##   godot --headless --path . --script tests/test_home_button.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run():
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.request_start("fresh")
	for i in 20: await process_frame
	check(not game.mobile_start.visible and not game.clock.paused, "campaign running")
	var popup: PopupMenu = game.hud.navigation_menu.get_popup()
	check(popup.get_item_text(0).contains("Home screen") and popup.get_item_text(1).contains("profile"), "More menu starts with Home screen and Commander profile")
	game.units.units[0].node.position.x += 0.0
	popup.id_pressed.emit(100)
	for i in 5: await process_frame
	check(game.mobile_start.visible and game.clock.paused and game.mobile_start.continue_button.visible, "Home screen shows, match paused, Resume offered")
	game.mobile_start.request_start("continue")
	for i in 5: await process_frame
	check(not game.mobile_start.visible and not game.clock.paused, "Resume carries on with the same match")
	popup.id_pressed.emit(101)
	for i in 5: await process_frame
	check(game.account_panel != null and game.account_panel.visible, "Commander profile opens")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
