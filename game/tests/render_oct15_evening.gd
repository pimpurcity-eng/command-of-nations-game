extends SceneTree
## Pictures for the owner list of 2026-10-15 (evening): city buildings outside the houses, the
## garden-sized square, a battle at close quarters, a refuelling plane and the country names.
##   SHOT_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_oct15_evening.gd
func _initialize() -> void: call_deferred("run")
var game
func shot(point: Vector2, distance: float, name: String, frames: int = 60) -> void:
	game.rig.target = Vector3(point.x, 0, point.y)
	game.rig.distance = distance
	game.rig._snap(1.0)
	for i in frames: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))
func put(unit: Dictionary, point: Vector2) -> void:
	for member in game.units.stacks.members(unit):
		member.node.position = game.units.surface_position(member, point)
		member.target = point
		member.moving = false
		member.waypoints.clear()
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var moscow: Dictionary = game.buildings.city("moscow")
	for id in ["industry", "barracks", "tank_plant", "airbase", "factory", "missile_factory", "recruitment_center", "train_station"]:
		if not game.buildings.levels.has(moscow.id): game.buildings.levels[moscow.id] = {}
		game.buildings.levels[moscow.id][id] = 2
	game.buildings.changed.emit()
	await shot(moscow.point, 9.0, "Moscow_buildings")
	var units: UnitSystem = game.units
	var kharkiv: Dictionary = game.buildings.city("kharkiv")
	await shot(CitySystem.plaza_point(kharkiv.point), 5.0, "Kharkiv_square")
	# A battle in the open.
	game.match_rules.declare_war()
	var russian: Dictionary = units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "infantry")[0]
	var tank: Array = units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "armor")
	var ukrainian: Dictionary = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "infantry")[0]
	var field: Vector2 = kharkiv.point + Vector2(2.6, 1.2)
	put(ukrainian, field)
	put(russian, field + Vector2(0.4, 0.05))
	if not tank.is_empty(): put(tank[0], field + Vector2(0.05, 0.42))
	game.clock.paused = false
	for i in 40:
		game.clock.advance(0.2)
		await process_frame
	game.clock.paused = true
	game.combat_effects.clock.paused = false
	await shot(field, 4.0, "Battle", 50)
	# A plane refuelling.
	var plane: Dictionary = units.units.filter(func(u): return u.country == "russia" and units.air.is_air(u))[0]
	plane.flight_mode = "grounded"
	plane.refuel_remaining = 12.0
	units.air.position(plane, units.air.base(plane).point)
	await shot(units.air.base(plane).point, 4.0, "Refuel")
	# Country names after Russia takes eastern Ukraine.
	for t in game.map.territories:
		if t.playable and t.owner == "ukraine" and t.center.x > kharkiv.point.x - 2.0: game.match_rules.change_control(t, "russia")
	game.map.update_relations(true)
	await shot(kharkiv.point, 60.0, "Country_names")
	quit()
