extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(game: Node,unit: Dictionary,distance: float,name: String) -> void:
	game.units.select_unit(game.units.units.find(unit))
	game.rig.target = Vector3(unit.node.position.x,0,unit.node.position.z)
	game.rig.distance = distance
	game.rig._snap(1.0)
	game.refresh_hud()
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name))
func run() -> void:
	root.size = Vector2i(720,1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	game.rig.set_process(false)
	var ship: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "carriers_ukraine")[0]
	await capture(game,ship,15,"Ships_At_Waterline.png")
	var plane: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "bombers_russia")[0]
	game.units.select_unit(game.units.units.find(plane))
	var p: = Vector2(plane.node.position.x,plane.node.position.z)
	game.units.order(Vector3(p.x+3,0,p.y+3))
	game.units.air.advance(plane,0.1)
	game.units._draw_route()
	await capture(game,plane,14,"Aircraft_No_Flight_Lines.png")
	game.units.stop_selected()
	var launcher: Dictionary = game.units.units.filter(func(u):return u.equipment_id == "missiles_russia" and u.level == 2)[0]
	var enemy: Dictionary = game.units.units.filter(func(u):return u.country == "ukraine" and u.visual_kind == "armor")[0]
	enemy.node.position = launcher.node.position+Vector3(3,0,0)
	game.units.select_unit(game.units.units.find(launcher))
	game.match_rules.declare_war()
	game.units.attack_selected(enemy)
	game.match_rules.advance_battles(0.001)
	game.combat_effects.advance_visual(0.4)
	game.combat_effects.set_process(false)
	await capture(game,launcher,9,"Missile_Actual_Launch.png")
	print("REVIEW real missile projectiles=",game.combat_effects.projectiles.size())
	game.queue_free()
	await process_frame
	quit()
