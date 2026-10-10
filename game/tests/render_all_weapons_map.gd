extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(720,1440)
	GameSession.player_country = "ukraine"
	GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	game.rig.set_process(false)
	for entry in [["drones_ukraine", 4, 13.0, "Real_Map_Drones.png"], ["carriers_ukraine", 1, 15.0, "Real_Map_Fleet.png"], ["missiles_ukraine", 3, 12.0, "Real_Map_Missiles.png"], ["helicopters_russia", 1, 10.0, "Real_Map_Helicopter.png"]]:
		var unit: Dictionary = game.units.units.filter(func(u): return u.equipment_id == entry[0] and u.level == entry[1])[0]
		game.units.select_unit(game.units.units.find(unit))
		if unit.equipment_id == "helicopters_russia":
			var center: = Vector2(unit.node.position.x,unit.node.position.z)
			game.units.air.order(unit,center + Vector2(0.3,0.3),"patrol")
			game.units.air.advance(unit,0.03)
		game.rig.target = Vector3(unit.node.position.x,0,unit.node.position.z)
		game.rig.distance = entry[2]
		game.rig._snap(1.0)
		game.refresh_hud()
		for i in 10: await process_frame
		root.get_texture().get_image().save_png(output.path_join(entry[3]))
	print("REVIEW live_weapons=",game.units.units.size()," local_roads=",StrategicMap.road_graph(game.map.territories).edges.size())
	quit()
