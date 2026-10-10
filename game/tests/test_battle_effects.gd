extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()  # live arsenal is empty until the new weapons arrive
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.clock.paused = true
	game.mobile_start.hide()
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	var fx = game.combat_effects
	for id in ["missile_launcher_russia", "missile_launcher_ukraine"]:
		var launcher: = UnitVisual.create("missile_launcher", Color.WHITE, id)
		check(not launcher.get_meta("missing_original_model", true), id + " original model available")
		if launcher.get_child_count() > 0:
			var forward: Vector3 = launcher.get_child(0).basis * Vector3.FORWARD
			check(forward.normalized().is_equal_approx(Vector3.FORWARD), id + " fitted cab faces -Z")
		launcher.free()
		for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
			var aim: = UnitVisual.firing_heading(id, direction)
			check((Basis(Vector3.UP, aim) * Vector3.FORWARD).is_equal_approx(direction), id + " truck front faces enemy " + str(direction))
	var a = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "armor")[0]
	var b = game.units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "armor")[0]
	b.node.position = a.node.position + Vector3(0.3, 0, 0)
	a.moving = true
	game.match_rules.declare_war()
	game.match_rules.advance(0.1)
	check(fx.projectiles.any(func(j): return j.effect == "cannon"), "tank combat emits cannon projectile")
	check(not fx.muzzles.is_empty(), "combat creates muzzle flash")
	fx.clear()
	await process_frame
	var old_id: String = a.equipment_id
	a.equipment_id = "missile_launcher_russia"
	fx.on_shot(a, b, "missile")
	var target_direction: Vector3 = (b.node.position - a.node.position).normalized()
	check((Basis(Vector3.UP, a.heading) * Vector3.FORWARD).is_equal_approx(target_direction), "launch event points truck front at enemy")
	a.equipment_id = old_id
	fx.clear()
	var model = a.node.get_child(0)
	var base = model.position
	var world = a.node.position
	check(game.units.units.all(func(u): return u.node.has_meta("ground_shadow")), "every unit has a ground shadow")
	a.node.position.y += 2.0
	UnitShadow.update(a, world)
	var shadow: MeshInstance3D = a.node.get_meta("ground_shadow")
	check(is_equal_approx(shadow.global_position.y, world.y + 0.04), "airborne shadow stays on the ground")
	a.node.position = world
	UnitShadow.update(a, world)
	fx.on_shot(a, b, "cannon")
	fx.on_shot(a, b, "cannon")
	check(fx.muzzles.size() == 1, "rapid firing keeps one recoil job per model")
	fx.advance_visual(0.25)
	check(model.position.is_equal_approx(base), "recoil returns to original model position")
	check(a.node.position.is_equal_approx(world), "recoil leaves simulation position unchanged")
	fx.clear()
	fx.launch(a.node.position + Vector3.UP, b.node.position + Vector3.UP, "missile")
	fx.advance_visual(0.1)
	check(not fx.smoke_jobs.is_empty(), "missile leaves smoke puffs")
	for i in 60: fx.advance_visual(0.1)
	check(fx.projectiles.is_empty() and fx.impacts.is_empty() and fx.smoke_jobs.is_empty(), "flight and impact effects expire")
	fx.on_destroyed(a)
	check(fx.wrecks.size() == 1 and fx.wrecks[0].node.get_child(0).get_meta("original_vehicle_asset", false), "wreck reuses original vehicle model")
	fx.clear()
	game.units.fog_enabled = true
	a.node.position = Vector3(10000, 0, 10000)
	b.node.position = Vector3(20000, 0, 20000)
	a.country = "ukraine"
	fx.on_shot(a, b, "cannon")
	fx.on_destroyed(b)
	check(fx.projectiles.is_empty() and fx.muzzles.is_empty() and fx.wrecks.is_empty(), "unseen enemy battle produces no effects")
	game.units.fog_enabled = false
	for i in 100: fx.smoke_puff(Vector3.ZERO)
	check(fx.smoke_jobs.size() == fx.MAX_SMOKE, "smoke is bounded for mobile")
	for i in 100: fx.launch(Vector3.ZERO, Vector3.ONE, "cannon")
	check(fx.projectiles.size() == fx.MAX_PROJECTILES, "projectiles are bounded for mobile")
	fx.clear()
	check(fx.smoke_jobs.is_empty() and fx.projectiles.is_empty() and fx.muzzles.is_empty() and fx.wrecks.is_empty(), "reset clears all effects")
	game.queue_free()
	await process_frame
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
