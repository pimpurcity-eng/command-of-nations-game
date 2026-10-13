extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String):
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	await game.populate_weapons_test()
	game.match_rules.ai_enabled = false
	game.units.at_war = false
	for unit in game.units.units.filter(func(u):return u.visual_kind == "naval"):
		GameSession.player_country = unit.country
		game.units.select_unit(game.units.units.find(unit))
		var start: = Vector2(unit.node.position.x,unit.node.position.z)
		var destination: = start
		for angle in 16:
			var candidate: = start+Vector2.from_angle(float(angle)*TAU/16.0)*0.5
			if game.units.sea_navigation.clear_segment(start,candidate): destination = candidate;break
		check(destination != start,unit.id+" has an accessible water destination")
		check(game.units.order(Vector3(destination.x,0,destination.y)),unit.id+" accepts sea movement")
		game.units.advance(0.05)
		var point: = Vector2(unit.node.position.x,unit.node.position.z)
		check(point.distance_to(start)>0.01,unit.id+" moves on water")
		check(game.units.sea_navigation.on_sea(point),unit.id+" stays on water")
		game.units.stop_selected()
	var sub: Dictionary = game.units.units.filter(func(u):return EquipmentIdentity.spec(u.equipment_id).get("role","") == "submarine")[0]
	var escort: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "fleet_ukraine")[0]
	var scout: Dictionary = game.units.units.filter(func(u):return u.country == "ukraine" and u.visual_kind == "armor")[0]
	for unit in game.units.units:
		if unit.country == "ukraine": unit.node.position = Vector3(40,0,40)
	sub.node.position = Vector3.ZERO
	scout.node.position = Vector3(0.5,0,0)
	game.units.fog_enabled = true
	check(not game.units.visible_to_country(sub,"ukraine"),"ordinary sight does not reveal a submarine")
	escort.node.position = Vector3(1,0,0)
	check(game.units.visible_to_country(sub,"ukraine"),"surface escort sonar reveals submarine")
	var combat: = CombatSystem.new()
	check(combat.damage_value(sub,"carrier")>combat.damage_value(escort,"carrier"),"submarine has a distinct carrier counter")
	check(combat.damage_value(escort,"infantry")>0,"surface missile ship can bombard ground units")
	check(game.match_rules.air_combat.value(escort,"aa_damage")>0,"surface ship provides air defense")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
