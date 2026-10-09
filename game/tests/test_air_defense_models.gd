extends SceneTree
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	game.units.restore([])
	var expected: Array = []
	for country in ["russia", "ukraine"]:
		var capital: Dictionary = game.buildings.capital(country)
		for pair in [["skyguard_", 1], ["skyguard_", 3], ["patriot_", 1], ["patriot_", 3], ["patriot_", 5]]:
			var id: String = pair[0] + country
			var tier: Dictionary = EquipmentIdentity.research_tier(id, pair[1])
			var data: Dictionary = {"id": "air_model_" + str(expected.size()), "name": tier.name, "country": country, "equipment_id": id, "visual_kind": "air_defense", "level": pair[1]}
			game.units._spawn(data, capital.point + Vector2(expected.size() % 5, 1.5), Color.WHITE)
			expected.append(tier.model)
	for index in game.units.units.size():
		var unit: Dictionary = game.units.units[index]
		var model: Node3D = unit.node.get_child(0)
		check(model.get_meta("asset_path") == expected[index], "correct original " + unit.name)
		check(not model.get_meta("stand_in_model", false), "no stand-in for " + unit.name)
		var animator: AirDefenseAnimator = model.get_meta("air_defense_animator")
		check(not animator.launchers.is_empty() or not animator.radars.is_empty(), "named moving parts " + unit.name)
		animator.moving = false
		animator.animate(2.0)
		check(is_equal_approx(animator.deployed, 1.0), "deploys when stationary " + unit.name)
		if not animator.launchers.is_empty(): check(is_equal_approx(animator.launchers[0].rotation.z, animator.elevation), "launcher reaches deployed angle " + unit.name)
		animator.moving = true
		animator.animate(2.0)
		check(is_equal_approx(animator.deployed, 0.0), "packs before moving " + unit.name)
		if not animator.launchers.is_empty(): check(is_equal_approx(animator.launchers[0].rotation.z, animator.rest[animator.launchers[0]].z), "restores travel pose " + unit.name)
		animator.fire(unit.node.position + Vector3(1, 1, 0))
		check(animator.shot_remaining > 0 and animator.muzzle_position().is_finite(), "firing animation and launch origin " + unit.name)
		var fitted: Node3D = model.get_node("ModelFit")
		check((fitted.basis * Vector3.RIGHT).normalized().dot(Vector3.FORWARD) > 0.99, "truck/hull front faces game heading " + unit.name)
		game.units.selected = index
		game.units._process(0.016)
		check(game.units.air_range.visible and is_equal_approx(game.units.air_range.scale.x, EquipmentIdentity.air_defense_range(unit)), "range circle matches actual weapon reach " + unit.name)
	var first: Dictionary = game.units.units[0]
	first.level = 3
	game.units._process(0.016)
	check(first.node.get_child(0).get_meta("asset_path").ends_with("russia_tor_m2.glb"), "modernization replaces Strela with Tor")
	var state: Array = game.units.snapshot()
	game.units.restore(state)
	check(game.units.units.size() == 10 and game.units.units[0].node.get_child(0).get_meta("asset_path").ends_with("russia_tor_m2.glb"), "save restore retains correct tier models")
	var source: Dictionary = game.units.units[0]
	var point: Vector2 = Vector2(source.node.position.x, source.node.position.z) + Vector2(0.35, 0.0)
	game.units._spawn({"id": "interception_target", "name": "Aircraft", "country": "ukraine", "equipment_id": "f18a_ukraine", "visual_kind": "fighter", "flight_mode": "patrol"}, point, Color.WHITE)
	game.units.at_war = true
	var pending: Dictionary = {}
	game.match_rules.air_combat.advance(0.0, game.units, pending, true)
	check(pending.get("interception_target", 0.0) > 0, "actual interception applies aircraft damage")
	check(not game.combat_effects.projectiles.is_empty(), "actual combat emits flying interceptor")
	var controller: AirDefenseAnimator = source.node.get_child(0).get_meta("air_defense_animator")
	check(controller.shot_remaining > 0, "combat signal starts launcher animation")
	if not game.combat_effects.projectiles.is_empty(): check(game.combat_effects.projectiles[0].start.distance_to(controller.muzzle_position()) < 0.5, "interceptor starts at original model launcher")
	print("RESULT checks=", checks, " failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)
