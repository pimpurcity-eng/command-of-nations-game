extends SceneTree
## Owner 2026-10-15: "I fired on myself by accident, it declared war on the other person."
## The Attack button never declares war; own armies cannot be targeted; at peace the player is
## asked before war is declared. After a move order the order panel closes ("one click").
##   godot --headless --path . --script tests/test_attack_confirm.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	for i in 3: await process_frame
	var mine: Array = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")
	var theirs: Array = game.units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")
	game.units.select_unit(game.units.units.find(mine[0]))
	game.hud.attack_requested.emit()
	check(not game.match_rules.at_war, "pressing Attack does not declare war")
	game._attack_army(mine[1])
	check(not game.match_rules.at_war and game.attack_order, "targeting your own army is refused, still at peace")
	game._attack_army(theirs[0])
	var dialog: ConfirmationDialog = null
	for child in game.get_children():
		if child is ConfirmationDialog: dialog = child
	check(dialog != null and not game.match_rules.at_war, "attacking an enemy at peace asks first")
	if dialog != null:
		dialog.canceled.emit()
		check(not game.match_rules.at_war and not game.attack_order, "Cancel keeps the peace")
		game.units.select_unit(game.units.units.find(mine[0]))
		game.hud.attack_requested.emit()
		game._attack_army(theirs[0])
		for child in game.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion(): dialog = child
		dialog.confirmed.emit()
		check(game.match_rules.at_war, "confirming declares war and attacks")
	# One click, destination.
	game.units.select_unit(game.units.units.find(mine[0]))
	game.hud.move_requested.emit()
	game.player_order(mine[0].node.position + Vector3(1.5, 0, 0.5))
	check(not game.order_mode and game.units.selected < 0, "after the destination the order panel closes")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
