extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool,message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func tap(game: Node,army: Dictionary) -> void:
	game.rig.target = Vector3(army.node.position.x,0,army.node.position.z)
	game.rig.distance = 5
	game.rig._snap(1.0)
	game._map_click(game.rig.camera.unproject_position(army.node.position+Vector3.UP*0.3),false)
func run() -> void:
	root.size = Vector2i(720,1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	for i in 3: await process_frame
	game.mobile_start.hide()
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.units.fog_enabled = false
	game.rig.set_process(false)
	var armies: Array = game.units.units.filter(func(u):return u.country == "russia" and u.equipment_id == "tanks_russia")
	game.units.select_unit(game.units.units.find(armies[0]))
	game.open_army_selection()
	check(game.selecting_armies and game.army_selection == null,"map selection without list")
	tap(game,armies[1])
	check(game.units.command_ids.has(armies[0].id) and game.units.command_ids.has(armies[1].id),"add second army")
	tap(game,armies[2])
	check(game.units.command_ids.size() == 3,"add third army")
	tap(game,armies[1])
	check(not game.units.command_ids.has(armies[1].id) and game.units.command_ids.size() == 2,"tap again removes army")
	tap(game,armies[1])
	var enemy: Dictionary = game.units.units.filter(func(u):return u.country == "ukraine")[0]
	tap(game,enemy)
	check(game.units.command_ids.size() == 3 and GameSession.player_country == "russia","enemy tap preserves side/selection")
	# Ground armies are drawn bigger since 2026-10-14; pick a meeting point clear of every army.
	var destination: Vector3 = armies[0].node.position+Vector3(2,0,2)
	var screen: Vector2
	for offset in [Vector3(2,0,2),Vector3(-2,0,2),Vector3(2,0,-2),Vector3(-2,0,-2),Vector3(3,0,0),Vector3(0,0,3),Vector3(-3,0,0),Vector3(0,0,-3)]:
		destination = armies[0].node.position+offset
		game.rig.target = Vector3(destination.x,0,destination.z)
		game.rig.distance = 5
		game.rig._snap(1.0)
		screen = game.rig.camera.unproject_position(Vector3(destination.x,0,destination.z))
		if game.units.pick_screen(game.rig.camera,screen).is_empty(): break
	check(game.units.pick_screen(game.rig.camera,screen).is_empty(),"meeting point empty")
	game._map_click(screen,false)
	check(not game.selecting_armies and not game.order_mode,"meeting tap completes selection")
	check(armies.slice(0,3).all(func(u):return u.moving),"three armies receive meeting movement")
	check(game.units.command_groups().size() == 3,"chosen armies stay selected")
	game.rig.target = Vector3(armies[0].node.position.x,0,armies[0].node.position.z)
	game.rig.distance = 10
	game.rig._snap(1.0)
	for i in 5: await process_frame
	if not OS.get_cmdline_user_args().is_empty(): root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	game.open_army_selection()
	game._set_order_mode(false)
	check(not game.selecting_armies,"Cancel leaves selection")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
