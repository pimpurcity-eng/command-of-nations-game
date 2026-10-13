extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720,1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	game.rig.set_process(false)
	check(game.units.units.all(func(u):return is_equal_approx(u.heading,game.units._facing_enemy(u.country,Vector2(u.node.position.x,u.node.position.z)))),"idle units face their opposing country")
	# Enemy ships first, own ships last, so the final selection is one the player commands.
	var ships: Array = game.units.units.filter(func(u):return u.visual_kind == "naval")
	ships.sort_custom(func(a,b):return a.country != GameSession.player_country and b.country == GameSession.player_country)
	for ship in ships:
		game.rig.target = Vector3(ship.node.position.x,0,ship.node.position.z)
		game.rig.distance = 8
		game.rig._snap(1.0)
		game.units._process(0.016)
		check(ship.node.position.y < 0,ship.id+" hull intersects water")
		check(not ship.node.get_meta("ground_shadow").visible,ship.id+" no floating shadow")
		var model: Node3D = ship.node.get_child(0)
		var box: AABB = model.get_meta("pick_bounds")
		for end in [0.25,0.75]:
			var point: = model.global_transform * Vector3(box.get_center().x,box.get_center().y,box.position.z+box.size.z*end)
			game._map_click(game.rig.camera.unproject_position(point),false)
			check(game.units.selected == game.units.units.find(ship),ship.id+" tap hull "+str(end))
	check(game.hud.action_row.visible and not game.hud.move_button.disabled,"selected ship commands visible")
	var plane: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "bombers_russia")[0]
	game.units.select_unit(game.units.units.find(plane))
	var origin: = Vector2(plane.node.position.x,plane.node.position.z)
	check(game.units.order(Vector3(origin.x+1,0,origin.y+1)),"plane accepts flight")
	check(not game.units.route.visible,"no flight lines")
	plane.attack_target = game.units.units.filter(func(u):return u.country == "ukraine")[0].id
	game.units._draw_route()
	check(not game.units.route.visible,"no aircraft attack lines")
	game.units.stop_selected()
	var enemy: Dictionary = game.units.units.filter(func(u):return u.country == "ukraine" and u.visual_kind == "armor")[0]
	game.match_rules.declare_war()
	for family in ["artillery_russia","missiles_russia","silos_russia"]:
		var launcher: Dictionary = game.units.units.filter(func(u):return u.equipment_id == family)[0]
		game.units.select_unit(game.units.units.find(launcher))
		enemy.node.position = launcher.node.position+Vector3(2,0,0)
		if family == "artillery_russia": launcher.moving = true
		check(game.units.attack_selected(enemy),family+" in-range attack accepted")
		check(not launcher.moving and launcher.attack_target == enemy.id,family+" fires without moving")
		var health: float = enemy.health
		game.match_rules.combat.cooldowns.clear()
		game.combat_effects.clear()
		game.match_rules.advance_battles(0.001)
		check(enemy.health < health,family+" damages target")
		check(game.combat_effects.projectiles.any(func(j):return j.effect == ("artillery" if family == "artillery_russia" else "missile")),family+" real combat projectile")
		enemy.health = 100
		launcher.attack_target = ""
	game.units.fog_enabled = false
	game.fog.mask = null
	game.fog.refresh(true)
	check(game.fog.mask == null,"disabled fog skips mask generation")
	game.units.fog_enabled = true
	game.fog.refresh(true)
	check(game.fog.mask != null,"enabled fog still works")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
