extends SceneTree
func _initialize():call_deferred("run")
func save(name: String):
	for i in 6:await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name))
func run():
	root.size=Vector2i(720,1440)
	GameSession.player_country="russia";GameSession.weapons_test=false
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in 3:await process_frame
	game.mobile_start.hide();game.clock.paused=true;game.units.fog_enabled=false
	game.research_panel.open();game.research_panel.show_category(4)
	await save("Naval_Research_Classes.png")
	game.research_panel.hide()
	game.buildings.levels.moscow.infrastructure=1
	game.buildings.levels.kursk.infrastructure=1
	game.buildings.levels.moscow.airbase=3
	game.buildings.changed.emit()
	game.rig.set_process(false)
	game.rig.target=game.map.position_at(game.buildings.city("moscow").point)
	game.rig.distance=6;game.rig._snap(1.0)
	await save("New_Buildings_Station_And_Tracks.png")
	game.city_panel.open(game.buildings.city("moscow"))
	await save("New_Building_Menu.png")
	game.city_panel.hide()
	var province: Dictionary=game.buildings.provinces.places.values().filter(func(p):return game.production.controlled(p,"russia"))[0]
	game.hud.show_territory(province.region);game.hud.construct_requested.emit()
	await save("Rural_Construction.png")
	game.queue_free();await process_frame;quit()
