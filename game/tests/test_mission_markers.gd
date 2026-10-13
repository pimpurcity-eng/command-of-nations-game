extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String):
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(720,1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	for unit in game.units.units.filter(func(u):return game.units.air.is_air(u)):
		GameSession.player_country = unit.country
		var point: Vector2 = game.units.air.base(unit).point + Vector2(0.4,0.4)
		check(game.units.air.order(unit,point,"patrol").is_empty(),unit.id+" patrol accepted")
		game.units._draw_route()
		var key: String = unit.country+":"+unit.stack_id
		check(game.units.order_markers.has(key),unit.id+" patrol marker exists")
		if game.units.order_markers.has(key):
			var marker: Node3D = game.units.order_markers[key]
			check(marker.get_meta("order_kind") == "patrol" and Vector2(marker.position.x,marker.position.z).is_equal_approx(point),unit.id+" marker at patrol centre")
			game.units.air.advance(unit,0.01)
			game.units._draw_route()
			check(Vector2(marker.position.x,marker.position.z).is_equal_approx(point),unit.id+" marker stays at patrol spot during flight")
		check(not game.units.route.visible,unit.id+" has no flight lines")
		game.units.air.return_home(unit)
		game.units._draw_route()
		check(not game.units.order_markers.has(key),unit.id+" marker clears on Return")
		unit.flight_mode = "grounded"
		unit.moving = false
	for launcher in game.units.units.filter(func(u):return u.visual_kind == "missile_launcher"):
		GameSession.player_country = launcher.country
		var enemy: Dictionary = game.units.units.filter(func(u):return u.country != launcher.country and u.visual_kind == "armor")[0]
		launcher.attack_target = enemy.id
		game.units._draw_route()
		var key: String = launcher.country+":"+launcher.stack_id
		check(game.units.order_markers.has(key),launcher.id+" target marker exists")
		if game.units.order_markers.has(key):
			var marker: Node3D = game.units.order_markers[key]
			check(marker.get_meta("order_kind") == "missile" and Vector2(marker.position.x,marker.position.z).is_equal_approx(Vector2(enemy.node.position.x,enemy.node.position.z)),launcher.id+" marker on target")
		check(not game.units.route.visible,launcher.id+" has no target line")
		launcher.attack_target = ""
		game.units._draw_route()
		check(not game.units.order_markers.has(key),launcher.id+" marker clears on cancellation")
	for unit in game.units.units.filter(func(u):return u.country == "ukraine"):
		var point: = Vector2(unit.node.position.x,unit.node.position.z)
		var closest: Dictionary = {}
		var distance: = INF
		for city in GeographicProjection.load_cities():
			if city.country.to_lower() == "russia" and point.distance_squared_to(city.point) < distance:
				distance = point.distance_squared_to(city.point)
				closest = city
		var actual: Vector3 = Basis(Vector3.UP,game.units._facing_enemy("ukraine",point))*Vector3.FORWARD
		var direction: Vector2 = (closest.point-point).normalized()
		check(actual.is_equal_approx(Vector3(direction.x,0,direction.y)),unit.id+" idle bearing points toward Russia")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
