extends SceneTree
## Renders every equipment model as the game shows it, facing "north" (heading 0 = up on
## screen), to check model size and facing. Usage:
##   godot --path . --script tests/model_lineup.gd -- <output.png> [russia|ukraine|all]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: = OS.get_cmdline_user_args()
	var out: String = args[0]
	var only: String = args[1] if args.size() > 1 else "all"
	root.size = Vector2i(1600, 1200)
	var world: = Node3D.new()
	root.add_child(world)
	var env: = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d8d4c4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	world.add_child(sun)
	var ids: Array = []
	for e in EquipmentIdentity.catalog:
		if only == "all" or e.get("country", "") == only or e.id in only.split(","): ids.append(e.id)
	var columns: = mini(7, ids.size())
	var rows: = ceili(ids.size() / float(columns))
	var cam: = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows * 1.25, columns * 1.3 * root.size.y / float(root.size.x)) + 0.4
	cam.position = Vector3((columns - 1) * 0.65, 30, (rows - 1) * 0.625 + 0.25)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	world.add_child(cam)
	var i: = 0
	for id in ids:
		var spec: Dictionary = EquipmentIdentity.spec(id)
		var model: Node3D = UnitVisual.create(spec.get("visual_kind", "armor"), Color.WHITE, id)
		model.scale = Vector3.ONE * 0.65
		var cell: = Vector3((i % columns) * 1.3, 0, (i / columns) * 1.25)
		model.position = cell
		world.add_child(model)
		var label: = Label3D.new()
		label.text = id + ("\n(no original model)" if model.get_meta("missing_original_model", false) else "")
		label.font_size = 26
		label.pixel_size = 0.0045
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = cell + Vector3(0, 1, 0.5)
		label.modulate = Color.BLACK
		world.add_child(label)
		var arrow: = Label3D.new()
		arrow.text = "▲"
		arrow.font_size = 30
		arrow.pixel_size = 0.005
		arrow.rotation_degrees = Vector3(-90, 0, 0)
		arrow.position = cell + Vector3(-0.55, 1, -0.4)
		arrow.modulate = Color(0.8, 0.1, 0.1)
		world.add_child(arrow)
		i += 1
	for f in 12: await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
