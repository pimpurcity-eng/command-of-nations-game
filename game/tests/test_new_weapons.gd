extends SceneTree
var failures: int = 0
var checks: int = 0
const FAMILIES: = ["artillery_russia", "artillery_ukraine", "rockets_russia", "rockets_ukraine", "helicopters_russia", "helicopters_ukraine"]
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in FAMILIES:
		var spec: = EquipmentIdentity.spec(id)
		var days: Array = spec.get("research_days", [])
		check(days.size() == 5 and int(days[0]) == 1 and int(days[1]) == 4 and int(days[2]) == 8 and int(days[3]) == 12 and int(days[4]) == 18, id + " unlock days")
		for level in range(1, 6):
			var tier: = EquipmentIdentity.research_tier(id, level)
			var model: = UnitVisual.create(spec.visual_kind, Color.WHITE, id, level)
			check(not model.get_meta("missing_original_model", true) and not model.get_meta("stand_in_model", false), tier.name + " actual original loaded")
			check(model.get_meta("asset_path") == tier.model, tier.name + " correct tier asset")
			check(CowUI.research_picture(id, level).resource_path == str(tier.model).trim_suffix(".glb") + ".png", tier.name + " research shows its own supplied picture")
			var pivot: Node3D = model.get_node("ModelFit")
			check((pivot.basis * Vector3.RIGHT).normalized().dot(Vector3.FORWARD) > 0.99, tier.name + " original +X faces game forward")
			var meshes: = model.find_children("*", "MeshInstance3D", true, false)
			var original_paint: bool = not meshes.is_empty()
			for mesh in meshes:
				for surface in mesh.mesh.get_surface_count():
					original_paint = original_paint and mesh.get_active_material(surface) is StandardMaterial3D
			check(original_paint, tier.name + " original materials retained")
			check(meshes.size() <= 4, tier.name + " merged phone meshes")
			if spec.get("role", "") == "helicopter":
				var animator: HelicopterAnimator = model.get_meta("helicopter_animator")
				check(animator.rotors.size() == 2, tier.name + " two original rotors")
				var before: = animator.rotors[0].transform
				animator.animate(0.02, false)
				check(animator.rotors[0].transform == before, tier.name + " grounded rotors stopped")
				animator.animate(0.02, true)
				check(animator.rotors[0].transform.basis != before.basis and animator.rotors[0].position == before.origin, tier.name + " flight spins about original pivot")
				if tier.model.contains("ka5"):
					var a: = animator.rest[0].basis.inverse() * animator.rotors[0].basis
					var b: = animator.rest[1].basis.inverse() * animator.rotors[1].basis
					check(a.is_equal_approx(b.inverse()), tier.name + " coaxial rotors counterrotate")
			model.free()
			UnitVisual._merged_meshes.clear()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var units: UnitSystem = game.units
	var helicopters: Array = units.units.filter(func(u): return u.equipment_id == "helicopters_russia")
	check(helicopters.size() == 1, "live campaign starts with Russian helicopter")
	if not helicopters.is_empty():
		var heli: Dictionary = helicopters[0]
		var start: = Vector2(heli.node.position.x, heli.node.position.z)
		var destination: = start + Vector2(0.3, 0.5)
		check(units.air.order(heli, destination).is_empty(), "helicopter accepts free flight within base range")
		check(heli.waypoints == [destination], "helicopter flies directly rather than road routing")
		units.air.advance(heli, 0.03)
		check(Vector2(heli.node.position.x, heli.node.position.z).distance_to(start) > 0, "helicopter actually moves")
		check(AirBattleSystem.new().value(heli, "ground_damage") > 0, "helicopter contributes ground attack")
	var rocket: = {"equipment_id": "rockets_russia", "visual_kind": "missile_launcher", "health": 100.0, "level": 1}
	check(is_equal_approx(CombatSystem.new().damage_value(rocket, "armor"), 12.0), "new rocket balance uses configured damage")
	check(is_equal_approx(CombatSystem.new().attack_reach(rocket), 3.5), "rocket range uses family configuration")
	check(CombatSystem.new().shot_effect(rocket) == "missile", "rockets use existing flight effects")
	var research: = ResearchPanel.new()
	root.add_child(research)
	research.setup(game.research, StrategyTheme.create())
	check(research._families(ResearchPanel.CATEGORIES.find("Helicopters")).size() == 1, "helicopter family appears in national research")
	for category in ["Artillery", "Helicopters", "Missiles", "Bombers", "Armor", "Mechanized"]:
		research.show_category(ResearchPanel.CATEGORIES.find(category))
		await process_frame
		var families: = research._families(research.category_index)
		var columns: = families.size() + 1
		var day_four: Label = research.grid.get_child(columns).get_child(0)
		var day_eighteen: Label = research.grid.get_child(columns * 4).get_child(0)
		check(day_four.text == "4" and day_eighteen.text == "18", category + " tree actually shows Day 4 and Day 18")
		check(not research.detail.name.text.contains("AA ") and research.detail.name.text.contains("Day 4"), category + " details render without air-defense fields")
	game.queue_free()
	research.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
