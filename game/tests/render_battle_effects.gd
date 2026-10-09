extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1000, 700)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.clock.paused = true
	game.mobile_start.hide()
	game.hud.hide()
	game.badges.hide()
	game.units.fog_enabled = false
	var a = game.units.units.filter(func(u): return u.country == "russia" and u.visual_kind == "armor")[0]
	var b = game.units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "armor")[0]
	var origin: Vector3 = game.map.position_at(Vector2(a.node.position.x + 4, a.node.position.z - 4))
	a.node.position = origin
	a.moving = false
	a.equipment_id = "missile_launcher_russia"
	a.visual_kind = "missile_launcher"
	a.node.get_child(0).queue_free()
	var launcher: = UnitVisual.create("missile_launcher", Color.WHITE, "missile_launcher_russia")
	launcher.scale = Vector3.ONE * 0.65
	a.node.add_child(launcher)
	a.node.move_child(launcher, 0)
	b.node.get_child(0).queue_free()
	var tank: = UnitVisual.create("armor", Color.WHITE, "t90")
	tank.scale = Vector3.ONE * 0.65
	b.node.add_child(tank)
	b.node.move_child(tank, 0)
	b.node.position = game.map.position_at(Vector2(origin.x + 2.5, origin.z - 1.4))
	a.heading = atan2(-2.5, 1.4)
	b.heading = a.heading + PI
	for u in game.units.units:
		if u.id != a.id and u.id != b.id: u.node.hide()
	game.units.set_process(false)
	a.node.get_child(0).rotation.y = a.heading
	b.node.get_child(0).rotation.y = b.heading
	UnitShadow.update(a, origin)
	UnitShadow.update(b, b.node.position)
	game.rig.target = origin + Vector3(1.25, 0, -0.7)
	game.rig.distance = 7
	game.rig._snap(1.0)
	for i in 6: await process_frame
	var output: = OS.get_environment("BATTLE_PREVIEW_DIR")
	if output.is_empty(): output = "user://battle-preview"
	DirAccess.make_dir_recursive_absolute(output)
	for frame in 52:
		if frame == 1: game.combat_effects.on_shot(a, b, "missile")
		game.combat_effects.advance_visual(0.08)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%02d.png" % frame))
	quit()
