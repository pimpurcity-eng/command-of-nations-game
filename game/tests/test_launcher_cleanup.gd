extends SceneTree
## Removing an army or replacing its model must cancel pending physical launch animations.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var effects := CombatEffects.new()
	root.add_child(effects)
	for silo in [false, true]:
		var army := Node3D.new()
		var model := Node3D.new()
		root.add_child(army)
		army.add_child(model)
		var moving_part := Node3D.new()
		model.add_child(moving_part)
		var source := {"node": army, "equipment_id": "silos_russia" if silo else "missiles_russia", "country": "russia", "level": 1}
		if silo:
			var missile := Node3D.new()
			model.add_child(missile)
			for pair in [["silo_lid", moving_part], ["silo_missile", missile], ["silo_lid_rest", Vector3.ZERO], ["silo_missile_rest", Vector3.ZERO], ["silo_missile_length", 1.0], ["silo_lid_slide", 1.0], ["silo_rise", 1.0]]: model.set_meta(pair[0], pair[1])
			effects.silo_launch(source, Vector3(3, 0, 0), "")
		else:
			model.set_meta("erector_hinge", moving_part)
			model.set_meta("erector_mouth", Vector3.RIGHT)
			effects.erect_and_launch(source, Vector3(3, 0, 0), "")
		var pending: Array = get_processed_tweens().duplicate()
		check(not pending.is_empty(), "physical launch has a pending animation")
		# The army can survive while its model is swapped for an upgraded/low-memory visual.
		army.remove_child(model)
		model.queue_free()
		for frame in 3: await process_frame
		check(pending.all(func(tween): return not tween.is_valid()), "removing the model cancels its launch animation")
		for frame in 180: await process_frame
		check(effects.projectiles.is_empty(), "a removed launcher cannot emit a delayed projectile")
		army.queue_free()
	effects.queue_free()
	await process_frame
	print("RESULT LAUNCHER_CLEANUP checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
