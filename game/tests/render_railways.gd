extends SceneTree
## Owner 2026-10-13: "no train tracks at the start until you connect railway stations ... the
## railroads look like crap". Renders the capital-only start and a connected Moscow network.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_railways.gd
func _initialize() -> void: call_deferred("run")
var game
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func look(city: String, distance: float) -> void:
	var at: Vector2 = game.buildings.city(city).point
	game.rig.target = Vector3(at.x, 0, at.y)
	game.rig.distance = distance
	game.rig._snap(1.0)
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var railway: RailwayMap = game.map.get_node("Railways")
	print("RAIL start links=", railway.links.size())
	look("moscow", 30.0)
	await shot("Rail_Start")
	for id in ["tula", "bryansk", "kursk", "belgorod"]:
		if not game.buildings.city(id).is_empty(): game.buildings.levels[id]["train_station"] = 1
	game.buildings.changed.emit()
	print("RAIL connected links=", railway.links.size(), " ", railway.links.map(func(l): return l.a + "-" + l.b))
	look("tula", 30.0)
	await shot("Rail_Network")
	look("tula", 12.0)
	await shot("Rail_Close")
	look("tula", 5.0)
	await shot("Rail_Closest")
	var mid: Vector2 = (game.buildings.city("tula").point + game.buildings.city("moscow").point) * 0.5
	game.rig.target = Vector3(mid.x, 0, mid.y)
	game.rig.distance = 2.0
	game.rig._snap(1.0)
	await shot("Rail_Detail")
	quit()
