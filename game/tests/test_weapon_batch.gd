extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", message)
func _initialize(): call_deferred("run")
func run():
	var control: = CombatSystem.new()
	var catalog: Array = EquipmentIdentity.catalog
	check(catalog.size() == 63, "all new families are present")
	var ids: Dictionary = {}
	for spec in catalog:
		check(not ids.has(spec.id), "unique equipment ID " + spec.id)
		ids[spec.id] = true
		check(spec.research_tiers.size() == 5, "five research levels " + spec.id)
		for i in spec.research_tiers.size():
			var tier: Dictionary = spec.research_tiers[i]
			check(not tier.model.contains("m113") and not tier.model.contains("m270") and not tier.model.contains("f16") and not tier.model.contains("e7_wedgetail"), "no American model " + tier.model)
			if not tier.model.contains("/arsenal/"): continue
			check(ResourceLoader.exists(tier.model), "model exists " + tier.model)
			if not ResourceLoader.exists(tier.model): continue
			var model: = UnitVisual.create(spec.visual_kind, Color.WHITE, spec.id, i+1)
			check(not model.get_meta("missing_original_model", true), "original model loads " + spec.id)
			check(not model.get_meta("stand_in_model", false), "no stand-in " + spec.id)
			var bounds: AABB = model.get_meta("pick_bounds", AABB())
			check(bounds.size.length() > 0.01, "pickable model bounds " + spec.id)
			model.free()
	var infantry: = {"equipment_id":"infantry_russia","visual_kind":"infantry","health":100.0,"level":1}
	check(control.damage_value(infantry, "infantry") > 0, "infantry combat")
	var support: = {"equipment_id":"kamaz5350_supply_russia","visual_kind":"support","health":100.0,"level":1}
	check(control.damage_value(support,"armor") == 0, "support is unarmed")
	var launcher: = {"equipment_id":"coastal_missiles_russia","visual_kind":"missile_launcher","health":100.0,"level":1}
	check(control.damage_value(launcher,"naval") > 0, "coastal missiles damage ships")
	check(control.damage_value(launcher,"armor") == 0, "coastal missiles do not attack tanks")
	check(EquipmentIdentity.spec("il76md_russia").ground_damage == 0, "transport aircraft are unarmed")
	check(SimulationClock.MOVEMENT_PACE == 3.0, "pending slower movement retained")
	var effects: = CombatEffects.new()
	root.add_child(effects)
	for path in ["res://assets/library/arsenal/russia_p800_oniks.glb", "res://assets/library/arsenal/euro_nsm.glb"]:
		effects.launch(Vector3.ZERO,Vector3(2,0,2),"missile","russia",path)
		check(effects.projectiles.back().node.get_meta("projectile_model", "") == path, "matching missile flight asset")
	effects.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
