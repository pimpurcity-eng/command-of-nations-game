extends SceneTree
## Owner 2026-10-15: 3 tanks, 3 air defence, 1 aircraft, 23 infantry per country;
## three ground units in each of seven cities, remaining infantry singly in provinces.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	for country in ["russia", "ukraine"]:
		var forces: Array = game.units.units.filter(func(u): return u.country == country)
		check(forces.size() == 30, country + " starts with 30 units")
		check(game.session.scenario.countries.any(func(c): return c.id == country and c.starting_force_count == 30), country + " scenario metadata agrees with the real start")
		for spec in [["light_tank_" + country, 3], ["skyguard_" + country, 3], [game.STARTING_PLANE[country], 1], ["infantry_" + country, 23]]:
			check(forces.filter(func(u): return u.equipment_id == spec[0]).size() == spec[1], "%s starts with %d %s" % [country, spec[1], spec[0]])
		check(forces.all(func(u): return u.level == 1), country + " keeps level-1 starters")
		var homes: Array = game.production.cities.filter(func(city): return city.country.to_lower() == country)
		check(homes.size() == 7, country + " has seven starting cities")
		for city in homes:
			var at_city: Array = forces.filter(func(u): return not game.units.air.is_air(u) and CitySystem.near_city(Vector2(u.node.position.x, u.node.position.z), city.point))
			check(at_city.size() == 3, city.name + " starts with three ground units")
		var rural: Array = forces.filter(func(u): return u.visual_kind == "infantry" and not homes.any(func(city): return CitySystem.near_city(Vector2(u.node.position.x, u.node.position.z), city.point)))
		check(rural.size() == 8, country + " has eight remaining infantry in provinces")
		var positions: Dictionary = {}
		for unit in rural:
			var point := Vector2(unit.node.position.x, unit.node.position.z)
			positions[CitySystem.city_key(point)] = true
			check(game.map.territories.any(func(t): return t.playable and t.owner == country and RegionData.contains(t, point)), country + " rural infantry is on its own land")
			check(game.units.stacks.members(unit).size() == 1, country + " rural infantry is a single-unit army")
		check(positions.size() == rural.size(), country + " rural infantry occupy different province posts")
		var planes: Array = forces.filter(func(u): return game.units.air.is_air(u))
		if planes.size() == 1:
			var airport: Dictionary = game.buildings.provinces.places.get(planes[0].base_city, {})
			check(not airport.is_empty() and game.buildings.provinces.level(airport.id, "airbase") == 1, country + " plane keeps its province airport")
			check(planes[0].flight_mode == "grounded", country + " plane starts on the ground")
	print("RESULT starting_force_layout checks=", checks, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
