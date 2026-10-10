extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in 12: await process_frame
	var folder: String = OS.get_environment("BUILDING_PREVIEW_DIR")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func record_deployment(game: Node, unit: Dictionary, name: String) -> void:
	var folder: String = OS.get_environment("BUILDING_PREVIEW_DIR").path_join(name + "_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	game.units.set_process(false)
	for member in game.units.units: member.node.visible = member.id == unit.id
	game.rig.target = unit.node.position
	game.rig.distance = 4.5
	game.rig._snap(1.0)
	var animator: AirDefenseAnimator = unit.node.get_child(0).get_meta("air_defense_animator")
	animator.deployed = 0.0
	animator.moving = false
	var enemy_country: String = "ukraine" if unit.country == "russia" else "russia"
	var point: Vector2 = Vector2(unit.node.position.x - 0.85, unit.node.position.z - 0.8)
	game.units._spawn({"id": "preview_aircraft", "name": "Aircraft", "country": enemy_country, "equipment_id": "su57_" + enemy_country, "visual_kind": "fighter", "flight_mode": "patrol"}, point, Color.WHITE)
	var enemy: Dictionary = game.units.units[-1]
	for frame in 60:
		animator.animate(0.07)
		if frame == 32: game.combat_effects.on_shot(unit, enemy, "interceptor")
		game.combat_effects.advance_visual(0.07)
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(folder.path_join("%03d.png" % frame))
	game.units.units.pop_back().node.queue_free()
	game.combat_effects.clear()
	game.units.set_process(true)
func run() -> void:
	root.size = Vector2i(1200, 850)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	for country in ["russia", "ukraine"]:
		GameSession.player_country = country
		game.apply_player_country()
		game.units.restore([])
		var capital: Dictionary = game.buildings.capital(country)
		var variants: Array = [["skyguard_", 1], ["skyguard_", 3], ["patriot_", 1], ["patriot_", 3], ["patriot_", 5]]
		for i in variants.size():
			var id: String = variants[i][0] + country
			var data: Dictionary = {"id": "lineup_" + str(i), "name": EquipmentIdentity.research_title(id, variants[i][1]), "country": country, "equipment_id": id, "visual_kind": "air_defense", "level": variants[i][1]}
			game.units._spawn(data, capital.point + Vector2(1.4 + i * 0.95, 1.1), Color("c7caa0"))
		for unit in game.units.units:
			unit.heading = atan2(0.5, -0.8660254 / sin(0.55))
			unit.node.get_child(0).rotation.y = unit.heading
			var animator: AirDefenseAnimator = unit.node.get_child(0).get_meta("air_defense_animator")
			animator.animate(2.0)
		game.units.select_unit(4)
		game.rig.target = game.units.units[2].node.position
		game.rig.distance = 7.5
		game.rig.pitch = 0.55
		game.rig.yaw = 0.0
		game.rig._snap(1.0)
		await capture("Russian_Air_Defense_Map" if country == "russia" else "European_Air_Defense_Map")
		if OS.get_environment("AIR_RECORD") == "1":
			await record_deployment(game, game.units.units[4], "Russian_Deployment" if country == "russia" else "European_Deployment")
		# Close view of the selected launcher in a city; the range remains at full map scale.
		root.size = Vector2i(720, 1440)
		var selected: Dictionary = game.units.units[4]
		selected.node.position = game.map.position_at(capital.point + Vector2(0.3, 0.15))
		game.units._process(1.0)
		game.units._process(0.016)
		game.units.set_process(false)
		for member in game.units.units: member.node.visible = member.id == selected.id
		game.rig.target = selected.node.position
		game.rig.distance = 4.5
		game.rig._snap(1.0)
		await capture("Russian_City_Air_Defense" if country == "russia" else "European_City_Air_Defense")
		game.research_panel.open()
		game.research_panel.show_category(4)
		game.research_panel.selected_id = "patriot_" + country
		game.research_panel.selected_level = 5
		game.research_panel.message.text = ""
		game.research_panel._refresh()
		var scroll: ScrollContainer = game.research_panel.grid.get_parent()
		scroll.scroll_vertical = 600
		await capture("Russian_Air_Defense_Research" if country == "russia" else "European_Air_Defense_Research")
		game.research_panel.hide()
		game.units.set_process(true)
		root.size = Vector2i(1200, 850)
	quit()
