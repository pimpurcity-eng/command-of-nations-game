extends SceneTree
## The separate 20-player Europe map (owner requests 2026-10-12).
##   godot --headless --path . --script tests/test_europe_map.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(MapDefinition.is_regional(), "the regional campaign map stays the default")
	var view = load("res://scenes/europe_map.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await process_frame
	var map: StrategicMap = view.map
	check(MapDefinition.players().size() == 20, "20 player countries")
	var provinces: = {}
	var cities: = {}
	for t in map.territories:
		if t.playable and t.id.ends_with("_0"): provinces[t.controller] = provinces.get(t.controller, 0) + 1
	for city in view.cities.cities: cities[city.country_id] = cities.get(city.country_id, 0) + 1
	var uneven: = []
	for country in MapDefinition.players():
		var expected: = 27 if country.id == "ukraine" else 25
		if provinces.get(country.id, 0) != expected or cities.get(country.id, 0) != 5: uneven.append("%s %d/%d" % [country.id, provinces.get(country.id, 0), cities.get(country.id, 0)])
	check(uneven.is_empty(), "every player country has 25 provinces (Ukraine 27) and 5 cities (%s)" % [uneven])
	var ai_wrong: Array = MapDefinition.data.ai_countries.filter(func(c: Dictionary): return cities.get(c.id, 0) != 1 or provinces.get(c.id, 0) < 1)
	check(ai_wrong.is_empty(), "every AI country has provinces and one city (%s)" % [ai_wrong.map(func(c): return c.id)])
	check(not MapDefinition.is_player("portugal") and MapDefinition.is_player("russia"), "AI countries are not player slots")
	var owner_at: = func(lon: float, lat: float) -> String:
		var point: = GeographicProjection.project(lon, lat)
		for t in map.territories:
			if RegionData.contains(t, point): return t.controller if t.playable else "context"
		return "sea"
	check(owner_at.call(33.0, 68.9) == "russia" and owner_at.call(33.5, 63.0) == "russia" and owner_at.call(40.5, 64.5) == "russia", "Russia includes Murmansk, Karelia and Arkhangelsk")
	check(owner_at.call(37.6, 55.75) == "russia" and owner_at.call(30.5, 50.45) == "ukraine", "Moscow is Russian and Kyiv Ukrainian")
	check(owner_at.call(60.0, 56.0) == "context", "Russia east of its map part is context land")
	check(owner_at.call(14.5, 46.05) == "slovenia" and owner_at.call(-0.12, 51.5) == "united_kingdom", "small countries and capitals are on the map")
	check(map.province_hubs.size() >= 20 * 25, "every province has a road hub (%d)" % map.province_hubs.size())
	view._back.call()
	check(MapDefinition.is_regional(), "leaving the Europe map restores the regional map")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
