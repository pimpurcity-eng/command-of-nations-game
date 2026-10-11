extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String):
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(720,1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	game.rig.set_process(false)
	for drone in game.units.units.filter(func(u): return EquipmentIdentity.spec(u.equipment_id).get("role","") == "drone"):
		game.rig.target = drone.node.position
		game.rig.distance = 5
		game.rig._snap(1.0)
		game.units._process(0.016)
		var model: Node3D = drone.node.get_child(0)
		var box: AABB = model.get_meta("pick_bounds")
		for fraction in [0.15,0.5,0.85]:
			var p: Vector3 = model.to_global(box.position + box.size * Vector3(fraction,0.5,0.5))
			game._map_click(game.rig.camera.unproject_position(p),false)
			check(game.units.selected == game.units.units.find(drone),drone.id+" tap visible body/wing "+str(fraction))
		# Repeat at actual flight height, away from the ground marker.
		drone.flight_mode = "patrol"
		game.units.air.position(drone,Vector2(drone.node.position.x,drone.node.position.z))
		var hit: Dictionary = game.units.pick_screen(game.rig.camera,game.rig.camera.unproject_position(model.to_global(box.get_center())))
		check(not hit.is_empty() and hit.index == game.units.units.find(drone),drone.id+" airborne tap")
		drone.flight_mode = "grounded"
	for heli in game.units.units.filter(func(u):return EquipmentIdentity.spec(u.equipment_id).get("role","") == "helicopter" and u.country == "russia"):
		var base: Dictionary = game.units.air.base(heli)
		game.units.select_unit(game.units.units.find(heli))
		game.clock.paused = true
		var origin: Vector3 = heli.node.position
		game.player_order(Vector3(base.point.x+0.4,0,base.point.y+0.4))
		check(not game.clock.paused and heli.flight_mode == "fly",heli.id+" order starts test flight")
		game.clock.advance(0.25)
		check(heli.node.position.distance_to(origin)>0.01,heli.id+" moves on map")
		var rotor: HelicopterAnimator = heli.node.get_child(0).get_meta("helicopter_animator")
		var old: float = rotor.phase
		game.units._process(0.1)
		check(rotor.phase != old,heli.id+" rotors turn in flight")
	var enemy: Dictionary = game.units.units.filter(func(u):return u.country == "ukraine" and u.visual_kind == "armor")[0]
	var helicopter: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "helicopters_russia")[0]
	helicopter.refuel_remaining = 0.0
	var home: Dictionary = game.units.air.base(helicopter)
	game.rig.target = Vector3(home.point.x,0,home.point.y)
	game.rig.distance = 5
	game.rig._snap(1.0)
	game.units.select_unit(game.units.units.find(helicopter))
	game.order_mode = true
	game._map_click(game.rig.camera.unproject_position(game.map.position_at(home.point)+Vector3.UP*0.2),false)
	check(helicopter.target.is_equal_approx(home.point) and not game.order_mode,"Fly order to city issues flight instead of opening city")
	for launcher in game.units.units.filter(func(u):return u.visual_kind == "missile_launcher"):
		game.combat_effects.clear()
		enemy.node.position = launcher.node.position + Vector3(2,0,0)
		game.combat_effects.on_shot(launcher,enemy,"missile")
		var marker: Marker3D = launcher.node.get_child(0).get_meta("missile_launch_point")
		check(not game.combat_effects.projectiles.is_empty(),launcher.id+" launches missile")
		if not game.combat_effects.projectiles.is_empty():
			check(game.combat_effects.projectiles[-1].start.is_equal_approx(marker.global_position),launcher.id+" projectile starts at launcher tip")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
