extends SceneTree
## Owner 2026-10-16: keep cities reachable when their garrisons cover the centre.
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var city: Dictionary = game.buildings.city("moscow")
	game.rig.target = Vector3(city.point.x, 0, city.point.y)
	game.rig.distance = 12.0
	game.rig._snap(1.0)
	for i in 20: await process_frame
	var screen: Vector2 = game.rig.camera.unproject_position(game.cities.terrain.position_at(city.point) + Vector3.UP * 0.2)
	var armies: Array = game.units.pick_all_screen(game.rig.camera, screen)
	check(not armies.is_empty(), "a real garrison stands under the city tap")
	var opened: Array = []
	game.cities.city_selected.connect(func(place): opened.append(place.id))
	game._map_click(screen, false)
	check(game.units.selected >= 0 and opened.is_empty(), "the first tap selects the garrison")
	for i in armies.size(): game._map_click(screen, false)
	check(opened.has(city.id), "the next taps reach the city after all armies")
	game._map_click(screen, false)
	check(game.units.selected >= 0, "the tap cycle returns to the army")
	print("RESULT CITY_ARMY_TAP checks=", checks, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
