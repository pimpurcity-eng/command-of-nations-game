extends SceneTree
## Every live equipment family at each research level (rows = families, columns = levels),
## facing north (up). Review aid.  godot --path . --script tests/tier_lineup.gd -- <out.png>
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1500, 1800)
	var world: = Node3D.new()
	root.add_child(world)
	var env: = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("cfcab8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	world.add_child(sun)
	var ids: Array = EquipmentIdentity.catalog.map(func(e: Dictionary): return e.id)
	var cam: = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ids.size() * 1.6 + 0.6
	cam.position = Vector3(2 * 2.4, 30, (ids.size() - 1) * 0.8)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	world.add_child(cam)
	for row in ids.size():
		var spec: Dictionary = EquipmentIdentity.spec(ids[row])
		for level in range(1, 6):
			var model: Node3D = UnitVisual.create(spec.get("visual_kind", "armor"), Color.WHITE, ids[row], level)
			model.scale = Vector3.ONE * 0.65
			model.position = Vector3((level - 1) * 2.4, 0, row * 1.6)
			world.add_child(model)
		var label: = Label3D.new()
		label.text = ids[row]
		label.font_size = 30
		label.pixel_size = 0.006
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(-1.9, 1, row * 1.6)
		label.modulate = Color.BLACK
		world.add_child(label)
	for i in 12: await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
