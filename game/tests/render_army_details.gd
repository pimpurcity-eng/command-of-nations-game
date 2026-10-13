extends SceneTree
## Owner review: Army Details (Call of War style) for an own and an enemy stack.
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 20: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var moscow: Vector2 = game.buildings.city("moscow").point
	for id in ["tanks_russia", "skyguard_russia", "2b14_mortar_82_russia", "infantry_russia"]:
		for u in game.units.units:
			if u.equipment_id == id: u.stack_id = "showcase"; u.node.position = Vector3(moscow.x, u.node.position.y, moscow.y)
	game.units.stacks.invalidate()
	game.units.units.filter(func(u): return u.equipment_id == "infantry_russia")[0].health = 62.0
	game.units.select_unit(game.units.units.find(game.units.units.filter(func(u): return u.equipment_id == "infantry_russia")[0]))
	game.hud.stack_info_requested.emit()
	await shot("Army_Details_Top")
	game.stack_dialog.content.get_parent().scroll_vertical = 1400
	await shot("Army_Details_Units")
	game.stack_dialog.hide()
	var enemy: Dictionary = game.units.units.filter(func(u): return u.country == "ukraine")[0]
	game.units.select_unit(game.units.units.find(enemy))
	game.hud.stack_info_requested.emit()
	await shot("Army_Details_Enemy")
	quit()
