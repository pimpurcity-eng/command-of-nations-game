extends SceneTree
## Owner 2026-10-13: "you can't click on the cities when units are there" and "no train tracks at
## the start until you connect railway stations; one station in the capital already built".
##   xvfb-run -a godot --path . --script tests/test_city_tap_rail.gd
var failures: = 0
var checks: = 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	# Railways.
	var railway: RailwayMap = game.map.get_node("Railways")
	for city in game.cities.cities:
		var capital: bool = game.buildings.is_capital(city)
		check(game.buildings.level(city.id, "train_station") == (1 if capital else 0), "only the capital starts with a train station: " + city.name)
	check(railway.links.is_empty() and railway.get_child_count() == 0, "no railway lines at the start")
	var moscow: Dictionary = game.buildings.city("moscow")
	var tula: Dictionary = game.buildings.city("tula")
	check(game.trade.rail_factor(moscow.point, "russia") == 1.0, "no rail speed before a line exists")
	game.buildings.levels.tula.train_station = 1
	game.buildings.changed.emit()
	check(railway.links.size() == 1 and railway.get_child_count() > 0, "a second station joins the capital by rail")
	check(game.trade.rail_factor(tula.point, "russia") == 2.0 and game.trade.rail_factor(moscow.point, "russia") == 2.0, "armies move faster along the new line")
	var land_only: bool = true
	for point in railway.links[0].route:
		if game.units.navigation.controller_at(point) != "russia": land_only = false
	check(land_only, "the line stays on Russian land")
	game.buildings.levels.kursk.train_station = 1
	game.buildings.levels.bryansk.train_station = 1
	game.buildings.changed.emit()
	check(railway.links.size() == 3, "four stations make one network of three lines (%d)" % railway.links.size())
	game.buildings.levels.kyiv.train_station = 1
	game.buildings.changed.emit()
	check(railway.links.all(func(l): return l.country == "russia"), "no line between enemy stations")
	# Tapping a city that has armies on it.
	var at: Vector3 = game.map.position_at(moscow.point)
	game.rig.target = Vector3(at.x, 0, at.z)
	game.rig.distance = 12.0
	game.rig._snap(1.0)
	for i in 10: await process_frame
	var screen: Vector2 = game.rig.camera.unproject_position(game.cities.terrain.position_at(moscow.point) + Vector3.UP * 0.2)
	var garrison: Array = game.units.pick_all_screen(game.rig.camera, screen)
	check(not garrison.is_empty(), "armies stand on Moscow (%d under the tap)" % garrison.size())
	var opened: Array = []
	game.cities.city_selected.connect(func(city): opened.append(city.id))
	game._map_click(screen, false)
	check(game.units.selected >= 0 and opened.is_empty(), "first tap selects the army on the city")
	for i in garrison.size(): game._map_click(screen, false)
	check(opened.has("moscow"), "tapping again reaches the city (%d taps)" % (garrison.size() + 1))
	game._map_click(screen, false)
	check(game.units.selected >= 0, "and then back to the army")
	print("RESULT checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
