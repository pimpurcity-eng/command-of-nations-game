extends SceneTree
## The 100-player world map (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_world_map.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var started: = Time.get_ticks_msec()
	var view = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	print("world map built in %d ms" % (Time.get_ticks_msec() - started))
	await process_frame
	var map: StrategicMap = view.map
	check(MapDefinition.id == "world100" and MapDefinition.players().size() == 100, "100 player countries")
	var provinces: = {}
	var cities: = {}
	for t in map.territories:
		if t.playable and t.id.ends_with("_0"): provinces[t.controller] = provinces.get(t.controller, 0) + 1
	for city in view.cities.cities: cities[city.country_id] = cities.get(city.country_id, 0) + 1
	var uneven: = MapDefinition.players().filter(func(c: Dictionary): return provinces.get(c.id, 0) != 15 or cities.get(c.id, 0) != 5)
	check(uneven.is_empty(), "every player country has 15 provinces and 5 cities (%s)" % [uneven.map(func(c): return c.id)])
	var ai: Array = MapDefinition.data.ai_countries
	check(ai.size() > 50 and ai.all(func(c: Dictionary): return cities.get(c.id, 0) == 1 and provinces.get(c.id, 0) >= 1), "every AI country has provinces and one city")
	var owner_at: = func(lon: float, lat: float) -> String:
		var point: = GeographicProjection.project(lon, lat)
		for t in map.territories:
			if RegionData.contains(t, point): return t.controller
		return "sea"
	check(owner_at.call(-98.0, 39.0) == "united_states" and owner_at.call(105.0, 35.0) == "china" and owner_at.call(-55.0, -10.0) == "brazil", "USA, China and Brazil are where they belong")
	check(owner_at.call(130.0, 62.0) == "russia" and owner_at.call(37.6, 55.75) == "russia", "the whole of Russia, Siberia included")
	check(owner_at.call(-30.0, 30.0) == "sea", "the Atlantic is sea")
	var back: = GeographicProjection.unproject(GeographicProjection.project(-70.0, -33.0))
	check(back.distance_to(Vector2(-70.0, -33.0)) < 0.001, "the Equal Earth projection round-trips")
	view._back.call()
	check(MapDefinition.is_regional(), "leaving the world map restores the regional map")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
