extends SceneTree
## Owner 2026-10-15: a nuclear missile launcher fires once, the blast lands after the flight and
## hurts every army around the target, and the launcher is used up.
var failures: = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	GameSession.weapons_test = true
	await game.populate_weapons_test(false, "drones")
	var launcher: Dictionary = {}
	for u in game.units.units:
		if u.equipment_id == "strategic_russia": launcher = u; break
	check(not launcher.is_empty(), "Yars on the drones and missiles map")
	var target: Dictionary = {}
	var best: = INF
	for u in game.units.units:
		if u.country != "ukraine" or game.units.air.is_air(u) or game.units.is_naval(u): continue
		var d: = Vector2(u.node.position.x, u.node.position.z).distance_to(Vector2(launcher.node.position.x, launcher.node.position.z))
		if d < best and d > 2.0: best = d; target = u
	game.match_rules.declare_war()
	game.clock.paused = false
	var model: Node3D = launcher.node.get_child(0)
	game.units.units.filter(func(u): return u.country == "russia" and u != launcher).map(func(u): u.fire_mode = "hold"; return u)
	launcher.attack_target = target.id
	var fired: = false
	var before: float = target.health
	for i in 600:
		game.match_rules.advance_battles(0.002)
		if launcher.has("nuke_launch"): fired = true
		if launcher.health <= 0: break
	check(fired, "Yars fires at an enemy in range")
	check(launcher.health <= 0, "launcher is used up after the blast")
	check(target.health < before * 0.5, "blast badly hurts the target army (%.0f -> %.0f)" % [before, target.health])
	print("RESULT failures=", failures)
	quit()
