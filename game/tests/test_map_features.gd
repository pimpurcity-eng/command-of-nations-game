extends SceneTree
## Checks for the owner's phone review (2026-10-09): roads to every province, resource sites
## that pay their province's controller, vehicles resting on the drawn ground, and movement
## that is visible within half a minute.
##   godot --headless --path . --script tests/test_map_features.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.apply_player_country()
	game.clock.paused = true
	game.match_rules.ai_enabled = false

	# 1. Roads: every province (except the Kaliningrad exclave) is reached by a local road.
	var edges: Array = StrategicMap.road_network(game.map.territories)
	var largest: = {}
	for t in game.map.territories:
		if t.playable and StrategicMap._polygon_area(t.polygon) > largest.get(t.title, [-1.0])[0]: largest[t.title] = [StrategicMap._polygon_area(t.polygon), t.center]
	var unreached: = []
	for title in largest:
		var center: Vector2 = largest[title][1]
		if not edges.any(func(e: Array): return e[0].distance_to(center) < 0.11 or e[1].distance_to(center) < 0.11): unreached.append(title)
	unreached.erase("Kaliningrad region")
	check(unreached.is_empty(), "a road reaches every province (unreached: %s)" % [unreached])

	# 2. Resource sites: placed in playable provinces, with city specialties, paying the controller.
	var sites: ResourceSites = game.resource_sites
	check(sites.sites.size() >= 40, "resource sites are scattered across the provinces (%d)" % sites.sites.size())
	var kinds: = {}
	for site in sites.sites: kinds[site.resource] = true
	check(kinds.has_all(["fuel", "materials", "electronics", "manpower"]), "oil, mines, plants and farmland are all present")
	check(ResourceSites.city_resources("Kursk").has("materials"), "cities list their resource specialties")
	var fuel_site: Dictionary = {}
	for site in sites.sites:
		if site.resource == "fuel" and site.territory.controller == "ukraine": fuel_site = site
	check(not fuel_site.is_empty(), "Ukraine holds an oil or gas field")
	var earned: Dictionary = sites.income(10.0)
	check(earned.get("ukraine", {}).get("fuel", 0.0) > 0.0, "a site earns its resource for the province's controller")
	var original: String = fuel_site.territory.controller
	fuel_site.territory.controller = "russia"
	var before: float = sites.income(10.0).get("russia", {}).get("fuel", 0.0)
	fuel_site.territory.controller = original
	check(before > sites.income(10.0).get("russia", {}).get("fuel", 0.0), "capturing the province transfers the site's income")
	var stock_before: float = game.production.stockpiles.russia.fuel
	game.production.advance(1.0)
	check(game.production.stockpiles.russia.fuel > stock_before, "production adds city and site income")

	# 3. Ground: the height used for placement matches the drawn ground, and vehicles rest on it.
	var units: UnitSystem = game.units
	var off_ground: = 0
	for unit in units.units:
		if units.is_naval(unit) or units.air.is_air(unit): continue
		var p: = Vector2(unit.node.position.x, unit.node.position.z)
		if absf(unit.node.position.y - game.map.elevation(p)) > 0.001: off_ground += 1
	check(off_ground == 0, "vehicles sit on the ground, not raised above it (%d off)" % off_ground)
	var sloped: = Vector2(9.0, -14.0)
	var normal: Vector3 = units.ground_normal(sloped)
	check(normal.is_normalized() and normal.y > 0.5, "vehicles tilt with the ground slope")
	var hill: Vector3 = game.map_position(36.5, 50.2)
	var ray: = PhysicsRayQueryParameters3D.create(Vector3(hill.x, 50, hill.z), Vector3(hill.x, -50, hill.z))
	await physics_frame
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y - game.map.elevation(Vector2(hill.x, hill.z))) < 0.01, "placement height equals the drawn ground")

	# 4. Movement: an ordered tank visibly moves within 30 real seconds at 1x.
	var tank: Dictionary = {}
	for unit in units.units:
		if unit.country == "russia" and unit.visual_kind == "armor": tank = unit
	units.select_unit(units.units.find(tank))
	var start: = Vector2(tank.node.position.x, tank.node.position.z)
	var goal: Vector3 = game.map_position(39.2, 51.66)  # Voronezh
	game.player_order(goal)
	check(tank.moving, "the move order is accepted")
	var route_points: = []
	for road in game.map.roads: route_points.append_array(Array(StrategicMap.road_curve(road[0], road[1], road[2])))
	var off_road: = 0
	for waypoint in tank.waypoints.slice(1):
		var nearest: = INF
		for point in route_points: nearest = minf(nearest, point.distance_to(waypoint))
		if nearest > 0.001: off_road += 1
	check(tank.waypoints.size() > 2 and off_road == 0, "the route follows the roads (%d of %d points off-road)" % [off_road, tank.waypoints.size()])
	check(game.map.province_hubs.values().any(func(hub: Vector2): return hub.distance_to(tank.target) < 0.001), "armies travel to a province centre")
	game.clock.paused = false
	for step in 30: game.clock.advance(1.0)
	var moved: = Vector2(tank.node.position.x, tank.node.position.z).distance_to(start)
	check(moved > 0.3, "a tank moves visibly in 30 seconds (%.2f map units)" % moved)
	# 5. Research is national: it runs at full speed even without the capital.
	check(game.research.rate("russia") == 1.0, "research does not depend on a city")
	for city in game.cities.cities:
		if city.name == "Moscow":
			for t in game.map.territories:
				if t.id == city.sector: t.controller = "ukraine"
	check(game.research.rate("russia") == 1.0, "losing the capital does not stop research")
	check(not game.city_panel.rows.has("research_center"), "the city menu has no research building")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
